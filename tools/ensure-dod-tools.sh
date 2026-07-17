#!/usr/bin/env bash
# tools/ensure-dod-tools.sh — ensure the PINNED SwiftFormat + SwiftLint binaries exist in tools/bin/.
#
# The Definition of Done must be deterministic: a `brew install` of "latest" means a new formatter
# release can redline CI (or the local gate) with failures unrelated to any diff — a real incident
# (SwiftFormat 0.61 changed CLI arg parsing) motivated this. Both LOCAL_DOD and CI call this script
# and then invoke tools/bin/swiftformat / tools/bin/swiftlint, so local and CI run byte-identical,
# checksum-verified tools. Bumping a tool = update the VERSION + SHA256 here, deliberately, in a
# commit that CI then proves green.
#
# Idempotent and quiet on the happy path: if the right versions are already installed, exits 0
# without network access. Diagnostics to stderr.
set -euo pipefail

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$TOOLS_DIR/bin"

SWIFTFORMAT_VERSION="0.61.1"
SWIFTFORMAT_URL="https://github.com/nicklockwood/SwiftFormat/releases/download/${SWIFTFORMAT_VERSION}/swiftformat.zip"
SWIFTFORMAT_SHA256="b990400779aceb7d7020796eb9ba814d4480543f671d38fc0ff48cb72f04c584"

SWIFTLINT_VERSION="0.65.0"
SWIFTLINT_URL="https://github.com/realm/SwiftLint/releases/download/${SWIFTLINT_VERSION}/portable_swiftlint.zip"
SWIFTLINT_SHA256="d6cb0aa7a2f5f1ef306fc9e37bcb54dc9a26facc8f7784ac0c3dd3eccf5c6ba6"

installed_version() { # $1 = binary path
  [ -x "$1" ] && "$1" --version 2>/dev/null | head -1 | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true
}

fetch_and_install() { # $1 name, $2 url, $3 sha256, $4 binary-name-inside-zip
  local name="$1" url="$2" sha="$3" bin="$4"
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  echo "ensure-dod-tools: fetching pinned ${name}..." >&2
  curl -fsSL --retry 3 -o "$tmp/pkg.zip" "$url"
  local got
  got="$(shasum -a 256 "$tmp/pkg.zip" | awk '{print $1}')"
  if [ "$got" != "$sha" ]; then
    echo "ensure-dod-tools: CHECKSUM MISMATCH for $name — expected $sha, got $got. Refusing to install." >&2
    exit 1
  fi
  unzip -o -q "$tmp/pkg.zip" -d "$tmp/unpacked"
  mkdir -p "$BIN_DIR"
  install -m 0755 "$tmp/unpacked/$bin" "$BIN_DIR/$bin"
}

if [ "$(installed_version "$BIN_DIR/swiftformat")" != "$SWIFTFORMAT_VERSION" ]; then
  fetch_and_install "SwiftFormat $SWIFTFORMAT_VERSION" "$SWIFTFORMAT_URL" "$SWIFTFORMAT_SHA256" "swiftformat"
fi
if [ "$(installed_version "$BIN_DIR/swiftlint")" != "$SWIFTLINT_VERSION" ]; then
  fetch_and_install "SwiftLint $SWIFTLINT_VERSION" "$SWIFTLINT_URL" "$SWIFTLINT_SHA256" "swiftlint"
fi

echo "ensure-dod-tools: swiftformat $(installed_version "$BIN_DIR/swiftformat"), swiftlint $(installed_version "$BIN_DIR/swiftlint") ready in tools/bin/" >&2

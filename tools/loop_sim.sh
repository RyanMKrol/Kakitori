#!/usr/bin/env bash
# tools/loop_sim.sh — ensure Kakitori's DEDICATED iOS simulators exist; print the requested UDID.
#
# Usage:
#   ./tools/loop_sim.sh          # ensure + print the iPad  (Kakitori-Sim — the default, DoD device)
#   ./tools/loop_sim.sh phone    # ensure + print the iPhone (Kakitori-Sim-Phone — compact-layout shots)
#
# Every local build/test surface targets a uniquely-named dedicated device (never a generic
# model name like "iPad Air 11-inch (M4)" or "iPhone 16") so that the several autonomous iOS
# loops on this Mac (Scout, Sprout, Enough, Basket, Kakitori) can never converge on the same
# device and stamp on each other's foreground app / XCUITest runner. A unique NAME is the
# collision guard; this script makes name-targeting deterministic by guaranteeing exactly one
# device per name exists (reuse if present, else create on the newest installed iOS runtime).
# Prefix gate/build commands with `./tools/loop_sim.sh >/dev/null &&` so a fresh machine
# self-heals before the first test run.
#
# Two devices because Kakitori is a universal, iPad-FIRST app: the DoD + default visual verify
# run on the iPad (the primary layout); the iPhone exists ONLY for compact-layout screenshot
# tasks (T048/T049-style) — generic iPhone names are both ambiguous (duplicate names across
# installed runtimes) and shared with other loops.
#
# Prints ONLY the UDID on stdout; all diagnostics go to stderr, so callers can do
# SIM=$(tools/loop_sim.sh) / PHONE=$(tools/loop_sim.sh phone).
set -euo pipefail

IPAD_NAME="${KAKITORI_SIM_NAME:-Kakitori-Sim}"
IPAD_TYPE="com.apple.CoreSimulator.SimDeviceType.iPad-Air-11-inch-M4"
PHONE_NAME="${KAKITORI_SIM_PHONE_NAME:-Kakitori-Sim-Phone}"
PHONE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-16"

newest_runtime() {
  xcrun simctl list runtimes available \
    | grep -Eo 'com\.apple\.CoreSimulator\.SimRuntime\.iOS-[0-9-]+' | sort -V | tail -1
}

ensure_device() { # $1 = name, $2 = device type; prints UDID
  local name="$1" devtype="$2" udid runtime
  udid="$(xcrun simctl list devices --json \
    | jq -r --arg n "$name" '
        .devices | to_entries[] | .value[]
        | select(.name == $n and (.isAvailable != false)) | .udid' \
    | head -1)"
  if [ -z "${udid:-}" ]; then
    runtime="$(newest_runtime)"
    [ -n "${runtime:-}" ] || { echo "loop_sim: no iOS simulator runtime installed; run 'xcodebuild -downloadPlatform iOS'." >&2; exit 1; }
    echo "loop_sim: creating dedicated simulator '$name' ($runtime)…" >&2
    udid="$(xcrun simctl create "$name" "$devtype" "$runtime")"
  fi
  echo "$udid"
}

# Always ensure BOTH devices (idempotent, cheap) so either surface self-heals; print the requested one.
ipad_udid="$(ensure_device "$IPAD_NAME" "$IPAD_TYPE")"
phone_udid="$(ensure_device "$PHONE_NAME" "$PHONE_TYPE")"

case "${1:-}" in
  phone) echo "$phone_udid" ;;
  *)     echo "$ipad_udid" ;;
esac

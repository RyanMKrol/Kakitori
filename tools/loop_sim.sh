#!/usr/bin/env bash
# tools/loop_sim.sh — ensure Kakitori's DEDICATED iOS simulator exists; print its UDID.
#
# Every local build/test surface targets the uniquely-named `Kakitori-Sim` (never a generic
# model name like "iPad Air 11-inch (M4)") so that the several autonomous iOS loops on this
# Mac (Scout, Sprout, Enough, Basket, Kakitori) can never converge on the same device and
# stamp on each other's foreground app / XCUITest runner. A unique NAME is the collision
# guard; this script makes name-targeting deterministic by guaranteeing exactly one such
# device exists (reuse if present, else create on the newest installed iOS runtime).
# Prefix gate/build commands with `./tools/loop_sim.sh >/dev/null &&` so a fresh machine
# self-heals before the first test run.
#
# The device is an iPad — Kakitori is a universal, iPad-FIRST app (side-by-side prompt +
# canvas layout), so the loop's screenshots and tests should exercise the primary layout.
#
# Prints ONLY the UDID on stdout; all diagnostics go to stderr, so callers can do
# SIM=$(tools/loop_sim.sh).
set -euo pipefail

SIM_NAME="${KAKITORI_SIM_NAME:-Kakitori-Sim}"
DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPad-Air-11-inch-M4"

# Reuse an existing available device with this exact name, if any.
udid="$(xcrun simctl list devices --json \
  | jq -r --arg n "$SIM_NAME" '
      .devices | to_entries[] | .value[]
      | select(.name == $n and (.isAvailable != false)) | .udid' \
  | head -1)"

if [ -z "${udid:-}" ]; then
  runtime="$(xcrun simctl list runtimes available \
    | grep -Eo 'com\.apple\.CoreSimulator\.SimRuntime\.iOS-[0-9-]+' | sort -V | tail -1)"
  [ -n "${runtime:-}" ] || { echo "loop_sim: no iOS simulator runtime installed; run 'xcodebuild -downloadPlatform iOS'." >&2; exit 1; }
  echo "loop_sim: creating dedicated simulator '$SIM_NAME' ($runtime)…" >&2
  udid="$(xcrun simctl create "$SIM_NAME" "$DEVICE_TYPE" "$runtime")"
fi

echo "$udid"

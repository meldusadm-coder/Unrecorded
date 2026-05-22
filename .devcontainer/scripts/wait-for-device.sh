#!/usr/bin/env bash
# Block until adb reports at least one device (after connect-host-emulator).
set -euo pipefail

TIMEOUT="${ADB_WAIT_TIMEOUT:-120}"
INTERVAL=2
elapsed=0

echo "Waiting for adb device (timeout ${TIMEOUT}s) ..."

while ((elapsed < TIMEOUT)); do
  if adb devices | awk 'NR>1 && $2=="device" {found=1} END{exit !found}'; then
    adb devices -l
    exit 0
  fi
  sleep "${INTERVAL}"
  elapsed=$((elapsed + INTERVAL))
done

echo "ERROR: No adb device within ${TIMEOUT}s." >&2
adb devices >&2
exit 1

#!/usr/bin/env bash
# Connect container adb to Android emulator running on the Windows host.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=reset-adb.sh
source "${SCRIPT_DIR}/reset-adb.sh"

HOST="${ADB_HOST:-host.docker.internal}"
PORT="${ADB_PORT:-5555}"
MAX_ATTEMPTS="${ADB_CONNECT_ATTEMPTS:-30}"
SLEEP_SECS="${ADB_CONNECT_SLEEP:-2}"

device_ready() {
  adb devices | awk 'NR>1 && $2=="device" {found=1} END{exit !found}'
}

reset_adb

# Preferred: host adb server (ADB_SERVER_SOCKET from devcontainer.json).
if [[ -n "${ADB_SERVER_SOCKET:-}" ]]; then
  echo "Checking devices via host adb (${ADB_SERVER_SOCKET}) ..."
  for ((i = 1; i <= MAX_ATTEMPTS; i++)); do
    if device_ready; then
      echo "Host emulator visible to container adb."
      adb devices -l
      exit 0
    fi
    echo "  attempt ${i}/${MAX_ATTEMPTS} — waiting for host emulator ..."
    sleep "${SLEEP_SECS}"
  done
  echo "ERROR: Host adb has no device. On Windows:" >&2
  echo "  1. Confirm emulator in Android Studio (Device Manager)" >&2
  echo "  2. Run: start-dev.cmd  (or Start-UnrecordedDev.ps1)" >&2
  echo "  3. On host: adb devices  (should show emulator-5554 device)" >&2
  exit 1
fi

# Fallback: direct adb connect to forwarded host port.
echo "Connecting adb to ${HOST}:${PORT} ..."

for ((i = 1; i <= MAX_ATTEMPTS; i++)); do
  if adb connect "${HOST}:${PORT}" 2>/dev/null | grep -qE 'connected|already'; then
    if device_ready; then
      echo "Connected."
      adb devices -l
      exit 0
    fi
  fi
  echo "  attempt ${i}/${MAX_ATTEMPTS} — waiting for host emulator ..."
  sleep "${SLEEP_SECS}"
done

echo "ERROR: Could not connect to ${HOST}:${PORT}." >&2
echo "On Windows, run: start-dev.cmd" >&2
echo "Then in the container: ./scripts/dev-run-demo.sh" >&2
exit 1

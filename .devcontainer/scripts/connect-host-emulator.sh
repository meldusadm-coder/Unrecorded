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

reset_adb

echo "Connecting adb to ${HOST}:${PORT} ..."

for ((i = 1; i <= MAX_ATTEMPTS; i++)); do
  if adb connect "${HOST}:${PORT}" 2>/dev/null | grep -qE 'connected|already'; then
    if adb devices | grep -qE "${HOST}:${PORT}|device$"; then
      echo "Connected."
      adb devices -l
      exit 0
    fi
  fi
  echo "  attempt ${i}/${MAX_ATTEMPTS} — waiting for host emulator ..."
  sleep "${SLEEP_SECS}"
done

echo "ERROR: Could not connect to ${HOST}:${PORT}." >&2
echo "On Windows, run: scripts\\windows\\Start-UnrecordedDev.ps1" >&2
echo "Ensure the emulator is booted and adb on the host shows emulator-5554." >&2
exit 1

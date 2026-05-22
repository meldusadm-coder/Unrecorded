#!/usr/bin/env bash
# Kill stale adb server/processes and start a fresh server (or use host adb via ADB_SERVER_SOCKET).
set -euo pipefail

reset_adb() {
  if [[ -n "${ADB_SERVER_SOCKET:-}" ]]; then
    echo "Using host adb server (${ADB_SERVER_SOCKET}) ..."
    if ! adb devices >/dev/null 2>&1; then
      echo "ERROR: Cannot reach host adb. On Windows run start-dev.cmd, then retry." >&2
      return 1
    fi
    echo "Host adb reachable."
    return 0
  fi

  echo "Resetting local adb ..."
  adb kill-server 2>/dev/null || true
  if command -v pkill >/dev/null 2>&1; then
    pkill -x adb 2>/dev/null || true
  fi
  sleep 0.5
  if ! adb start-server >/dev/null 2>&1; then
    echo "ERROR: adb start-server failed." >&2
    return 1
  fi
  if ! adb version >/dev/null 2>&1; then
    echo "ERROR: adb is not responding after reset." >&2
    return 1
  fi
  echo "adb server ready."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  reset_adb
fi

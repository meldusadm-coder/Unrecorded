#!/usr/bin/env bash
# Reset adb, connect to the host emulator, and wait until a device is ready.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "${SCRIPT_DIR}/connect-host-emulator.sh"
bash "${SCRIPT_DIR}/wait-for-device.sh"

echo "Host emulator ready."

#!/usr/bin/env bash
set -euo pipefail

cd /workspace

echo "==> flutter pub get"
flutter pub get

echo "==> flutter doctor"
flutter doctor -v

echo "==> Dev container ready."
echo "    Windows: run scripts/windows/Start-UnrecordedDev.ps1 on the host first."
echo "    Then: .devcontainer/scripts/connect-host-emulator.sh"

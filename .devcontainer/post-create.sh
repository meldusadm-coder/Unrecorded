#!/usr/bin/env bash
set -euo pipefail

cd /workspace

echo "==> flutter pub get"
flutter pub get

echo "==> flutter doctor"
flutter doctor -v

echo "==> Dev container ready."
echo "    Windows host (once per session): start-dev.cmd"
echo "    Then in this container: ./scripts/dev-run.sh"
echo "    Or press F5 -> Unrecorded (mobile)"

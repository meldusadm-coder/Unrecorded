#!/usr/bin/env bash
# Connect the dev container to the host emulator and run or build the app.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

CONNECT_ONLY=false
BUILD_APK=false
FLUTTER_ARGS=()

usage() {
  cat <<'EOF'
Usage: scripts/dev-run.sh [options] [-- flutter-run-args]

One-command dev workflow inside the dev container:
  1. Reset adb and connect to the Windows host emulator
  2. Wait for the device
  3. flutter pub get
  4. flutter run (default) or flutter build apk --debug (--build)

Prerequisite on Windows host (once per session):
  start-dev.cmd

Options:
  --connect-only   Prepare the emulator connection only
  --build          Build a debug APK instead of running the app
  -h, --help       Show this help

Examples:
  ./scripts/dev-run.sh
  ./scripts/dev-run.sh --build
  ./scripts/dev-run.sh --connect-only
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --connect-only)
      CONNECT_ONLY=true
      shift
      ;;
    --build)
      BUILD_APK=true
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      FLUTTER_ARGS+=("$@")
      break
      ;;
    *)
      FLUTTER_ARGS+=("$1")
      shift
      ;;
  esac
done

echo "==> Preparing host emulator"
bash .devcontainer/scripts/prepare-emulator.sh

if [[ "${CONNECT_ONLY}" == true ]]; then
  echo "Ready. Run: ./scripts/dev-run.sh"
  exit 0
fi

echo "==> flutter pub get"
flutter pub get

if [[ "${BUILD_APK}" == true ]]; then
  echo "==> flutter build apk --debug"
  cd apps/mobile
  flutter build apk --debug
else
  echo "==> flutter run"
  echo "    Note: first assembleDebug in a dev container can take 10–20+ min (Windows Docker I/O)."
  echo "    If it seems stuck, open another terminal and run: ./scripts/warm-android-build.sh"
  echo "    Or: cd apps/mobile/android && ./gradlew :app:assembleDebug --info"
  cd apps/mobile
  if [[ ${#FLUTTER_ARGS[@]} -gt 0 ]]; then
    flutter run "${FLUTTER_ARGS[@]}"
  else
    flutter run
  fi
fi

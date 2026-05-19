#!/usr/bin/env bash
# Pre-download Gradle deps and run one debug assemble (optional; first run is slow in dev containers).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

export GRADLE_USER_HOME="${GRADLE_USER_HOME:-${HOME}/.gradle}"
mkdir -p "${GRADLE_USER_HOME}"

echo "==> flutter pub get"
flutter pub get

echo "==> Gradle warm-up (assembleDebug). This can take 10–20+ minutes the first time."
echo "    Progress: watch for 'BUILD SUCCESSFUL' or run with -v in another terminal:"
echo "    cd apps/mobile/android && ./gradlew :app:assembleDebug --info"
echo ""

cd apps/mobile
flutter build apk --debug

echo "==> Done. Next: ./scripts/dev-run-demo.sh (install + run is much faster)."

#!/usr/bin/env bash
# Run checks before opening a release/hotfix PR or cutting a build.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

REPO_ROOT="$(git_lib_repo_root)"
SKIP_TESTS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-tests)
      SKIP_TESTS=true
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--skip-tests]" >&2
      exit 1
      ;;
  esac
done

git_lib_require_git "${REPO_ROOT}"
cd "${REPO_ROOT}"

run_step() {
  echo ""
  echo "==> $1"
  shift
  "$@"
}

run_step "Version (pubspec)" "${REPO_ROOT}/tool/release/verify_version.sh"
run_step "Release copy guardrails" "${REPO_ROOT}/tool/release/check_release_copy.sh"
run_step "Workspace dependencies" flutter pub get
run_step "Format check" dart format --set-exit-if-changed .
run_step "Analyze" dart analyze --fatal-infos

if [[ "${SKIP_TESTS}" != "true" ]]; then
  run_step "Core tests" bash -c 'cd packages/unrecorded_core && dart test'
  run_step "Radio tests" bash -c 'cd packages/unrecorded_radio && flutter test'
  run_step "App tests" bash -c 'cd apps/mobile && flutter test'
else
  echo ""
  echo "Skipping tests (--skip-tests)."
fi

echo ""
echo "Preflight passed."

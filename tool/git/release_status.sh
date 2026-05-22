#!/usr/bin/env bash
# Print current branch, app version, and ahead/behind vs main and dev.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

REPO_ROOT="$(git_lib_repo_root)"
PRODUCTION_BRANCH="${PRODUCTION_BRANCH:-main}"
INTEGRATION_BRANCH="${INTEGRATION_BRANCH:-dev}"

git_lib_require_git "${REPO_ROOT}"
git_lib_fetch "${REPO_ROOT}" 2>/dev/null || true

BRANCH="$(git_lib_current_branch "${REPO_ROOT}")"
echo "current_branch=${BRANCH:-detached}"

if [[ -f "${REPO_ROOT}/apps/mobile/pubspec.yaml" ]]; then
  # shellcheck source=/dev/null
  eval "$("${REPO_ROOT}/tool/release/verify_version.sh")"
  echo "app_version=${full_version}"
  echo "release_tag=${tag_name}"
fi

count_range() {
  local from="$1" to="$2"
  git -C "${REPO_ROOT}" rev-list --count "${from}..${to}" 2>/dev/null || echo "?"
}

if git_lib_branch_exists_remote "${REPO_ROOT}" "${PRODUCTION_BRANCH}" \
  && git_lib_branch_exists_remote "${REPO_ROOT}" "${INTEGRATION_BRANCH}"; then
  echo ""
  echo "origin/${INTEGRATION_BRANCH} vs origin/${PRODUCTION_BRANCH}:"
  echo "  dev ahead of main:  $(count_range "origin/${PRODUCTION_BRANCH}" "origin/${INTEGRATION_BRANCH}") commit(s)"
  echo "  main ahead of dev:  $(count_range "origin/${INTEGRATION_BRANCH}" "origin/${PRODUCTION_BRANCH}") commit(s)"
fi

if [[ -n "${BRANCH}" ]] && git_lib_branch_exists_remote "${REPO_ROOT}" "${PRODUCTION_BRANCH}"; then
  if git -C "${REPO_ROOT}" rev-parse --verify "${BRANCH}" >/dev/null 2>&1; then
    echo ""
    echo "${BRANCH} vs origin/${PRODUCTION_BRANCH}:"
    echo "  branch ahead of main: $(count_range "origin/${PRODUCTION_BRANCH}" "${BRANCH}") commit(s)"
    echo "  branch behind main:   $(count_range "${BRANCH}" "origin/${PRODUCTION_BRANCH}") commit(s)"
  fi
fi

echo ""
echo "Docs: docs/git-flow.md"

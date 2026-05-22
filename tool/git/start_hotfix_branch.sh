#!/usr/bin/env bash
# Create hotfix/VERSION from origin/main and optionally bump app version.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

REPO_ROOT="$(git_lib_repo_root)"
PRODUCTION_BRANCH="${PRODUCTION_BRANCH:-main}"
ALLOW_DIRTY=false

usage() {
  echo "Usage: $0 <version_name> [build_number] [--allow-dirty]"
  echo "  Creates branch hotfix/<version_name> from origin/${PRODUCTION_BRANCH}."
  echo "  If build_number is given, runs tool/release/bump_version.sh."
  exit 1
}

if [[ $# -lt 1 ]]; then
  usage
fi

VERSION_NAME="$1"
shift

BUILD_NUMBER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-dirty)
      ALLOW_DIRTY=true
      shift
      ;;
    *)
      if [[ -z "${BUILD_NUMBER}" ]] && [[ "${1}" =~ ^[0-9]+$ ]]; then
        BUILD_NUMBER="$1"
        shift
      else
        echo "Unknown argument: $1" >&2
        usage
      fi
      ;;
  esac
done

git_lib_require_git "${REPO_ROOT}"
git_lib_validate_semver "${VERSION_NAME}"
if [[ -n "${BUILD_NUMBER}" ]]; then
  git_lib_validate_build_number "${BUILD_NUMBER}"
fi
git_lib_ensure_clean_or_allow_dirty "${REPO_ROOT}" "${ALLOW_DIRTY}"

HOTFIX_BRANCH="hotfix/${VERSION_NAME}"

if git -C "${REPO_ROOT}" rev-parse --verify "${HOTFIX_BRANCH}" >/dev/null 2>&1; then
  echo "Error: branch ${HOTFIX_BRANCH} already exists locally." >&2
  exit 1
fi

git_lib_fetch "${REPO_ROOT}"

if ! git_lib_branch_exists_remote "${REPO_ROOT}" "${PRODUCTION_BRANCH}"; then
  echo "Error: origin/${PRODUCTION_BRANCH} not found." >&2
  exit 1
fi

echo "Creating ${HOTFIX_BRANCH} from origin/${PRODUCTION_BRANCH}..."
git -C "${REPO_ROOT}" checkout -b "${HOTFIX_BRANCH}" "origin/${PRODUCTION_BRANCH}"

if [[ -n "${BUILD_NUMBER}" ]]; then
  echo "Bumping version to ${VERSION_NAME}+${BUILD_NUMBER}..."
  "${REPO_ROOT}/tool/release/bump_version.sh" "${VERSION_NAME}" "${BUILD_NUMBER}" \
    $([[ "${ALLOW_DIRTY}" == "true" ]] && echo --allow-dirty)
  echo "Commit version bump before opening the hotfix PR."
fi

git_lib_print_next_steps "Hotfix branch ready: ${HOTFIX_BRANCH}" \
  "Apply the fix; update CHANGELOG.md." \
  "Run: ./tool/git/preflight_release.sh" \
  "Run: ./tool/git/open_release_pr.sh  (PR targets main)" \
  "After merge: Release Android workflow on main" \
  "Then: ./tool/git/backmerge_main_to_dev.sh"

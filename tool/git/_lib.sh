# shellcheck shell=bash
# Shared helpers for tool/git/*.sh
set -euo pipefail

git_lib_repo_root() {
  local lib_dir
  lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "${lib_dir}/../.." && pwd
}

git_lib_require_git() {
  local root="$1"
  if ! git -C "${root}" rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: not a git repository: ${root}" >&2
    exit 1
  fi
}

git_lib_fetch() {
  local root="$1"
  echo "Fetching origin..."
  git -C "${root}" fetch origin
}

git_lib_branch_exists_remote() {
  local root="$1" branch="$2"
  git -C "${root}" rev-parse --verify "origin/${branch}" >/dev/null 2>&1
}

git_lib_current_branch() {
  local root="$1"
  git -C "${root}" branch --show-current 2>/dev/null || true
}

git_lib_ensure_clean_or_allow_dirty() {
  local root="$1" allow_dirty="${2:-false}"
  if [[ "${allow_dirty}" == "true" ]]; then
    return 0
  fi
  if [[ -n "$(git -C "${root}" status --porcelain 2>/dev/null || true)" ]]; then
    echo "Error: working tree is dirty. Commit, stash, or pass --allow-dirty." >&2
    exit 1
  fi
}

git_lib_validate_semver() {
  local version="$1"
  if ! [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: version must be MAJOR.MINOR.PATCH (e.g. 0.2.0), got: ${version}" >&2
    exit 1
  fi
}

git_lib_validate_build_number() {
  local build="$1"
  if ! [[ "${build}" =~ ^[0-9]+$ ]]; then
    echo "Error: build_number must be numeric, got: ${build}" >&2
    exit 1
  fi
}

git_lib_has_gh() {
  command -v gh >/dev/null 2>&1
}

git_lib_print_next_steps() {
  local title="$1"
  shift
  echo ""
  echo "=== ${title} ==="
  while [[ $# -gt 0 ]]; do
    echo "  - $1"
    shift
  done
  echo ""
}

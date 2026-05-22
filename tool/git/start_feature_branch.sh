#!/usr/bin/env bash
# Create feature/issue-N-slug from origin/dev (optional GitHub issue title via gh).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

REPO_ROOT="$(git_lib_repo_root)"
INTEGRATION_BRANCH="${INTEGRATION_BRANCH:-dev}"
ALLOW_DIRTY=false
CUSTOM_SLUG=""
ISSUE_NUMBER=""

usage() {
  echo "Usage: $0 <issue_number> [--slug <short-slug>] [--allow-dirty]"
  echo "  Creates feature/issue-<N>-<slug> from origin/${INTEGRATION_BRANCH}."
  echo "  With gh installed, slug defaults from issue title."
  exit 1
}

slugify() {
  local raw="$1"
  echo "${raw}" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g; s/-+/-/g' \
    | cut -c1-40 \
    | sed -E 's/-+$//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --slug)
      CUSTOM_SLUG="${2:-}"
      shift 2
      ;;
    --allow-dirty)
      ALLOW_DIRTY=true
      shift
      ;;
    --help | -h)
      usage
      ;;
    *)
      if [[ -z "${ISSUE_NUMBER}" ]] && [[ "${1}" =~ ^[0-9]+$ ]]; then
        ISSUE_NUMBER="$1"
        shift
      else
        echo "Unknown argument: $1" >&2
        usage
      fi
      ;;
  esac
done

if [[ -z "${ISSUE_NUMBER}" ]]; then
  usage
fi

git_lib_require_git "${REPO_ROOT}"
git_lib_ensure_clean_or_allow_dirty "${REPO_ROOT}" "${ALLOW_DIRTY}"

SLUG="${CUSTOM_SLUG}"
if [[ -z "${SLUG}" ]] && git_lib_has_gh; then
  if title="$(gh issue view "${ISSUE_NUMBER}" --json title -q .title 2>/dev/null)"; then
    SLUG="$(slugify "${title}")"
    echo "Issue #${ISSUE_NUMBER}: ${title}"
  fi
fi

if [[ -z "${SLUG}" ]]; then
  echo "Error: could not derive slug. Pass --slug <name> or install gh and authenticate." >&2
  exit 1
fi

FEATURE_BRANCH="feature/issue-${ISSUE_NUMBER}-${SLUG}"

if git -C "${REPO_ROOT}" rev-parse --verify "${FEATURE_BRANCH}" >/dev/null 2>&1; then
  echo "Error: branch ${FEATURE_BRANCH} already exists." >&2
  exit 1
fi

git_lib_fetch "${REPO_ROOT}"

if ! git_lib_branch_exists_remote "${REPO_ROOT}" "${INTEGRATION_BRANCH}"; then
  echo "Error: origin/${INTEGRATION_BRANCH} not found." >&2
  exit 1
fi

echo "Creating ${FEATURE_BRANCH} from origin/${INTEGRATION_BRANCH}..."
git -C "${REPO_ROOT}" checkout -b "${FEATURE_BRANCH}" "origin/${INTEGRATION_BRANCH}"

git_lib_print_next_steps "Feature branch ready: ${FEATURE_BRANCH}" \
  "Implement; commit on this branch." \
  "Push: git push -u origin ${FEATURE_BRANCH}" \
  "Open PR into ${INTEGRATION_BRANCH} (fixes #${ISSUE_NUMBER})." \
  "Playbook: skills/create-feature-branch/SKILL.md"

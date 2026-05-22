#!/usr/bin/env bash
# After a release, sync main into dev via a PR (or print manual steps).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

REPO_ROOT="$(git_lib_repo_root)"
PRODUCTION_BRANCH="${PRODUCTION_BRANCH:-main}"
INTEGRATION_BRANCH="${INTEGRATION_BRANCH:-dev}"

usage() {
  echo "Usage: $0 [--dry-run]"
  echo "  Opens (or prints) a PR to merge ${PRODUCTION_BRANCH} into ${INTEGRATION_BRANCH}."
  exit 1
}

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
elif [[ $# -gt 0 ]]; then
  usage
fi

git_lib_require_git "${REPO_ROOT}"
git_lib_fetch "${REPO_ROOT}"

if ! git_lib_branch_exists_remote "${REPO_ROOT}" "${PRODUCTION_BRANCH}"; then
  echo "Error: origin/${PRODUCTION_BRANCH} not found." >&2
  exit 1
fi
if ! git_lib_branch_exists_remote "${REPO_ROOT}" "${INTEGRATION_BRANCH}"; then
  echo "Error: origin/${INTEGRATION_BRANCH} not found." >&2
  exit 1
fi

BEHIND="$(git -C "${REPO_ROOT}" rev-list --count "origin/${INTEGRATION_BRANCH}..origin/${PRODUCTION_BRANCH}" 2>/dev/null || echo 0)"
AHEAD="$(git -C "${REPO_ROOT}" rev-list --count "origin/${PRODUCTION_BRANCH}..origin/${INTEGRATION_BRANCH}" 2>/dev/null || echo 0)"

echo "${PRODUCTION_BRANCH} is ${BEHIND} commit(s) ahead of ${INTEGRATION_BRANCH}."
echo "${INTEGRATION_BRANCH} is ${AHEAD} commit(s) ahead of ${PRODUCTION_BRANCH}."

if [[ "${BEHIND}" -eq 0 ]]; then
  echo "Nothing to back-merge: ${INTEGRATION_BRANCH} already contains ${PRODUCTION_BRANCH}."
  exit 0
fi

SYNC_BRANCH="sync/main-into-dev-$(date -u +%Y%m%d)"

if [[ "${DRY_RUN}" == "true" ]]; then
  echo "Dry run: would create ${SYNC_BRANCH} from origin/${PRODUCTION_BRANCH} and PR → ${INTEGRATION_BRANCH}."
  exit 0
fi

if git -C "${REPO_ROOT}" rev-parse --verify "${SYNC_BRANCH}" >/dev/null 2>&1; then
  echo "Error: ${SYNC_BRANCH} already exists. Delete it or use another name." >&2
  exit 1
fi

git -C "${REPO_ROOT}" checkout -b "${SYNC_BRANCH}" "origin/${PRODUCTION_BRANCH}"

TITLE="Sync ${PRODUCTION_BRANCH} into ${INTEGRATION_BRANCH} after release"
BODY="$(cat <<EOF
## Summary
Back-merge shipped commits from \`${PRODUCTION_BRANCH}\` into \`${INTEGRATION_BRANCH}\` so integration stays aligned with production.

## Checklist
- [ ] CI green
- [ ] No unintended conflict resolutions (release-only commits should already be on both sides when possible)
EOF
)"

REMOTE="$(git -C "${REPO_ROOT}" remote get-url origin 2>/dev/null || echo "")"
if [[ "${REMOTE}" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
  OWNER="${BASH_REMATCH[1]}"
  REPO="${BASH_REMATCH[2]%.git}"
  MANUAL_URL="https://github.com/${OWNER}/${REPO}/compare/${INTEGRATION_BRANCH}...${SYNC_BRANCH}?expand=1"
else
  MANUAL_URL="(open PR: ${SYNC_BRANCH} → ${INTEGRATION_BRANCH})"
fi

if git_lib_has_gh; then
  git -C "${REPO_ROOT}" push -u origin "${SYNC_BRANCH}"
  gh pr create \
    --base "${INTEGRATION_BRANCH}" \
    --head "${SYNC_BRANCH}" \
    --title "${TITLE}" \
    --body "${BODY}" || true
  git_lib_print_next_steps "Back-merge PR" \
    "Merge the PR into ${INTEGRATION_BRANCH}." \
    "Delete branch ${SYNC_BRANCH} after merge."
else
  echo ""
  echo "gh CLI not found. Push and open PR manually:"
  echo "  git push -u origin ${SYNC_BRANCH}"
  echo "  ${MANUAL_URL}"
  echo ""
  echo "Suggested title: ${TITLE}"
fi

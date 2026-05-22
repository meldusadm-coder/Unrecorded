#!/usr/bin/env bash
# Open a PR from the current release/* or hotfix/* branch into main.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

REPO_ROOT="$(git_lib_repo_root)"
PRODUCTION_BRANCH="${PRODUCTION_BRANCH:-main}"

git_lib_require_git "${REPO_ROOT}"

BRANCH="$(git_lib_current_branch "${REPO_ROOT}")"
if [[ -z "${BRANCH}" ]]; then
  echo "Error: detached HEAD; checkout a release/* or hotfix/* branch." >&2
  exit 1
fi

if [[ "${BRANCH}" != release/* && "${BRANCH}" != hotfix/* ]]; then
  echo "Error: expected release/* or hotfix/* branch, on: ${BRANCH}" >&2
  exit 1
fi

# shellcheck source=/dev/null
eval "$("${REPO_ROOT}/tool/release/verify_version.sh")"
TITLE="Release ${version_name} (${full_version})"
if [[ "${BRANCH}" == hotfix/* ]]; then
  TITLE="Hotfix ${version_name} (${full_version})"
fi

BODY="$(cat <<EOF
## Summary
- Ship \`${full_version}\` from \`${BRANCH}\` into \`${PRODUCTION_BRANCH}\`.

## Checklist
- [ ] CHANGELOG.md updated for \`${full_version}\`
- [ ] \`./tool/git/preflight_release.sh\` passed locally
- [ ] CI green on this PR
- [ ] Merge with **Create a merge commit** (never squash into \`${PRODUCTION_BRANCH}\`)
- [ ] After merge: run **Release Android** on \`${PRODUCTION_BRANCH}\` (see docs/release.md)
- [ ] After release: \`./tool/git/backmerge_main_to_dev.sh\` (back-merge PR also merge-commit only)
EOF
)"

REMOTE="$(git -C "${REPO_ROOT}" remote get-url origin 2>/dev/null || echo "")"
if [[ "${REMOTE}" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
  OWNER="${BASH_REMATCH[1]}"
  REPO="${BASH_REMATCH[2]%.git}"
  MANUAL_URL="https://github.com/${OWNER}/${REPO}/compare/${PRODUCTION_BRANCH}...${BRANCH}?expand=1"
else
  MANUAL_URL="(open a PR: ${BRANCH} → ${PRODUCTION_BRANCH} on your host)"
fi

echo "Branch: ${BRANCH} → ${PRODUCTION_BRANCH}"
echo "Version: ${full_version} (tag: ${tag_name})"

if git_lib_has_gh; then
  echo "Pushing branch and opening PR with gh..."
  git -C "${REPO_ROOT}" push -u origin "${BRANCH}"
  gh pr create \
    --base "${PRODUCTION_BRANCH}" \
    --head "${BRANCH}" \
    --title "${TITLE}" \
    --body "${BODY}"
else
  echo ""
  echo "gh CLI not found. Push and open PR manually:"
  echo "  git push -u origin ${BRANCH}"
  echo "  ${MANUAL_URL}"
  echo ""
  echo "Suggested title: ${TITLE}"
fi

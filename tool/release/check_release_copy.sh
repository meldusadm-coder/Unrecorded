#!/usr/bin/env bash
# Fail if release/store copy uses certainty claims forbidden by product guardrails.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

# Patterns that imply certainty. Negated disclaimers (e.g. "not proof that …") are OK.
FORBIDDEN=(
  'recording detected'
  'spy detected'
  'confirmed threat'
  'surveillance found'
  'we know someone is recording'
  'proves that anyone is recording'
  'proves that someone is recording'
  'proof that anyone is recording'
  'proof that someone is recording'
  'guaranteed detection'
  'definitely recording'
)

SEARCH_PATHS=(CHANGELOG.md store tool/release/release_notes_template.md)

found=0

for pattern in "${FORBIDDEN[@]}"; do
  for path in "${SEARCH_PATHS[@]}"; do
    if [[ ! -e "${path}" ]]; then
      continue
    fi
    while IFS= read -r -d '' file; do
      while IFS= read -r line || [[ -n "${line}" ]]; do
        if ! echo "${line}" | grep -qiE "${pattern}"; then
          continue
        fi
        if echo "${line}" | grep -qiE "not[[:space:]]+${pattern}"; then
          continue
        fi
        echo "Error: forbidden phrase '${pattern}' in ${file}" >&2
        echo "  ${line}" >&2
        found=1
      done < "${file}"
    done < <(find "${path}" \( -name '*.txt' -o -name '*.md' \) -print0 2>/dev/null)
  done
done

if [[ "${found}" -ne 0 ]]; then
  echo "Release copy check failed. Use cautious wording (possible risk, not proof)." >&2
  exit 1
fi

echo "Release copy check passed."

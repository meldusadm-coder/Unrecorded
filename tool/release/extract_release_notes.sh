#!/usr/bin/env bash
# Extract release notes for GitHub Release from CHANGELOG or template.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHANGELOG="${REPO_ROOT}/CHANGELOG.md"
TEMPLATE="${REPO_ROOT}/tool/release/release_notes_template.md"

usage() {
  echo "Usage: $0 <version_key> [output_file]" >&2
  echo "  version_key  e.g. 0.1.0+1" >&2
  exit 1
}

[[ $# -ge 1 ]] || usage
VERSION_KEY="$1"
OUTPUT="${2:-}"

emit() {
  if [[ -n "${OUTPUT}" ]]; then
    cat >"${OUTPUT}"
    echo "Wrote release notes to ${OUTPUT}" >&2
  else
    cat
  fi
}

if [[ -f "${CHANGELOG}" ]]; then
  section="$(awk -v ver="${VERSION_KEY}" '
    $0 == "## " ver { found=1; next }
    found && /^## / { exit }
    found { print }
  ' "${CHANGELOG}")"
  if [[ -n "${section}" ]]; then
    {
      echo "# Unrecorded ${VERSION_KEY}"
      echo ""
      echo "${section}"
    } | emit
    exit 0
  fi
fi

{
  echo "# Unrecorded ${VERSION_KEY}"
  echo ""
  if [[ -f "${TEMPLATE}" ]]; then
    sed '1d' "${TEMPLATE}"
  else
    echo "Unrecorded surfaces possible privacy risk indicators from nearby Bluetooth signals."
    echo "It cannot prove that anyone is recording. Scan data stays on your device."
  fi
} | emit

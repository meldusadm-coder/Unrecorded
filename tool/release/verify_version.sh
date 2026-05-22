#!/usr/bin/env bash
# Print version_name and build_number from apps/mobile/pubspec.yaml.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PUBSPEC="${REPO_ROOT}/apps/mobile/pubspec.yaml"

if [[ ! -f "${PUBSPEC}" ]]; then
  echo "Error: pubspec not found: ${PUBSPEC}" >&2
  exit 1
fi

line="$(grep -E '^version:[[:space:]]*' "${PUBSPEC}" | head -n 1)"
raw="${line#version:}"
raw="${raw// /}"

if [[ "${raw}" != *"+"* ]]; then
  echo "Error: expected version NAME+BUILD in pubspec, got: ${raw}" >&2
  exit 1
fi

version_name="${raw%%+*}"
build_number="${raw#*+}"

echo "version_name=${version_name}"
echo "build_number=${build_number}"
echo "full_version=${raw}"
echo "tag_name=mobile-v${raw}"

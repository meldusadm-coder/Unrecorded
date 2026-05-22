#!/usr/bin/env bash
# Bump app version in apps/mobile/pubspec.yaml (source of truth for Android/iOS).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PUBSPEC="${REPO_ROOT}/apps/mobile/pubspec.yaml"
CHANGELOG="${REPO_ROOT}/CHANGELOG.md"
ALLOW_DIRTY=false

usage() {
  echo "Usage: $0 <version_name> <build_number> [--allow-dirty]"
  echo "  version_name   Semantic version, e.g. 0.1.0"
  echo "  build_number   Integer build number, e.g. 1"
  exit 1
}

if [[ $# -lt 2 ]]; then
  usage
fi

VERSION_NAME="$1"
BUILD_NUMBER="$2"
shift 2

while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-dirty)
      ALLOW_DIRTY=true
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      ;;
  esac
done

if ! [[ "${VERSION_NAME}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: version_name must be MAJOR.MINOR.PATCH (e.g. 0.1.0), got: ${VERSION_NAME}" >&2
  exit 1
fi

if ! [[ "${BUILD_NUMBER}" =~ ^[0-9]+$ ]]; then
  echo "Error: build_number must be numeric, got: ${BUILD_NUMBER}" >&2
  exit 1
fi

if [[ "${ALLOW_DIRTY}" != "true" ]] && [[ -n "$(git -C "${REPO_ROOT}" status --porcelain 2>/dev/null || true)" ]]; then
  echo "Error: working tree is dirty. Commit or stash changes, or pass --allow-dirty." >&2
  exit 1
fi

if [[ ! -f "${PUBSPEC}" ]]; then
  echo "Error: pubspec not found: ${PUBSPEC}" >&2
  exit 1
fi

FULL_VERSION="${VERSION_NAME}+${BUILD_NUMBER}"

if grep -qE '^version:[[:space:]]*' "${PUBSPEC}"; then
  sed -i "s/^version:.*/version: ${FULL_VERSION}/" "${PUBSPEC}"
else
  echo "Error: no version: line in ${PUBSPEC}" >&2
  exit 1
fi

echo "Updated ${PUBSPEC} -> version: ${FULL_VERSION}"

if [[ -f "${CHANGELOG}" ]] && ! grep -qF "## ${FULL_VERSION}" "${CHANGELOG}"; then
  tmp="$(mktemp)"
  {
    head -n 1 "${CHANGELOG}"
    echo ""
    echo "## ${FULL_VERSION}"
    echo ""
    echo "### Added"
    echo "- (describe changes)"
    echo ""
    echo "### Changed"
    echo "- "
    echo ""
    echo "### Fixed"
    echo "- "
    echo ""
    if [[ $(wc -l <"${CHANGELOG}") -gt 1 ]]; then
      tail -n +2 "${CHANGELOG}"
    fi
  } >"${tmp}"
  mv "${tmp}" "${CHANGELOG}"
  echo "Inserted placeholder section in CHANGELOG.md for ${FULL_VERSION}"
elif [[ -f "${CHANGELOG}" ]]; then
  echo "CHANGELOG.md already has section ## ${FULL_VERSION}"
fi

echo ""
echo "Done. Flutter maps this to:"
echo "  Android versionName=${VERSION_NAME} versionCode=${BUILD_NUMBER}"
echo "  iOS CFBundleShortVersionString=${VERSION_NAME} CFBundleVersion=${BUILD_NUMBER}"
echo "Fill in CHANGELOG.md bullets before releasing."

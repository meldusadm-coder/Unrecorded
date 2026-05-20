#!/usr/bin/env bash
# Fix common Android build failures in the dev container (bind mount + mixed ownership).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE_BUILD="${REPO_ROOT}/apps/mobile/build"

if [ -d "${MOBILE_BUILD}" ]; then
  if find "${MOBILE_BUILD}" ! -user "$(id -u)" -print -quit 2>/dev/null | grep -q .; then
    echo "==> Fixing ownership on apps/mobile/build (mixed root/vscode breaks Gradle on Windows mounts)"
    sudo chown -R "$(id -u):$(id -g)" "${MOBILE_BUILD}"
  fi
fi

if [ -n "${UNRECORDED_ANDROID_BUILD_DIR:-}" ]; then
  mkdir -p "${UNRECORDED_ANDROID_BUILD_DIR}"
fi

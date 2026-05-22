#!/usr/bin/env bash
# Fix common Android build failures in the dev container (bind mount + mixed ownership).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE_BUILD="${REPO_ROOT}/apps/mobile/build"

if [ -d "${MOBILE_BUILD}" ] && [ ! -L "${MOBILE_BUILD}" ]; then
  if find "${MOBILE_BUILD}" ! -user "$(id -u)" -print -quit 2>/dev/null | grep -q .; then
    echo "==> Fixing ownership on apps/mobile/build (mixed root/vscode breaks Gradle on Windows mounts)"
    sudo chown -R "$(id -u):$(id -g)" "${MOBILE_BUILD}"
  fi
fi

# Dev container: keep all of apps/mobile/build on the container filesystem via symlink
# so Flutter finds the APK at build/app/outputs/... and Gradle can chmod plugin outputs.
if [ -n "${UNRECORDED_ANDROID_BUILD_DIR:-}" ]; then
  CACHE_DIR="${UNRECORDED_ANDROID_BUILD_DIR}"
  mkdir -p "${CACHE_DIR}"

  if [ -L "${MOBILE_BUILD}" ]; then
    current="$(readlink -f "${MOBILE_BUILD}")"
    if [ "${current}" != "${CACHE_DIR}" ]; then
      echo "==> Repointing apps/mobile/build symlink to ${CACHE_DIR}"
      rm -f "${MOBILE_BUILD}"
      ln -sfn "${CACHE_DIR}" "${MOBILE_BUILD}"
    fi
  elif [ -d "${MOBILE_BUILD}" ]; then
    echo "==> Moving apps/mobile/build onto container disk (${CACHE_DIR})"
    shopt -s nullglob
    for item in "${MOBILE_BUILD}"/*; do
      name="$(basename "${item}")"
      if [ ! -e "${CACHE_DIR}/${name}" ]; then
        mv "${item}" "${CACHE_DIR}/"
      fi
    done
    shopt -u nullglob
    rm -rf "${MOBILE_BUILD}"
    ln -sfn "${CACHE_DIR}" "${MOBILE_BUILD}"
  else
    ln -sfn "${CACHE_DIR}" "${MOBILE_BUILD}"
  fi
  echo "==> apps/mobile/build -> ${CACHE_DIR}"
fi

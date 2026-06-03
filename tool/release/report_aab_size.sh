#!/usr/bin/env bash
# Estimate Play download size from a release .aab using bundletool.
# Usage: report_aab_size.sh <path-to-app-release.aab>
set -euo pipefail

AAB="${1:?Usage: $0 <app-release.aab>}"
if [[ ! -f "${AAB}" ]]; then
  echo "AAB not found: ${AAB}" >&2
  exit 1
fi

BUNDLETOOL_VERSION="${BUNDLETOOL_VERSION:-1.17.2}"
BUNDLETOOL_JAR="${BUNDLETOOL_JAR:-${RUNNER_TEMP:-/tmp}/bundletool-all.jar}"
APKS="${RUNNER_TEMP:-/tmp}/app-release-size.apks"

if [[ ! -f "${BUNDLETOOL_JAR}" ]]; then
  echo "Downloading bundletool ${BUNDLETOOL_VERSION}..."
  curl -fsSL \
    "https://github.com/google/bundletool/releases/download/${BUNDLETOOL_VERSION}/bundletool-all-${BUNDLETOOL_VERSION}.jar" \
    -o "${BUNDLETOOL_JAR}"
fi

java -jar "${BUNDLETOOL_JAR}" build-apks \
  --bundle="${AAB}" \
  --output="${APKS}" \
  --mode=universal \
  --overwrite >/dev/null

echo "Estimated download size (bundletool get-size total):"
SIZE_REPORT="$(java -jar "${BUNDLETOOL_JAR}" get-size total --apks="${APKS}")"
echo "${SIZE_REPORT}"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## App size (estimated download)"
    echo
    echo '```'
    echo "${SIZE_REPORT}"
    echo '```'
    echo
    echo "Source: \`bundletool get-size total\` on universal APKs from \`${AAB}\`."
    echo "Compare with [Play Console → App size](https://play.google.com/console/about/appsize/)."
  } >> "${GITHUB_STEP_SUMMARY}"
fi

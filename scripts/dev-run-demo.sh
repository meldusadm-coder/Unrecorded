#!/usr/bin/env bash
# Run the app with demo scanner mode (emulator-friendly UAT).
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "${REPO_ROOT}/scripts/dev-run.sh" -- \
  --dart-define=UNRECORDED_DEMO_MODE=true \
  --dart-define=UNRECORDED_DEMO_SCENARIO=high \
  "$@"

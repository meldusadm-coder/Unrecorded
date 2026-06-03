#!/usr/bin/env bash
# Run create_remove_ads_products.py with python3 + local venv (PEP 668 safe).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
VENV="${ROOT}/tool/play/.venv"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 not found. Install Python 3.10+." >&2
  exit 1
fi

if ! python3 -m venv --help >/dev/null 2>&1; then
  echo "python3-venv missing. Run: sudo apt-get install -y python3-venv python3-pip" >&2
  exit 1
fi

if [ ! -d "$VENV" ]; then
  echo "Creating tool/play/.venv …"
  python3 -m venv "$VENV"
fi

# shellcheck source=/dev/null
source "${VENV}/bin/activate"
pip install -q -r tool/play/requirements.txt
exec python tool/play/create_remove_ads_products.py "$@"

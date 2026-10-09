#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [[ ! -x ".venv/bin/python" ]]; then
    echo "Missing .venv. Run ./setup_linux.sh first." >&2
    exit 1
fi

exec ".venv/bin/python" -m nvision "$@"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
cd "$SCRIPT_DIR"

PYTHON_BIN="${PYTHON_BIN:-python3}"
"$PYTHON_BIN" -m venv .venv
".venv/bin/python" -m pip install --upgrade pip
".venv/bin/python" -m pip install -r requirements.txt

chmod +x setup_linux.sh run_nvision.sh run_nvision_gui.sh 2>/dev/null || true

echo "nVision Linux environment is ready."
echo "Run: ./run_nvision.sh <recording.dat> --rate 200"
echo "GUI: ./run_nvision_gui.sh"

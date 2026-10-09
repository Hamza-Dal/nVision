#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [[ ! -x ".venv/bin/python" ]]; then
    echo "Missing .venv. Run ./setup_linux.sh first." >&2
    exit 1
fi

if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
    echo "No graphical Linux session detected." >&2
    echo "Run this launcher from an Ubuntu desktop session with X11 or Wayland." >&2
    exit 1
fi

exec ".venv/bin/python" -m nvision.gui "$@"

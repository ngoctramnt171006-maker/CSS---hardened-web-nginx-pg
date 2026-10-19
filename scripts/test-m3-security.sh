#!/bin/sh
set -eu

echo "      M3 SECURITY INTEGRATION PYTESTS - CHI"
echo

VENV_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$VENV_DIR"
}

trap cleanup EXIT HUP INT TERM

python3 -m venv "$VENV_DIR"

PIP_DISABLE_PIP_VERSION_CHECK=1 \
"$VENV_DIR/bin/python" -m pip install -q pytest==8.4.2

PYTHONDONTWRITEBYTECODE=1 \
"$VENV_DIR/bin/python" -m pytest \
    -q \
    -p no:cacheprovider \
    tests/test_m3_security.py

#!/bin/sh

set -eu

PYTHON_IMAGE="python:3.12-slim-bookworm@sha256:54c85f3c47607a77f32adec749d3c81d1348bf25833671f512b26a9b6d778cb3"

echo "      WEB APPLICATION TESTS"
echo

docker run --rm \
    -e PYTHONDONTWRITEBYTECODE=1 \
    -e PIP_DISABLE_PIP_VERSION_CHECK=1 \
    -e PIP_ROOT_USER_ACTION=ignore \
    -v "$PWD:/work:ro" \
    -w /work \
    "$PYTHON_IMAGE" \
    sh -lc '
        python -m pip install -q \
            -r ma-nguon/web/requirements.txt \
            pytest==8.4.2 &&
        python -m pytest -q -p no:cacheprovider tests/test_web.py
    '

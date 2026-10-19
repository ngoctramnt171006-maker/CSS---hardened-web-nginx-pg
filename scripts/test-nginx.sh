#!/bin/sh

set -eu

BASE_URL="${BASE_URL:-https://localhost}"
CERT_DIR="${CERT_DIR:-cau-hinh/nginx/certs}"


echo "      NGINX TLS/mTLS SECURITY TEST"


echo
echo "[1] Test public endpoint /"
STATUS=$(curl -k -s -o /dev/null -w "%{http_code}" \
    "${BASE_URL}/")

if [ "$STATUS" = "200" ]; then
    echo "PASS: / -> HTTP 200"
else
    echo "FAIL: / -> HTTP ${STATUS}"
    exit 1
fi

echo
echo "[2] Test /admin without client certificate"
STATUS=$(curl -k -s -o /dev/null -w "%{http_code}" \
    "${BASE_URL}/admin")

if [ "$STATUS" = "403" ]; then
    echo "PASS: /admin without certificate -> HTTP 403"
else
    echo "FAIL: /admin without certificate -> HTTP ${STATUS}"
    exit 1
fi

echo
echo "[3] Test /admin with valid client certificate"
STATUS=$(curl -k -s -o /dev/null -w "%{http_code}" \
    --cert "${CERT_DIR}/client.crt" \
    --key "${CERT_DIR}/client.key" \
    "${BASE_URL}/admin")

if [ "$STATUS" = "200" ]; then
    echo "PASS: /admin with valid certificate -> HTTP 200"
else
    echo "FAIL: /admin with valid certificate -> HTTP ${STATUS}"
    exit 1
fi

echo

echo "ALL NGINX TLS/mTLS TESTS PASSED"

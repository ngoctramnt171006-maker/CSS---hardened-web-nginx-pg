#!/bin/sh
set -eu

echo "      DATABASE TLS TESTS (T3)"
echo

# T3-01: PostgreSQL must have SSL enabled.
SSL_ENABLED=$(docker compose exec -T db \
    psql -U postgres -d appdb -At \
    -c "SHOW ssl;" | tr -d '\r')

if [ "$SSL_ENABLED" = "on" ]; then
    echo "PASS: PostgreSQL SSL is enabled"
else
    echo "FAIL: PostgreSQL SSL is not enabled: ${SSL_ENABLED:-<empty>}"
    exit 1
fi

# T3-02: Non-TLS TCP connections must be rejected.
if NO_SSL_OUTPUT=$(docker compose exec -T db \
    psql "host=127.0.0.1 dbname=appdb user=app_user password=changeme_app_pw sslmode=disable" \
    -c "SELECT 1" 2>&1); then
    echo "FAIL: non-TLS PostgreSQL connection was accepted"
    exit 1
fi

if printf '%s\n' "$NO_SSL_OUTPUT" | grep -Fq 'pg_hba.conf rejects connection'; then
    echo "PASS: non-TLS PostgreSQL connection was rejected"
else
    echo "FAIL: non-TLS connection failed for an unexpected reason:"
    printf '%s\n' "$NO_SSL_OUTPUT"
    exit 1
fi

# T3-03: Web must connect to PostgreSQL using TLS.
TLS_OUTPUT=$(docker compose exec -T web python -c '
import psycopg2
import os

conn = psycopg2.connect(os.environ["DATABASE_URL"])
cur = conn.cursor()

cur.execute("""
    SELECT s.ssl, s.version, s.cipher
    FROM pg_stat_ssl s
    JOIN pg_stat_activity a ON a.pid = s.pid
    WHERE a.pid = pg_backend_pid()
""")

print(cur.fetchone())
' | tr -d '\r')

case "$TLS_OUTPUT" in
    "(True, "*)
        echo "PASS: web connects to PostgreSQL using TLS"
        ;;
    *)
        echo "FAIL: web connection is not using TLS: ${TLS_OUTPUT:-<empty>}"
        exit 1
        ;;
esac

echo
echo "ALL T3 DATABASE TLS TESTS PASSED"

#!/bin/sh

set -eu

echo "      POSTGRESQL PGAUDIT TESTS (T5)"
echo

SHARED_PRELOAD=$(docker compose exec -T db psql -U postgres -d appdb -At \
    -c "SHOW shared_preload_libraries;")
case ",$SHARED_PRELOAD," in
    *,pgaudit,*)
        echo "PASS: pgaudit is loaded through shared_preload_libraries"
        ;;
    *)
        echo "FAIL: pgaudit is not loaded: ${SHARED_PRELOAD:-<empty>}"
        exit 1
        ;;
esac

AUDIT_SETTINGS=$(docker compose exec -T db psql -U postgres -d appdb -At -F '|' \
    -c "SELECT current_setting('pgaudit.log'), EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgaudit');")

AUDIT_SETTINGS_NORMALIZED=$(printf '%s' "$AUDIT_SETTINGS" | tr -d '[:space:]')

if [ "$AUDIT_SETTINGS_NORMALIZED" = "ddl,role|t" ]; then
    echo "PASS: pgaudit logs DDL and role changes; extension is installed"
else
    echo "FAIL: unexpected pgaudit configuration or extension state: $AUDIT_SETTINGS"
    exit 1
fi

PROBE_NAME="audit_probe_$$"
NEGATIVE_TABLE="audit_user_should_fail_$$"
OLD_CONNECTION_LIMIT=$(docker compose exec -T db psql -U postgres -d appdb -At \
    -c "SELECT rolconnlimit FROM pg_roles WHERE rolname = 'app_user';")

if [ -z "$OLD_CONNECTION_LIMIT" ]; then
    echo "FAIL: app_user role was not found"
    exit 1
fi

if [ "$OLD_CONNECTION_LIMIT" = "99" ]; then
    TEST_CONNECTION_LIMIT=98
else
    TEST_CONNECTION_LIMIT=99
fi

docker compose exec -T db psql -U postgres -d appdb \
    -c "CREATE TABLE app.${PROBE_NAME}(id int);" \
    -c "DROP TABLE app.${PROBE_NAME};" \
    -c "ALTER ROLE app_user CONNECTION LIMIT ${TEST_CONNECTION_LIMIT};" \
    -c "ALTER ROLE app_user CONNECTION LIMIT ${OLD_CONNECTION_LIMIT};"

if CREATE_OUTPUT=$(docker compose exec -T db psql -U app_user -d appdb \
    -c "CREATE TABLE app.${NEGATIVE_TABLE}(id int);" 2>&1); then
    echo "FAIL: app_user unexpectedly created a table"
    exit 1
fi

if printf '%s\n' "$CREATE_OUTPUT" | grep -Fq 'permission denied'; then
    echo "PASS: app_user is denied DDL permissions"
else
    echo "FAIL: app_user DDL failed for an unexpected reason:"
    printf '%s\n' "$CREATE_OUTPUT"
    exit 1
fi

NEGATIVE_TABLE_EXISTS=$(docker compose exec -T db psql -U postgres -d appdb -At \
    -c "SELECT to_regclass('app.${NEGATIVE_TABLE}') IS NOT NULL;")

if [ "$NEGATIVE_TABLE_EXISTS" = "f" ]; then
    echo "PASS: denied DDL did not create a table"
else
    echo "FAIL: denied DDL unexpectedly created app.${NEGATIVE_TABLE}"
    exit 1
fi

LOG_FILE=$(mktemp)
AUDIT_FILE=$(mktemp)
trap 'rm -f "$LOG_FILE" "$AUDIT_FILE"' EXIT HUP INT TERM

docker compose logs --no-color db > "$LOG_FILE"
if grep 'AUDIT:' "$LOG_FILE" > "$AUDIT_FILE"; then
    :
else
    GREP_STATUS=$?
    if [ "$GREP_STATUS" -ne 1 ]; then
        echo "FAIL: could not extract pgaudit records from PostgreSQL logs"
        exit 1
    fi
fi

if grep -Fq "DDL,CREATE TABLE,TABLE,app.${PROBE_NAME}," "$AUDIT_FILE"; then
    echo "PASS: pgAudit recorded CREATE TABLE"
else
    echo "FAIL: pgAudit did not record CREATE TABLE for app.${PROBE_NAME}"
    exit 1
fi

if grep -Fq "DDL,DROP TABLE,TABLE,app.${PROBE_NAME}," "$AUDIT_FILE"; then
    echo "PASS: pgAudit recorded DROP TABLE"
else
    echo "FAIL: pgAudit did not record DROP TABLE for app.${PROBE_NAME}"
    exit 1
fi

PROBE_PID=$(grep -F "DDL,CREATE TABLE,TABLE,app.${PROBE_NAME}," "$AUDIT_FILE" \
    | sed -n 's/.*\[\([0-9][0-9]*\)\] LOG:.*/\1/p' \
    | head -n 1)

if [ -z "$PROBE_PID" ]; then
    echo "FAIL: could not identify the PostgreSQL session for this audit probe"
    exit 1
fi

if grep -F "[$PROBE_PID] LOG:  AUDIT:" "$AUDIT_FILE" \
    | grep -Fq "ROLE,ALTER ROLE,,,ALTER ROLE app_user CONNECTION LIMIT ${TEST_CONNECTION_LIMIT};"; then
    echo "PASS: pgAudit recorded ALTER ROLE"
else
    echo "FAIL: pgAudit did not record this run's ALTER ROLE at connection limit ${TEST_CONNECTION_LIMIT}"
    exit 1
fi

echo
echo "AUDIT LOG EVIDENCE:"
grep -E "DDL,(CREATE TABLE|DROP TABLE),TABLE,app\.${PROBE_NAME}," "$AUDIT_FILE"
grep -F "[$PROBE_PID] LOG:  AUDIT:" "$AUDIT_FILE" \
    | grep -F "ROLE,ALTER ROLE,,,ALTER ROLE app_user CONNECTION LIMIT ${TEST_CONNECTION_LIMIT};"
printf 'SHA-256: '
sha256sum "$AUDIT_FILE" | cut -d ' ' -f 1

echo
echo "ALL T5 PGAUDIT TESTS PASSED"

#!/bin/sh
# defend.sh - Goc nhin ke phong thu: liet ke trang thai that cua tung bien phap lam cung (doc cau hinh dang chay).
#   make defend
# Khac attack.sh: attack thu hanh vi; defend doc cau hinh dang ap dung roi so voi gia tri mong doi.
set -eu

OUT="${OUT:-bang-chung/defend/defend.txt}"
mkdir -p "$(dirname "$OUT")"
FAIL=0
PSQL="docker compose exec -T db psql -U postgres -d appdb -At"
check() {  # check <ten> <thuc-te> <mong-doi>
    if [ "$2" = "$3" ]; then echo "PASS: $1 = $2"; else echo "FAIL: $1 = '$2' (mong doi '$3')"; FAIL=1; fi
}
q() { $PSQL -c "$1" | tr -d '\r' | tr -d ' '; }

{
echo "DEFENSE STATE (nhom TH-True-Milk)"
echo "Thoi diem (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo
echo "[T1] RLS"
check "app.documents RLS enable+force" "$(q "SELECT relrowsecurity AND relforcerowsecurity FROM pg_class WHERE oid='app.documents'::regclass;")" "t"
check "app_user bypassrls"             "$(q "SELECT rolbypassrls FROM pg_roles WHERE rolname='app_user';")" "f"
check "app_user superuser"             "$(q "SELECT rolsuper FROM pg_roles WHERE rolname='app_user';")" "f"
echo "[T2] nginx"
PROTO=$(docker compose exec -T nginx nginx -T 2>/dev/null | tr -d '\r' | grep -E '^\s*ssl_protocols' | head -n 1 | sed 's/^ *//;s/;$//')
check "nginx ssl_protocols" "$PROTO" "ssl_protocols TLSv1.2 TLSv1.3"
echo "[T3] PostgreSQL TLS"
check "ssl"          "$(q "SHOW ssl;")" "on"
check "pg_hba: dong hostssl scram" "$(docker compose exec -T db cat /etc/postgresql/pg_hba.conf | tr -d '\r' | grep -cE '^hostssl[[:space:]].*scram-sha-256' || true)" "1"
check "pg_hba: dong host reject (khong TLS)" "$(docker compose exec -T db cat /etc/postgresql/pg_hba.conf | tr -d '\r' | grep -cE '^host[[:space:]].*reject' || true)" "2"
echo "[T5] pgaudit"
check "pgaudit.log" "$(q "SHOW pgaudit.log;")" "ddl,role"
check "pgaudit nap san" "$(q "SHOW shared_preload_libraries;" | grep -c pgaudit || true)" "1"
echo
if [ "$FAIL" -eq 0 ]; then echo "DEFEND RESULT: moi bien phap dang ap dung"; else echo "DEFEND RESULT: CO bien phap khong khop"; fi
} 2>&1 | tee "$OUT"

grep -q "DEFEND RESULT: moi bien phap dang ap dung" "$OUT"

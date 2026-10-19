#!/bin/sh
# attack.sh - Goc nhin ke tan cong: thu tung tan cong trong pham vi cho phep tren mang compose cua nhom.
#   make attack
# Moi ca in "BLOCKED" (he thong chan duoc) hoac "SUCCEEDED" (tan cong thanh cong = loi).
# Chi dung curl/psql/openssl thuong, khong cong cu khai thac, khong leo thang quyen.
set -eu

BASE_URL="${BASE_URL:-https://localhost}"
OUT="${OUT:-bang-chung/attack/attack.txt}"
mkdir -p "$(dirname "$OUT")"
FAIL=0
blocked()   { echo "BLOCKED: $1"; }
succeeded() { echo "SUCCEEDED (LOI): $1"; FAIL=1; }

{
echo "ATTACK PROBES (nhom TH-True-Milk)"
echo "Thoi diem (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo

UP=$(curl -k -s -o /dev/null -w "%{http_code}" --max-time 30 "$BASE_URL/" || true)
if [ "$UP" = "000" ] || [ -z "$UP" ]; then
    echo "FAIL: khong ket noi duoc $BASE_URL (da chay make up chua?)"
    echo "ATTACK RESULT: khong chay duoc"
    exit 1
fi
echo "[T2] Nghe len: ket noi HTTP khong ma hoa"
HDR=$(curl -s -I --max-time 30 http://localhost/ | tr -d '\r' || true)
CODE80=$(printf '%s\n' "$HDR" | sed -n '1s/^HTTP[^ ]* \([0-9]*\).*/\1/p')
LOC80=$(printf '%s\n' "$HDR" | sed -n 's/^[Ll]ocation: //p' | head -n 1)
case "$CODE80 $LOC80" in
    "301 https://"*) blocked "HTTP :80 khong phuc vu noi dung, chuyen 301 sang $LOC80" ;;
    *)               succeeded "HTTP :80 phuc vu noi dung hoac khong chuyen huong (ma '$CODE80', location '$LOC80')" ;;
esac

echo "[T2] Truy cap /admin khong co chung chi khach (mTLS)"
CODE=$(curl -k -s -o /dev/null -w "%{http_code}" "$BASE_URL/admin" || true)
[ "$CODE" = "403" ] && blocked "/admin khong chung chi -> HTTP 403" || succeeded "/admin khong chung chi -> HTTP $CODE"

echo "[T1] Phong ban nay doc du lieu phong ban khac (bo qua loc o tang web)"
OTHER=$(docker compose exec -T db psql -U app_user -d appdb -At \
    -c "BEGIN; SET LOCAL app.current_department = '1'; SELECT count(*) FROM app.documents WHERE department_id <> 1; COMMIT;" 2>&1 | tr -d '\r' | sed -n '/^[0-9][0-9]*$/p')
[ "$OTHER" = "0" ] && blocked "phong 1 doc tai lieu phong khac -> 0 dong (RLS)" || succeeded "phong 1 thay ${OTHER:-?} dong cua phong khac"
if W=$(docker compose exec -T db psql -U app_user -d appdb -At \
    -c "BEGIN; SET LOCAL app.current_department = '1'; INSERT INTO app.documents(department_id,title,content) VALUES (2,'tan-cong','tan-cong'); COMMIT;" 2>&1); then
    succeeded "phong 1 ghi duoc vao phong 2"
elif printf '%s' "$W" | grep -q 'row-level security'; then
    blocked "phong 1 ghi vao phong 2 bi RLS chan (new row violates row-level security policy)"
else
    succeeded "ghi bi chan nhung KHONG phai do RLS: $W"
fi

echo "[T3] Ket noi DB khong ma hoa bang tai khoan ung dung"
if N=$(docker compose exec -T db psql "host=127.0.0.1 dbname=appdb user=app_user password=changeme_app_pw sslmode=disable" -c "SELECT 1" 2>&1); then
    succeeded "ket noi DB khong TLS duoc chap nhan"
elif printf '%s' "$N" | grep -Fq 'pg_hba.conf rejects connection'; then
    blocked "ket noi DB khong TLS bi pg_hba tu choi (pg_hba.conf rejects connection)"
else
    succeeded "ket noi that bai nhung KHONG xac nhan duoc do pg_hba (chua chung minh duoc control): $N"
fi

echo "[T5] Tai khoan ung dung tao/sua doi tuong (DDL) va doi quyen"
if D=$(docker compose exec -T db psql -U app_user -d appdb -At -c "CREATE TABLE app.attack_probe_$$ (id int);" 2>&1); then
    docker compose exec -T db psql -U postgres -d appdb -c "DROP TABLE IF EXISTS app.attack_probe_$$;" >/dev/null 2>&1 || true
    succeeded "app_user tao duoc bang (quyen qua rong)"
elif printf '%s' "$D" | grep -q 'permission denied'; then
    blocked "app_user tao bang bi tu choi (permission denied)"
else
    succeeded "tao bang that bai nhung KHONG phai do phan quyen: $D"
fi
echo
if [ "$FAIL" -eq 0 ]; then echo "ATTACK RESULT: moi tan cong bi chan"; else echo "ATTACK RESULT: CO tan cong thanh cong"; fi
} 2>&1 | tee "$OUT"

grep -q "ATTACK RESULT: moi tan cong bi chan" "$OUT"

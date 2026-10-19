#!/bin/sh
# preflight.sh - Kiem moi truong truoc khi dung he thong; ghi kien truc CPU + phien ban cong cu.
#   sh scripts/preflight.sh            (make preflight goi script nay)
# Ghi ket qua ra bang-chung/preflight.txt. Thieu cong cu bat buoc -> exit 1.
set -eu

OUT="${OUT:-bang-chung/preflight.txt}"
mkdir -p "$(dirname "$OUT")"
FAIL=0

{
echo "PREFLIGHT"
echo "Thoi diem (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Kien truc CPU: $(uname -m)"
echo "He dieu hanh: $(uname -s) $(uname -r)"
echo

need() {  # need <lenh> <lenh-in-phien-ban>
    if command -v "$1" >/dev/null 2>&1; then
        echo "PASS: $1 -> $(sh -c "$2" 2>&1 | head -n 1)"
    else
        echo "FAIL: thieu $1"
        FAIL=1
    fi
}
need docker "docker --version"
need make "make --version"
need openssl "openssl version"
need curl "curl --version"
need git "git --version"

if docker compose version >/dev/null 2>&1; then
    echo "PASS: docker compose -> $(docker compose version 2>&1 | head -n 1)"
else
    echo "FAIL: khong co 'docker compose' (can Compose v2)"
    FAIL=1
fi
if docker info >/dev/null 2>&1; then
    echo "PASS: Docker daemon dang chay"
else
    echo "FAIL: Docker daemon khong chay (mo Docker Desktop)"
    FAIL=1
fi

# Cong 80/443 phai ranh neu he thong chua dung (neu da dung roi thi bo qua).
if docker compose ps -q 2>/dev/null | grep -q .; then
    echo "INFO: he thong dang chay, bo qua kiem tra cong 80/443"
else
    for p in 80 443; do
        if bash -c "exec 3<>/dev/tcp/127.0.0.1/$p" 2>/dev/null; then
            echo "FAIL: cong $p dang bi chuong trinh khac dung"
            FAIL=1
        else
            echo "PASS: cong $p ranh"
        fi
    done
fi
echo
if [ "$FAIL" -eq 0 ]; then echo "PREFLIGHT PASSED"; else echo "PREFLIGHT FAILED"; fi
} 2>&1 | tee "$OUT"

grep -q "PREFLIGHT PASSED" "$OUT"

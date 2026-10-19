#!/bin/sh
# make-manifest.sh - Tao va kiem MANIFEST sha256 cho thu muc bang-chung/ (Ha).
#
#   sh scripts/make-manifest.sh            tao bang-chung/MANIFEST.txt (mac dinh)
#   sh scripts/make-manifest.sh generate   nhu tren
#   sh scripts/make-manifest.sh check      kiem lai moi file con khop hash khong
#
# Moi file trong bang-chung/ (tru MANIFEST va .gitkeep) co mot dong "<sha256>  <duong dan>".
# Truoc khi tao, script quet ve sinh: khoa rieng lam script dung (exit 1);
# duong dan may ca nhan (/mnt/x/, /Users/ten/, C:\) chi canh bao, dat STRICT=1 de bien thanh loi.
set -eu

DIR="${EVIDENCE_DIR:-bang-chung}"
MANIFEST="$DIR/MANIFEST.txt"
MODE="${1:-generate}"

if command -v sha256sum >/dev/null 2>&1; then
    HASH="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
    HASH="shasum -a 256"
else
    echo "FAIL: khong tim thay sha256sum hoac shasum" >&2
    exit 1
fi

[ -d "$DIR" ] || { echo "FAIL: khong co thu muc $DIR" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

# Danh sach file bang chung, sap xep co dinh de MANIFEST giong nhau o moi may.
LC_ALL=C find "$DIR" -type f ! -name 'MANIFEST.txt' ! -name '.gitkeep' | LC_ALL=C sort > "$WORK/files"

hygiene() {
    bad=0
    warn=0
    while IFS= read -r f; do
        case "$f" in
            *.key|*.pem|*.srl)
                echo "FAIL: file khoa/chung chi rieng trong bang chung: $f"
                bad=$((bad + 1)) ;;
        esac
        if grep -qE -- '-----BEGIN [A-Z ]*PRIVATE KEY-----' "$f" 2>/dev/null; then
            echo "FAIL: co khoa rieng trong $f"
            bad=$((bad + 1))
        fi
        if grep -qE '(/mnt/[a-z]/|/Users/[^/ ]+/|[A-Za-z]:\\)' "$f" 2>/dev/null; then
            echo "WARN: duong dan may ca nhan trong $f"
            warn=$((warn + 1))
        fi
    done < "$WORK/files"
    if [ "$bad" -gt 0 ]; then
        echo "FAIL: $bad loi ve sinh bang chung"
        exit 1
    fi
    if [ "$warn" -gt 0 ] && [ "${STRICT:-0}" = "1" ]; then
        echo "FAIL: STRICT=1 va co $warn canh bao duong dan ca nhan"
        exit 1
    fi
    echo "OK: ve sinh bang chung (loi 0, canh bao $warn)"
}

case "$MODE" in
    generate)
        hygiene
        : > "$WORK/manifest"
        while IFS= read -r f; do
            $HASH "$f" >> "$WORK/manifest"
        done < "$WORK/files"
        n=$(wc -l < "$WORK/manifest" | tr -d ' ')
        if [ "$n" -eq 0 ]; then
            echo "FAIL: bang-chung/ chua co file nao de bam hash" >&2
            exit 1
        fi
        cp "$WORK/manifest" "$MANIFEST"
        echo "PASS: da ghi $MANIFEST ($n file)"
        ;;
    check)
        [ -f "$MANIFEST" ] || { echo "FAIL: chua co $MANIFEST" >&2; exit 1; }
        $HASH -c "$MANIFEST"
        # File moi chua co trong MANIFEST cung la loi: bang chung phai duoc bam het.
        missing=0
        while IFS= read -r f; do
            if ! sed 's/^[0-9a-fA-F]* [ *]//' "$MANIFEST" | tr -d '\r' | grep -qxF -- "$f"; then
                echo "FAIL: $f co trong thu muc nhung khong co trong MANIFEST"
                missing=$((missing + 1))
            fi
        done < "$WORK/files"
        [ "$missing" -eq 0 ] || exit 1
        echo "PASS: MANIFEST khop voi bang-chung/"
        ;;
    *)
        echo "Dung: sh scripts/make-manifest.sh [generate|check]" >&2
        exit 2
        ;;
esac

#!/bin/sh
# scan-secrets.sh - Quet bi mat lo bang gitleaks, ghi ket qua vao bang-chung/secrets/ (Ha).
#
#   sh scripts/scan-secrets.sh
#
# Dung dung phien ban gitleaks va hash sha256 ma cong an toan (cong-an-toan.yml) da ghim,
# nen ket qua o day va ket qua tren CI la cua cung mot chuong trinh.
# Co .git thi quet ca lich su commit; khong co .git (vi du tai zip) thi quet cay thu muc.
# Exit 0 = khong phat hien bi mat; exit 1 = co phat hien hoac khong chay duoc.
# Gia tri bi mat luon bi che (--redact), file ket qua khong chua bi mat that.
set -eu

GL_VERSION="8.18.4"
GL_SHA256="ba6dbb656933921c775ee5a2d1c13a91046e7952e9d919f9bac4cec61d628e7d"
GL_URL="https://github.com/gitleaks/gitleaks/releases/download/v${GL_VERSION}/gitleaks_${GL_VERSION}_linux_x64.tar.gz"

OUT_DIR="${OUT_DIR:-bang-chung/secrets}"
OUT="$OUT_DIR/gitleaks.txt"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
mkdir -p "$OUT_DIR"

# 1. Lay gitleaks: dung ban co san neu dung phien ban ghim, neu khong thi tai ve va kiem hash.
GL=""
if command -v gitleaks >/dev/null 2>&1 && gitleaks version 2>/dev/null | grep -q "$GL_VERSION"; then
    GL="gitleaks"
else
    case "$(uname -s)-$(uname -m)" in
        Linux-x86_64) ;;
        *)
            echo "FAIL: can gitleaks $GL_VERSION. May nay khong phai Linux x86_64 nen script khong tu tai duoc." >&2
            echo "      Cai gitleaks $GL_VERSION roi chay lai." >&2
            exit 1 ;;
    esac
    curl -sSL --fail -o "$WORK/gl.tgz" "$GL_URL"
    echo "$GL_SHA256  $WORK/gl.tgz" | sha256sum -c - >/dev/null
    tar xzf "$WORK/gl.tgz" -C "$WORK" gitleaks
    GL="$WORK/gitleaks"
fi

# 2. Chon che do quet.
if [ -d .git ]; then
    MODE="git (quet lich su commit)"
    COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
    SHALLOW="$(git rev-parse --is-shallow-repository 2>/dev/null || echo unknown)"
    set -- detect --source . --redact --no-banner -v
else
    MODE="no-git (quet cay thu muc, khong co lich su)"
    COMMIT="khong co .git"
    SHALLOW="khong ap dung"
    set -- detect --source . --no-git --redact --no-banner -v
fi

# 3. Chay, giu lai ma thoat (gitleaks tra 1 khi co phat hien).
set +e
"$GL" "$@" > "$WORK/out.txt" 2>&1
RC=$?
set -e

{
    echo "GITLEAKS SECRET SCAN"
    echo "Thoi diem (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Phien ban: gitleaks $GL_VERSION (sha256 goi cai: $GL_SHA256)"
    echo "Che do: $MODE"
    echo "Commit: $COMMIT   Shallow clone: $SHALLOW"
    echo "Lenh: gitleaks $*"
    echo "----- DAU RA CUA GITLEAKS -----"
    sed 's/\x1b\[[0-9;]*m//g' "$WORK/out.txt"
    echo "----- KET QUA -----"
    if [ "$RC" -eq 0 ]; then
        echo "PASS: gitleaks khong phat hien bi mat lo (exit 0)"
    else
        echo "FAIL: gitleaks exit $RC - co phat hien hoac loi chay"
    fi
} > "$OUT"

cat "$OUT"
exit "$RC"

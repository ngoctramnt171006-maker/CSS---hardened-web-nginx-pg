#!/bin/sh
# export-evidence.sh - Dong goi bang-chung/ thanh mot goi nop: kiem ve sinh, bam sha256, nen thanh zip.
#   make export-evidence
# Dau ra: bang-chung/MANIFEST.txt va dist/bang-chung-<ngay>.zip (dist/ da nam trong .gitignore).
set -eu
sh scripts/make-manifest.sh generate
sh scripts/make-manifest.sh check
mkdir -p dist
ZIP="dist/bang-chung-$(date -u +%Y%m%d).zip"
if command -v zip >/dev/null 2>&1; then
    zip -qr "$ZIP" bang-chung
else
    ZIP="dist/bang-chung-$(date -u +%Y%m%d).tar.gz"
    tar czf "$ZIP" bang-chung
fi
echo "PASS: da dong goi $ZIP"

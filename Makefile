# =====================================================================
# Makefile - Nhóm TH-True-Milk (CSS-26C-N03), Chủ đề A
# Cổng của thầy (cong-an-toan.yml) tự chạy: make up -> make verify -> make down
# KHÔNG sửa cong-an-toan.yml.
#
# GHI CHÚ CHO NGƯỜI SỬA FILE NÀY (Trâm)
# 1. Dòng lệnh dưới mỗi target phải thụt bằng phím TAB, không phải dấu cách.
#    Nếu make báo "missing separator" thì dòng đó đang thụt bằng dấu cách.
# 2. Dòng bắt đầu bằng "#" ở sát lề trái là ghi chú, make bỏ qua.
#    Muốn BẬT một dòng kiểm đang để sẵn: xóa đúng ký tự "#" ở đầu dòng (giữ nguyên TAB phía sau) và
#    để dòng lệnh bắt đầu bằng TAB.
# 3. Chỉ bật một dòng khi file script tương ứng đã được merge vào main.
#    Bật khi script chưa có thì make verify sẽ lỗi và CI đỏ.
# 4. Mỗi script phải tự thoát với mã khác 0 khi có ca FAIL (dùng set -eu
#    và exit 1 như scripts/test-nginx.sh). Makefile không tự kiểm hộ.
# 5. Kết quả mỗi script được ghi vào bang-chung/<nhóm>/ để cổng của thầy
#    upload. Không ghi khóa riêng (*.key) hay bí mật vào các file này,
#    gitleaks sẽ quét và làm đỏ cổng.
# 6. Cổng publish thật trong docker-compose.yml là 443, nên BASE_URL mặc
#    định https://localhost trong test-nginx.sh là đúng. Nếu đổi cổng
#    trong compose thì phải đổi BASE_URL cho khớp.
# 7. Thêm ca kiểm mới: viết script trong scripts/, thêm một dòng vào
#    verify theo mẫu bên dưới. Không cần sửa target khác.
# =====================================================================

# bash + pipefail: để "script | tee file" vẫn trả lỗi khi script FAIL.
# Thiếu hai dòng này thì tee che mất mã lỗi và CI vẫn xanh dù ca FAIL.
SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

.PHONY: preflight up attack defend verify export-evidence down

# ---------------------------------------------------------------------
# preflight: kiem moi truong (docker, compose, cong 80/443), ghi kien truc CPU + phien ban.
# ---------------------------------------------------------------------
preflight:
	sh scripts/preflight.sh

# ---------------------------------------------------------------------
# up: sinh chứng chỉ (CI mới clone chưa có file .key) rồi dựng hệ thống.
# --build: build lại image; --wait: chờ container chạy ổn rồi mới trả về.
# ---------------------------------------------------------------------
# Script kiểm tra cặp khóa/chứng chỉ và xử lý tham số OpenSSL cho Git Bash.
up:
	sh scripts/generate-dev-certs.sh
	docker compose up -d --build --wait

# ---------------------------------------------------------------------
# attack: goc nhin ke tan cong (T1,T2,T3,T5), thu tung tan cong, in BLOCKED/SUCCEEDED.
# defend: goc nhin phong thu, doc cau hinh dang chay va so voi gia tri mong doi.
# Can chay sau "make up". Ket qua ghi vao bang-chung/attack/ va bang-chung/defend/.
# ---------------------------------------------------------------------
attack:
	sh scripts/attack.sh

defend:
	sh scripts/defend.sh

# ---------------------------------------------------------------------
# verify: chạy lần lượt các ca kiểm, lưu kết quả vào bang-chung/.
# Người phụ trách: nginx = Trọng, DB = Hảo, web = Chi (nhóm xác nhận lại).
# ---------------------------------------------------------------------
verify:
	mkdir -p bang-chung/nginx bang-chung/web bang-chung/db

# --- ĐÃ CÓ: 3 ca nginx (/, /admin không chứng chỉ, /admin có chứng chỉ)
	sh scripts/test-nginx.sh 2>&1 | tee bang-chung/nginx/test-nginx.txt

# --- ĐÃ BẬT (script đã merge) (Chi): /health, /db-check
	sh scripts/test-web.sh 2>&1 | tee bang-chung/web/test-web.txt

# --- ĐÃ BẬT (script đã merge) (Hảo):
#     T1 phòng A đọc phòng B trả 0 dòng (RLS)
	sh scripts/test-db.sh 2>&1 | tee bang-chung/db/test-db.txt

# --- T3 (Trọng): PostgreSQL TLS, reject non-TLS, web -> DB dùng TLS
	sh scripts/test-t3-db.sh 2>&1 | tee bang-chung/db/test-t3-db.txt

# --- ĐÃ BẬT (script đã merge) (Hảo):
#     T5 pgaudit ghi DDL và ALTER ROLE; script ghi thêm sha256 của log
	sh scripts/test-audit.sh 2>&1 | tee bang-chung/db/test-audit.txt

# --- Ca kiem tich hop M3 (Chi): pytest T1/RLS va T5/pgaudit, ghi vao bang-chung/db/
	sh scripts/test-m3-security.sh 2>&1 | tee bang-chung/db/test-m3-security.txt

# --- Quet bi mat bang gitleaks (ban ghim giong cong), ghi bang-chung/secrets/gitleaks.txt
	sh scripts/scan-secrets.sh

# --- attack/defend: bang chung hanh vi tan cong va trang thai phong thu
	sh scripts/attack.sh
	sh scripts/defend.sh

# --- LUON DE CUOI CUNG: bam sha256 moi file bang chung vao bang-chung/MANIFEST.txt
	sh scripts/make-manifest.sh generate
	sh scripts/make-manifest.sh check

# ---------------------------------------------------------------------
# export-evidence: kiem ve sinh, tao MANIFEST.txt, dong goi bang-chung/ vao dist/.
# ---------------------------------------------------------------------
export-evidence:
	sh scripts/export-evidence.sh

# ---------------------------------------------------------------------
# down: dừng và xóa container + volume để lần chạy sau sạch.
# ---------------------------------------------------------------------
down:
	docker compose down -v

# Thông tin nhóm

Điền trước mốc M0, tức trước buổi S2. Cổng an toàn kiểm tệp này trước mọi thứ khác:
một bài nộp không gắn được với những con người cụ thể thì nó không chấm được.

Tên nhóm: TH-True-Milk

Đề tài: Chủ đề A, dịch vụ web nội bộ nhiều lớp được làm cứng. Hệ thống phải dựng gồm nginx làm cổng vào có TLS và mTLS cho đường quản trị, một ứng dụng web nhỏ, PostgreSQL. Mối đe
dọa phải xử lý gồm truy cập vượt quyền giữa các phòng ban, lộ dữ liệu khi truyền trong mạng
nội bộ, cấu hình mặc định của cơ sở dữ liệu cho phép kết nối không mã hóa. Bằng chứng phải
nộp gồm đầu ra testssl, chính sách row level security kèm ca kiểm âm, log pgaudit, và bảng
đối chiếu trước và sau khi làm cứng.

## Thành viên

| Mã số | Họ và tên | Tài khoản GitHub | Phần việc chính |
|---|---|---|---|
| 31241024918 | Trần Thu Hà | thuhaf1946 | Mô hình đe dọa; khung `docker-compose.yml`, `architecture.md`; bằng chứng "trước" T1/T2/T3/T5, MANIFEST, gitleaks, `attack`/`defend`/`preflight`/`export-evidence`, tính ALE; báo cáo kỹ thuật 7 phần và PDF; quyết định T4; đối chiếu số liệu, kiểm link, gắn thẻ nộp; duyệt PR |
| 31241022521 | Phạm Thị Tú Hảo | haorcine | PostgreSQL: `01-schema.sql`, `02-roles.sql`, `03-rls.sql` (RLS + FORCE), `04-pgaudit.sql`, `test-db.sh`, `test-audit.sh`; slides và kịch bản thuyết trình cho cả nhóm |
| 31241022087 | Nguyễn Thị Ngọc Trâm | ngoctramnt171006-maker | CI/CD: `ci.yml`, `Makefile`, SBOM CycloneDX (Syft), ký và xác minh Cosign; bằng chứng CI (4 tệp, SHA, chạy lại `make verify`); hỗ trợ slides (sơ đồ, kiểm số liệu) và video (lệnh demo, phụ đề, dựng, upload)|
| 31241025188 | Nguyễn Ngọc Quỳnh Chi | quynhchinguyen956-droid | Web Flask: `/health`, `/db-check`, session phòng ban; pytest web, `test-web.sh`, 8 integration pytest T1/T5, `test-m3-security.sh`; video clip 15 phút (khung, cảnh demo, lời dẫn, quay, dựng, đưa lên YouTube) |
| 31241028150 | Hoàng Văn Trọng | trong0x | nginx TLS/mTLS cho `/admin`, `generate-dev-certs.sh`, `test-nginx.sh`, testssl (cả cổng 443); T3 (`hostssl`, `scram-sha-256`, `test-t3-db.sh`); 5 tệp bằng chứng DB sạch, thu hẹp `SELECT` trên `app.users`; mục "Tái lập", README chỉ mục, MANIFEST + `.gitattributes` |

Nhóm từ ba tới năm người.

## Cam kết

Mỗi thành viên đọc rồi ghi tên vào dòng cuối.

Chúng tôi nộp sản phẩm của chính nhóm mình. Mỗi thành viên là tác giả của ít nhất một
pull request được gộp và là người phản biện của ít nhất một pull request của người khác.
Khi dùng công cụ hỗ trợ bằng trí tuệ nhân tạo, chúng tôi khai đầy đủ trong `docs/AI-USE.md`.
Chúng tôi không đưa bí mật thật hay dữ liệu cá nhân thật của bất kì ai vào kho này.

Đã đọc và đồng ý: Trần Thu Hà, Phạm Thị Tú Hảo, Nguyễn Thị Ngọc Trâm, Nguyễn Ngọc Quỳnh Chi, Hoàng Văn Trọng.

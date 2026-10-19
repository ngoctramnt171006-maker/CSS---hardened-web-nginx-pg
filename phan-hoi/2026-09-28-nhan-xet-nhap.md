# Nhận xét chấm nháp M1, nhóm N03 TH-True-Milk

Bản được xem: `main` tại `640340e` (22:27 ngày 28/09/2026). Đây là nhận xét nháp để nhóm sửa trước hạn, **không phải điểm**. Hạn M1: 23:59 thứ Sáu 02/10/2026, tính khi pull request có tiêu đề bắt đầu bằng `M1:` được gộp vào `main` và **đã có một bạn khác trong nhóm duyệt** (Approve).

## Tình trạng

1. `NHOM.md` **còn trống**: chưa có tên nhóm, đề tài, thành viên. Đây là mốc M0 (hạn trước S2) chưa đạt, và M1 cần dòng Đề tài.
2. Nhóm đã có một mô hình đe dọa cho **chủ đề A** (nginx có TLS và mTLS cho đường quản trị, ứng dụng web, PostgreSQL) trong `docs/threat-model.json`, viết theo khuôn JSON của lab S1 và đẩy thẳng lên `main`. Pull request #1 đã đóng mà không gộp.
3. Mục 2 "Mô hình đe dọa" của `docs/bao-cao.md` còn trống. M1 chấm mục 2 của báo cáo, nên cần chuyển nội dung sang đó.

## Nhận xét trên `threat-model.json`

Tốt: thang tác động và khả năng xảy ra có chú giải từng mức, mỗi mối có tác nhân, năng lực, động cơ, mã ATT&CK và điểm ưu tiên; đoạn "nếu lớp ngoài vỡ" lập luận được hai lớp phòng thủ. Cần sửa:

1. **Chỉ ba mối, và T2, T3 trùng nhau** (cùng là bắt gói tin trên đường nội bộ, cùng T1040). M1 cần ít nhất năm mối khác nhau, mỗi mối gắn chữ S, T, R, I, D hay E.
2. **Ranh giới tin cậy** chưa nêu: ai ở ngoài nginx, ai tới được `/admin`, ứng dụng và cơ sở dữ liệu nằm sau ranh giới nào.
3. **Biện pháp cấu hình cho từng mối**: cột "nguyen_ly" mới là nguyên lý; ghi biện pháp cụ thể, ví dụ Row Level Security theo phòng ban, `hostssl` và `ssl = on` trong PostgreSQL, `ssl_verify_client on` cho `/admin`.
4. Trường "nang_luc" và "dong_co" của T3 đang chép giống nhau; "nguyen_ly" của T3 lại là cách tấn công.

## Việc cần làm trước hạn

1. Điền `NHOM.md`: tên nhóm, chủ đề A, đủ thành viên đúng mã số và tài khoản GitHub, phần việc từng người, dòng cam kết.
2. Viết mục 2 một trang từ nội dung JSON, bổ sung như trên. JSON giữ lại trong `docs/` làm phụ lục.

## Cách nộp đúng

Tạo nhánh mới từ `main`, sửa trên nhánh ấy, mở pull request tiêu đề `M1: de tai va mo hinh de doa`. Một bạn **không phải tác giả** đọc, góp ý trong pull request rồi bấm **Review changes → Approve**; sau đó mới bấm **Merge**. Pull request tự gộp mà không ai duyệt thì chưa tính là có phản biện. Không push thẳng và không force push lên `main` (quy tắc ở đầu README kho).

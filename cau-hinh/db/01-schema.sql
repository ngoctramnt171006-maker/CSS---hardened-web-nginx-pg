-- 01-schema.sql: schema cơ bản cho hệ thống nội bộ theo phòng ban.
-- Chạy bằng tài khoản postgres (chủ sở hữu) khi DB khởi tạo lần đầu.
-- Row Level Security sẽ được bật ở mốc M3, M2 chỉ dựng cấu trúc.

-- Schema riêng "app": tách khỏi "public" để kiểm soát quyền rõ ràng.
CREATE SCHEMA IF NOT EXISTS app;

-- Danh mục phòng ban
CREATE TABLE app.departments (
    id    SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code  TEXT NOT NULL UNIQUE,
    name  TEXT NOT NULL
);

-- Tài khoản người dùng ứng dụng (dữ liệu GIẢ).
-- password_hash chỉ là chuỗi giả để test, không phải hash của mật khẩu thật.
CREATE TABLE app.users (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username       TEXT NOT NULL UNIQUE,
    password_hash  TEXT NOT NULL,
    department_id  SMALLINT NOT NULL REFERENCES app.departments(id),
    is_admin       BOOLEAN NOT NULL DEFAULT false
);

-- Tài liệu nội bộ: mỗi dòng thuộc đúng 1 phòng ban.
-- Cột department_id là căn cứ để policy RLS lọc dữ liệu ở M3
-- (policy sẽ so sánh với tham số phiên, ví dụ app.current_department).
CREATE TABLE app.documents (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    department_id  SMALLINT NOT NULL REFERENCES app.departments(id),
    title          TEXT NOT NULL,
    content        TEXT NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_documents_department ON app.documents(department_id);
CREATE INDEX idx_users_department     ON app.users(department_id);

-- ===== Dữ liệu giả để test (đề cấm dùng dữ liệu cá nhân thật) =====
INSERT INTO app.departments (code, name) VALUES
    ('KD', 'Kinh doanh'),
    ('NS', 'Nhan su'),
    ('KT', 'Ke toan');

INSERT INTO app.users (username, password_hash, department_id, is_admin) VALUES
    ('user_kd',  'FAKE_HASH_KD',  1, false),
    ('user_ns',  'FAKE_HASH_NS',  2, false),
    ('user_kt',  'FAKE_HASH_KT',  3, false),
    ('admin_it', 'FAKE_HASH_ADM', 1, true);

INSERT INTO app.documents (department_id, title, content) VALUES
    (1, 'Bao gia mau KD-001',     'Du lieu gia lap phong Kinh doanh'),
    (1, 'Ke hoach quy 4 KD',      'Du lieu gia lap phong Kinh doanh'),
    (2, 'Quy che luong NS-001',   'Du lieu gia lap phong Nhan su'),
    (2, 'Danh sach tuyen dung',   'Du lieu gia lap phong Nhan su'),
    (3, 'Bang can doi KT-001',    'Du lieu gia lap phong Ke toan'),
    (3, 'Bao cao thue quy 3',     'Du lieu gia lap phong Ke toan');
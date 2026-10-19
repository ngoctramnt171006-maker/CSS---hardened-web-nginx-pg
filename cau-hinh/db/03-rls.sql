-- 03-rls.sql: Row Level Security theo phong ban (T1)
-- Contract với web (Chi): tham số phiên app.current_department = department_id (SMALLINT)

ALTER TABLE app.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.documents FORCE ROW LEVEL SECURITY;

CREATE POLICY documents_by_department ON app.documents
    AS PERMISSIVE
    FOR ALL
    TO app_user
    USING (
        department_id = NULLIF(current_setting('app.current_department', true), '')::smallint
    )
    WITH CHECK (
        department_id = NULLIF(current_setting('app.current_department', true), '')::smallint
    );

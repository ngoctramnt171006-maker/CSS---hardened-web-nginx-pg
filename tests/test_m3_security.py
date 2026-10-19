import re
import subprocess
import uuid
from datetime import datetime, timezone
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]


def run_command(command, check=True):
    return subprocess.run(
        command,
        cwd=ROOT_DIR,
        text=True,
        capture_output=True,
        check=check,
    )


def compose(*args, check=True):
    return run_command(["docker", "compose", *args], check=check)


def psql(user, sql, check=True, tuples_only=True):
    command = [
        "exec",
        "-T",
        "db",
        "psql",
        "-v",
        "ON_ERROR_STOP=1",
        "-U",
        user,
        "-d",
        "appdb",
    ]

    if tuples_only:
        command.extend(["-At", "-F", "|"])

    command.extend(["-c", sql])

    return compose(*command, check=check)


def current_utc_timestamp():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# ---------------------------------------------------------------------
# T1 - PostgreSQL Row-Level Security
# ---------------------------------------------------------------------


def test_t1_01_policy_exists_and_rls_is_forced():
    policy = psql(
        "postgres",
        """
        SELECT EXISTS (
            SELECT 1
            FROM pg_policies
            WHERE schemaname = 'app'
              AND tablename = 'documents'
              AND policyname = 'documents_by_department'
              AND cmd = 'ALL'
              AND 'app_user' = ANY(roles)
        );
        """,
    ).stdout.strip()

    assert policy == "t"

    flags = psql(
        "postgres",
        """
        SELECT relrowsecurity, relforcerowsecurity
        FROM pg_class
        WHERE oid = 'app.documents'::regclass;
        """,
    ).stdout.strip()

    assert flags == "t|t"


def test_t1_02_no_department_context_sees_no_documents():
    total_documents = int(
        psql(
            "postgres",
            "SELECT COUNT(*) FROM app.documents;",
        ).stdout.strip()
    )

    assert total_documents > 0, (
        "Seed data must contain documents for this test"
    )

    visible_documents = psql(
        "app_user",
        "SELECT COUNT(*) FROM app.documents;",
    ).stdout.strip()

    assert visible_documents == "0"


def test_t1_03_department_one_sees_only_its_documents():
    baseline = psql(
        "postgres",
        """
        SELECT department_id, COUNT(*)
        FROM app.documents
        GROUP BY department_id
        ORDER BY department_id;
        """,
    ).stdout.strip().splitlines()

    baseline_rows = [
        line.strip()
        for line in baseline
        if re.fullmatch(r"\d+\|\d+", line.strip())
    ]

    assert len(baseline_rows) >= 2, (
        "Seed data must contain documents from at least two departments"
    )

    department_one = [
        row
        for row in baseline_rows
        if row.startswith("1|")
    ]

    assert len(department_one) == 1
    expected_department_one = department_one[0]

    result = psql(
        "app_user",
        """
        BEGIN;
        SELECT set_config('app.current_department', '1', true);
        SELECT department_id, COUNT(*)
        FROM app.documents
        GROUP BY department_id
        ORDER BY department_id;
        COMMIT;
        """,
    ).stdout

    visible_rows = [
        line.strip()
        for line in result.splitlines()
        if re.fullmatch(r"\d+\|\d+", line.strip())
    ]

    assert visible_rows == [expected_department_one]


def test_t1_04_cross_department_insert_is_rejected():
    marker = uuid.uuid4().hex[:12]
    title = f"chi_rls_negative_{marker}"

    result = psql(
        "app_user",
        f"""
        BEGIN;
        SELECT set_config('app.current_department', '1', true);
        INSERT INTO app.documents (department_id, title, content)
        VALUES (2, '{title}', 'M3 T1 negative test');
        COMMIT;
        """,
        check=False,
        tuples_only=False,
    )

    combined_output = result.stdout + result.stderr

    assert result.returncode != 0
    assert "violates row-level security policy" in combined_output

    created = psql(
        "postgres",
        f"""
        SELECT COUNT(*)
        FROM app.documents
        WHERE title = '{title}';
        """,
    ).stdout.strip()

    assert created == "0"


# ---------------------------------------------------------------------
# T5 - pgAudit
# ---------------------------------------------------------------------


def test_t5_01_pgaudit_is_loaded_and_configured():
    shared_preload = psql(
        "postgres",
        "SHOW shared_preload_libraries;",
    ).stdout.strip()

    loaded_libraries = {
        item.strip()
        for item in shared_preload.split(",")
        if item.strip()
    }

    assert "pgaudit" in loaded_libraries

    settings = psql(
        "postgres",
        """
        SELECT current_setting('pgaudit.log'),
               EXISTS (
                   SELECT 1
                   FROM pg_extension
                   WHERE extname = 'pgaudit'
               );
        """,
    ).stdout.strip()

    normalized = settings.replace(" ", "")

    assert normalized == "ddl,role|t"


def test_t5_02_app_user_cannot_create_table():
    marker = uuid.uuid4().hex[:12]
    table_name = f"chi_denied_{marker}"

    result = psql(
        "app_user",
        f"CREATE TABLE app.{table_name}(id int);",
        check=False,
        tuples_only=False,
    )

    combined_output = result.stdout + result.stderr

    assert result.returncode != 0
    assert "permission denied" in combined_output.lower()

    exists = psql(
        "postgres",
        f"""
        SELECT to_regclass('app.{table_name}') IS NOT NULL;
        """,
    ).stdout.strip()

    assert exists == "f"


def test_t5_03_pgaudit_records_current_create_and_drop():
    marker = uuid.uuid4().hex[:12]
    table_name = f"chi_audit_{marker}"

    since = current_utc_timestamp()

    psql(
        "postgres",
        f"CREATE TABLE app.{table_name}(id int);",
        tuples_only=False,
    )

    psql(
        "postgres",
        f"DROP TABLE app.{table_name};",
        tuples_only=False,
    )

    logs = compose(
        "logs",
        "--since",
        since,
        "--no-color",
        "db",
    ).stdout

    assert (
        f"DDL,CREATE TABLE,TABLE,app.{table_name},"
        in logs
    )

    assert (
        f"DDL,DROP TABLE,TABLE,app.{table_name},"
        in logs
    )


def test_t5_04_pgaudit_records_current_alter_role():
    old_limit = int(
        psql(
            "postgres",
            """
            SELECT rolconnlimit
            FROM pg_roles
            WHERE rolname = 'app_user';
            """,
        ).stdout.strip()
    )

    test_limit = 97 if old_limit != 97 else 96
    since = current_utc_timestamp()

    try:
        psql(
            "postgres",
            f"ALTER ROLE app_user CONNECTION LIMIT {test_limit};",
            tuples_only=False,
        )

        logs = compose(
            "logs",
            "--since",
            since,
            "--no-color",
            "db",
        ).stdout

        assert (
            "ROLE,ALTER ROLE,,,ALTER ROLE app_user "
            f"CONNECTION LIMIT {test_limit}"
            in logs
        )

    finally:
        psql(
            "postgres",
            f"ALTER ROLE app_user CONNECTION LIMIT {old_limit};",
            tuples_only=False,
        )

import importlib.util
from pathlib import Path

import psycopg2


APP_PATH = (
    Path(__file__).resolve().parents[1]
    / "ma-nguon"
    / "web"
    / "app.py"
)

spec = importlib.util.spec_from_file_location("th_true_milk_web_app", APP_PATH)
web_app = importlib.util.module_from_spec(spec)
spec.loader.exec_module(web_app)


def test_health_returns_ok():
    client = web_app.app.test_client()

    response = client.get("/health")

    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


def test_db_check_requires_database_url(monkeypatch):
    monkeypatch.setattr(web_app, "DATABASE_URL", None)
    monkeypatch.setattr(web_app, "APP_DEPARTMENT_ID", "1")
    client = web_app.app.test_client()

    response = client.get("/db-check")

    assert response.status_code == 500
    assert response.get_json() == {
        "status": "error",
        "message": "DATABASE_URL is not configured",
    }


def test_db_check_requires_department_id(monkeypatch):
    monkeypatch.setattr(
        web_app,
        "DATABASE_URL",
        "postgresql://app_user:test@db:5432/appdb",
    )
    monkeypatch.setattr(web_app, "APP_DEPARTMENT_ID", None)
    client = web_app.app.test_client()

    response = client.get("/db-check")

    assert response.status_code == 500
    assert response.get_json() == {
        "status": "error",
        "message": "APP_DEPARTMENT_ID is not configured",
    }


def test_db_check_rejects_non_numeric_department(monkeypatch):
    monkeypatch.setattr(
        web_app,
        "DATABASE_URL",
        "postgresql://app_user:test@db:5432/appdb",
    )
    monkeypatch.setattr(web_app, "APP_DEPARTMENT_ID", "KD")
    client = web_app.app.test_client()

    response = client.get("/db-check")

    assert response.status_code == 500
    assert response.get_json() == {
        "status": "error",
        "message": "APP_DEPARTMENT_ID must be a valid SMALLINT department id",
    }


def test_db_check_rejects_department_outside_smallint_range(monkeypatch):
    monkeypatch.setattr(
        web_app,
        "DATABASE_URL",
        "postgresql://app_user:test@db:5432/appdb",
    )
    monkeypatch.setattr(web_app, "APP_DEPARTMENT_ID", "32768")
    client = web_app.app.test_client()

    response = client.get("/db-check")

    assert response.status_code == 500
    assert response.get_json() == {
        "status": "error",
        "message": "APP_DEPARTMENT_ID must be a valid SMALLINT department id",
    }


def test_db_check_returns_503_on_database_error(monkeypatch):
    monkeypatch.setattr(
        web_app,
        "DATABASE_URL",
        "postgresql://app_user:test@db:5432/appdb",
    )
    monkeypatch.setattr(web_app, "APP_DEPARTMENT_ID", "1")

    def fail_connect(*args, **kwargs):
        raise psycopg2.OperationalError("simulated database failure")

    monkeypatch.setattr(web_app.psycopg2, "connect", fail_connect)
    client = web_app.app.test_client()

    response = client.get("/db-check")

    assert response.status_code == 503
    assert response.get_json() == {
        "status": "unavailable",
        "message": "PostgreSQL is not ready or cannot be reached",
    }


class FakeCursor:
    def __init__(self):
        self.last_query = ""
        self.department_id = None
        self.executed = []

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        return False

    def execute(self, query, params=None):
        normalized = " ".join(query.split())
        self.last_query = normalized
        self.executed.append((normalized, params))

        if normalized.startswith(
            "SELECT set_config('app.current_department', %s, true);"
        ):
            self.department_id = int(params[0])

    def fetchone(self):
        if self.last_query == "SELECT current_user, current_database();":
            return "app_user", "appdb"

        raise AssertionError(
            f"Unexpected fetchone() for query: {self.last_query}"
        )

    def fetchall(self):
        if "FROM app.documents" in self.last_query:
            return [(self.department_id, 2)]

        raise AssertionError(
            f"Unexpected fetchall() for query: {self.last_query}"
        )


class FakeConnection:
    def __init__(self):
        self.fake_cursor = FakeCursor()
        self.closed = False

    def cursor(self):
        return self.fake_cursor

    def close(self):
        self.closed = True


def test_db_check_sets_department_session_context(monkeypatch):
    monkeypatch.setattr(
        web_app,
        "DATABASE_URL",
        "postgresql://app_user:test@db:5432/appdb",
    )
    monkeypatch.setattr(web_app, "APP_DEPARTMENT_ID", "1")

    fake_connection = FakeConnection()

    monkeypatch.setattr(
        web_app.psycopg2,
        "connect",
        lambda *args, **kwargs: fake_connection,
    )

    client = web_app.app.test_client()
    response = client.get("/db-check")

    assert response.status_code == 200

    body = response.get_json()
    assert body == {
        "status": "ok",
        "database": "appdb",
        "database_user": "app_user",
        "department_id": 1,
        "visible_departments": [1],
        "visible_document_count": 2,
    }

    assert (
        "SELECT set_config('app.current_department', %s, true);",
        ("1",),
    ) in fake_connection.fake_cursor.executed

    assert fake_connection.closed is True


def test_different_department_contexts_produce_different_results(monkeypatch):
    monkeypatch.setattr(
        web_app,
        "DATABASE_URL",
        "postgresql://app_user:test@db:5432/appdb",
    )

    created_connections = []

    def make_connection(*args, **kwargs):
        connection = FakeConnection()
        created_connections.append(connection)
        return connection

    monkeypatch.setattr(
        web_app.psycopg2,
        "connect",
        make_connection,
    )

    client = web_app.app.test_client()

    monkeypatch.setattr(web_app, "APP_DEPARTMENT_ID", "1")
    response_department_1 = client.get("/db-check")

    monkeypatch.setattr(web_app, "APP_DEPARTMENT_ID", "2")
    response_department_2 = client.get("/db-check")

    assert response_department_1.status_code == 200
    assert response_department_2.status_code == 200

    body_department_1 = response_department_1.get_json()
    body_department_2 = response_department_2.get_json()

    assert body_department_1["department_id"] == 1
    assert body_department_1["visible_departments"] == [1]

    assert body_department_2["department_id"] == 2
    assert body_department_2["visible_departments"] == [2]

    assert body_department_1 != body_department_2

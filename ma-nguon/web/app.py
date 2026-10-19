import os

from flask import Flask, jsonify
import psycopg2


app = Flask(__name__)

DATABASE_URL = os.environ.get("DATABASE_URL")
APP_DEPARTMENT_ID = os.environ.get("APP_DEPARTMENT_ID")


@app.get("/")
def index():
    return jsonify(
        service="TH-True-Milk internal web app",
        status="running",
    )


@app.get("/health")
def health():
    return jsonify(status="ok")


@app.get("/db-check")
def db_check():
    if not DATABASE_URL:
        return jsonify(
            status="error",
            message="DATABASE_URL is not configured",
        ), 500

    if not APP_DEPARTMENT_ID:
        return jsonify(
            status="error",
            message="APP_DEPARTMENT_ID is not configured",
        ), 500

    try:
        department_id = int(APP_DEPARTMENT_ID)
    except ValueError:
        return jsonify(
            status="error",
            message="APP_DEPARTMENT_ID must be a valid SMALLINT department id",
        ), 500

    if department_id < 1 or department_id > 32767:
        return jsonify(
            status="error",
            message="APP_DEPARTMENT_ID must be a valid SMALLINT department id",
        ), 500

    connection = None

    try:
        connection = psycopg2.connect(
            DATABASE_URL,
            connect_timeout=3,
        )

        with connection.cursor() as cursor:
            # Transaction-local session context used by PostgreSQL RLS.
            # Hảo's RLS policy must read the same setting:
            # current_setting('app.current_department', true)
            cursor.execute(
                "SELECT set_config('app.current_department', %s, true);",
                (str(department_id),),
            )

            cursor.execute(
                "SELECT current_user, current_database();"
            )
            database_user, database_name = cursor.fetchone()

            cursor.execute(
                """
                SELECT department_id, COUNT(*)
                FROM app.documents
                GROUP BY department_id
                ORDER BY department_id;
                """
            )
            visible_rows = cursor.fetchall()

        return jsonify(
            status="ok",
            database=database_name,
            database_user=database_user,
            department_id=department_id,
            visible_departments=[row[0] for row in visible_rows],
            visible_document_count=sum(row[1] for row in visible_rows),
        )

    except psycopg2.Error:
        return jsonify(
            status="unavailable",
            message="PostgreSQL is not ready or cannot be reached",
        ), 503

    finally:
        if connection is not None:
            connection.close()


@app.get("/admin")
def admin():
    return jsonify(
        status="ok",
        message="Admin endpoint reached through the internal web application",
    )


if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=8000,
    )

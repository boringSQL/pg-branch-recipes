"""
pytest fixture for per-test database isolation using FILE_COPY.
Requires PostgreSQL 15+. Set file_copy_method=clone in postgresql.conf for speed on 18+.

Usage:
    def test_something(db):
        db.execute("INSERT INTO ...")
"""

import pytest
import psycopg
from uuid import uuid4

ADMIN_DSN = "postgresql://postgres@localhost/postgres"
TEMPLATE_DB = "app_template"


@pytest.fixture(scope="function")
def db():
    name = f"test_{uuid4().hex[:8]}"
    with psycopg.connect(ADMIN_DSN, autocommit=True) as admin:
        admin.execute(
            f'CREATE DATABASE "{name}" TEMPLATE {TEMPLATE_DB} STRATEGY=FILE_COPY'
        )
        try:
            with psycopg.connect(f"postgresql://localhost/{name}") as conn:
                yield conn
        finally:
            admin.execute(f'DROP DATABASE IF EXISTS "{name}" WITH (FORCE)')

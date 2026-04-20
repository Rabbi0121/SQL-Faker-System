from __future__ import annotations

import os
from pathlib import Path
import time

from dotenv import load_dotenv
import psycopg

load_dotenv()

SQL_FILES = [
    Path("sql/001_schema.sql"),
    Path("sql/002_seed_data.sql"),
    Path("sql/003_generators.sql"),
]

MAX_RETRIES = 30
RETRY_DELAY_SECONDS = 2.0


def connect_with_retry(database_url: str) -> psycopg.Connection:
    last_error: Exception | None = None
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            return psycopg.connect(database_url, autocommit=True)
        except Exception as exc:  # pragma: no cover - startup resilience
            last_error = exc
            print(
                f"DB not ready yet (attempt {attempt}/{MAX_RETRIES}): {exc}. "
                f"Retrying in {RETRY_DELAY_SECONDS:.1f}s..."
            )
            time.sleep(RETRY_DELAY_SECONDS)

    raise RuntimeError(
        f"Could not connect to database after {MAX_RETRIES} attempts"
    ) from last_error


def main() -> None:
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        raise RuntimeError("DATABASE_URL is not set")

    with connect_with_retry(database_url) as conn:
        for sql_file in SQL_FILES:
            sql_text = sql_file.read_text(encoding="utf-8")
            conn.execute(sql_text, prepare=False)
            print(f"Applied: {sql_file}")

    print("Database initialization finished.")


if __name__ == "__main__":
    main()

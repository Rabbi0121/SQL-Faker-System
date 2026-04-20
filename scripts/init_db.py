from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv
import psycopg

load_dotenv()

SQL_FILES = [
    Path("sql/001_schema.sql"),
    Path("sql/002_seed_data.sql"),
    Path("sql/003_generators.sql"),
]


def main() -> None:
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        raise RuntimeError("DATABASE_URL is not set")

    with psycopg.connect(database_url, autocommit=True) as conn:
        for sql_file in SQL_FILES:
            sql_text = sql_file.read_text(encoding="utf-8")
            conn.execute(sql_text, prepare=False)
            print(f"Applied: {sql_file}")

    print("Database initialization finished.")


if __name__ == "__main__":
    main()

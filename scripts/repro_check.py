from __future__ import annotations

import os

from dotenv import load_dotenv
import psycopg

load_dotenv()


def main() -> None:
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        raise RuntimeError("DATABASE_URL is not set")

    query = "SELECT * FROM fake.generate_user_batch(%s, %s, %s, %s);"

    with psycopg.connect(database_url, autocommit=True) as conn:
        with conn.cursor() as cur:
            args = ("en_US", 42, 7, 10)
            cur.execute(query, args)
            first = cur.fetchall()

            cur.execute(query, args)
            second = cur.fetchall()

            cur.execute(query, ("en_US", 42, 8, 10))
            third = cur.fetchall()

    same_repro = first == second
    changed_with_batch = first != third

    print(f"same args -> identical rows: {same_repro}")
    print(f"different batch index -> different rows: {changed_with_batch}")

    if not (same_repro and changed_with_batch):
        raise SystemExit(1)


if __name__ == "__main__":
    main()

from __future__ import annotations

import argparse
import os
import time

from dotenv import load_dotenv
import psycopg

load_dotenv()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Benchmark SQL fake-user generation speed.")
    parser.add_argument("--locale", default="en_US", help="Locale code (default: en_US)")
    parser.add_argument("--seed", type=int, default=42, help="Seed value (default: 42)")
    parser.add_argument(
        "--users",
        type=int,
        default=100_000,
        help="Total number of users to generate (default: 100000)",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=1000,
        help="Batch size per procedure call (default: 1000)",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    if args.users <= 0:
        raise ValueError("--users must be > 0")
    if args.batch_size <= 0:
        raise ValueError("--batch-size must be > 0")
    if args.users % args.batch_size != 0:
        raise ValueError("--users must be divisible by --batch-size for this benchmark")

    num_batches = args.users // args.batch_size

    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        raise RuntimeError("DATABASE_URL is not set")

    query = """
        SELECT count(*)
        FROM generate_series(0, %s - 1) AS b(batch_idx)
        CROSS JOIN LATERAL fake.generate_user_batch(%s, %s, b.batch_idx, %s) AS u;
    """

    with psycopg.connect(database_url, autocommit=True) as conn:
        with conn.cursor() as cur:
            warmup_query = "SELECT count(*) FROM fake.generate_user_batch(%s, %s, %s, %s);"
            cur.execute(warmup_query, (args.locale, args.seed, 0, min(args.batch_size, 1000)))
            cur.fetchone()

            started_at = time.perf_counter()
            cur.execute(query, (num_batches, args.locale, args.seed, args.batch_size))
            generated = cur.fetchone()[0]
            elapsed = time.perf_counter() - started_at

    users_per_second = generated / elapsed if elapsed > 0 else float("inf")

    print("Benchmark completed")
    print(f"Locale: {args.locale}")
    print(f"Seed: {args.seed}")
    print(f"Users generated: {generated}")
    print(f"Elapsed: {elapsed:.4f} sec")
    print(f"Throughput: {users_per_second:.2f} users/sec")


if __name__ == "__main__":
    main()

from __future__ import annotations

import csv
from io import StringIO
import os
from typing import Any

from dotenv import load_dotenv
from flask import Flask, Response, redirect, render_template, request, url_for
import psycopg
from psycopg.rows import dict_row

load_dotenv()

DEFAULT_LOCALE = "en_US"
DEFAULT_SEED = 42
DEFAULT_BATCH_SIZE = 10
MIN_BATCH_SIZE = 1
MAX_BATCH_SIZE = 200

app = Flask(__name__)


def parse_int(raw_value: Any, default: int, min_value: int | None = None) -> int:
    try:
        value = int(raw_value)
    except (TypeError, ValueError):
        return default

    if min_value is not None and value < min_value:
        return default

    return value


def get_connection() -> psycopg.Connection:
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        raise RuntimeError("DATABASE_URL is not set")

    return psycopg.connect(database_url, row_factory=dict_row)


def list_locales(conn: psycopg.Connection) -> list[dict[str, Any]]:
    query = "SELECT locale_code, locale_name FROM fake.get_locales();"
    return list(conn.execute(query).fetchall())


def load_batch(
    conn: psycopg.Connection,
    locale: str,
    seed: int,
    batch_index: int,
    batch_size: int,
) -> list[dict[str, Any]]:
    query = """
        SELECT *
        FROM fake.generate_user_batch(%s, %s, %s, %s);
    """
    return list(conn.execute(query, (locale, seed, batch_index, batch_size)).fetchall())


@app.get("/")
def index() -> str:
    locale = request.args.get("locale", DEFAULT_LOCALE)
    seed = parse_int(request.args.get("seed"), DEFAULT_SEED, min_value=0)
    batch_index = parse_int(request.args.get("batch"), 0, min_value=0)
    batch_size = parse_int(request.args.get("batch_size"), DEFAULT_BATCH_SIZE, min_value=MIN_BATCH_SIZE)
    batch_size = max(MIN_BATCH_SIZE, min(MAX_BATCH_SIZE, batch_size))

    users: list[dict[str, Any]] = []
    locales: list[dict[str, Any]] = []
    error_message: str | None = None
    batch_start = batch_index * batch_size
    batch_end = batch_start
    active_locale_name = locale

    try:
        with get_connection() as conn:
            locales = list_locales(conn)
            locale_name_map = {entry["locale_code"]: entry["locale_name"] for entry in locales}
            locale_codes = {entry["locale_code"] for entry in locales}

            if locale not in locale_codes and locales:
                locale = DEFAULT_LOCALE if DEFAULT_LOCALE in locale_codes else locales[0]["locale_code"]

            users = load_batch(conn, locale, seed, batch_index, batch_size)
            active_locale_name = locale_name_map.get(locale, locale)
    except Exception as exc:  # pragma: no cover - runtime feedback path
        error_message = str(exc)

    if users:
        batch_start = users[0]["position_in_stream"]
        batch_end = users[-1]["position_in_stream"]
    else:
        batch_end = batch_start + batch_size - 1

    return render_template(
        "index.html",
        locales=locales,
        users=users,
        selected_locale=locale,
        selected_locale_name=active_locale_name,
        seed=seed,
        batch_index=batch_index,
        batch_size=batch_size,
        batch_start=batch_start,
        batch_end=batch_end,
        locale_count=len(locales),
        user_count=len(users),
        error_message=error_message,
    )


@app.post("/generate")
def generate() -> Any:
    locale = request.form.get("locale", DEFAULT_LOCALE)
    seed = parse_int(request.form.get("seed"), DEFAULT_SEED, min_value=0)
    batch_size = parse_int(request.form.get("batch_size"), DEFAULT_BATCH_SIZE, min_value=MIN_BATCH_SIZE)
    batch_size = max(MIN_BATCH_SIZE, min(MAX_BATCH_SIZE, batch_size))
    return redirect(url_for("index", locale=locale, seed=seed, batch=0, batch_size=batch_size))


@app.post("/next")
def next_batch() -> Any:
    locale = request.form.get("locale", DEFAULT_LOCALE)
    seed = parse_int(request.form.get("seed"), DEFAULT_SEED, min_value=0)
    batch_index = parse_int(request.form.get("batch_index"), 0, min_value=0)
    batch_size = parse_int(request.form.get("batch_size"), DEFAULT_BATCH_SIZE, min_value=MIN_BATCH_SIZE)
    batch_size = max(MIN_BATCH_SIZE, min(MAX_BATCH_SIZE, batch_size))

    return redirect(
        url_for(
            "index",
            locale=locale,
            seed=seed,
            batch=batch_index + 1,
            batch_size=batch_size,
        )
    )


@app.get("/export.csv")
def export_csv() -> Response:
    locale = request.args.get("locale", DEFAULT_LOCALE)
    seed = parse_int(request.args.get("seed"), DEFAULT_SEED, min_value=0)
    batch_index = parse_int(request.args.get("batch"), 0, min_value=0)
    batch_size = parse_int(request.args.get("batch_size"), DEFAULT_BATCH_SIZE, min_value=MIN_BATCH_SIZE)
    batch_size = max(MIN_BATCH_SIZE, min(MAX_BATCH_SIZE, batch_size))

    users: list[dict[str, Any]] = []
    with get_connection() as conn:
        users = load_batch(conn, locale, seed, batch_index, batch_size)

    output = StringIO()
    writer = csv.writer(output)
    writer.writerow(
        [
            "position_in_stream",
            "full_name",
            "address",
            "latitude",
            "longitude",
            "height_cm",
            "weight_kg",
            "eye_color",
            "phone",
            "email",
            "locale_code",
            "seed_value",
            "batch_index",
            "index_in_batch",
        ]
    )
    for user in users:
        writer.writerow(
            [
                user["position_in_stream"],
                user["full_name"],
                user["address"],
                user["latitude"],
                user["longitude"],
                user["height_cm"],
                user["weight_kg"],
                user["eye_color"],
                user["phone"],
                user["email"],
                user["locale_code"],
                user["seed_value"],
                user["batch_index"],
                user["index_in_batch"],
            ]
        )

    filename = f"fake_contacts_{locale}_seed_{seed}_batch_{batch_index}_size_{batch_size}.csv"
    return Response(
        output.getvalue(),
        mimetype="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )


if __name__ == "__main__":
    port = parse_int(os.getenv("PORT"), 8000, min_value=1)
    debug_mode = os.getenv("FLASK_DEBUG", "0") == "1"
    app.run(host="0.0.0.0", port=port, debug=debug_mode)

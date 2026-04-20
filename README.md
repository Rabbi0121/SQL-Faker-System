# Task 6_DATA - SQL Faker Contacts

Web application for deterministic fake contact generation.

- Data generation is implemented in PostgreSQL stored procedures/functions.
- Python (Flask) is used only to render HTML and fetch records from DB.
- Supports two locales: `en_US` and `de_DE`.
- Seed-based reproducible generation with batch paging.

## Project Structure

- `app/main.py` - Flask app
- `app/templates/index.html` - UI
- `sql/001_schema.sql` - schema
- `sql/002_seed_data.sql` - large locale lookup data
- `sql/003_generators.sql` - stored procedures/functions
- `docs/stored_procedures.md` - SQL library docs
- `scripts/init_db.py` - applies SQL files
- `scripts/benchmark.py` - throughput benchmark (users/sec)
- `scripts/repro_check.py` - deterministic reproducibility smoke test
- `Dockerfile` + `docker-compose.yml` - optional containerized run

## 1) Prerequisites

- Python 3.12+
- PostgreSQL 14+ (local or remote)

## 2) Python Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

Set `DATABASE_URL` in `.env`.

Example:

```bash
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/fake_contacts
```

## 3) Initialize Database

Create the target database first (example using `createdb`/`psql`):

```bash
createdb fake_contacts
```

Then apply SQL via Python script:

```bash
python scripts/init_db.py
```

## 4) Run Web App

```bash
python app/main.py
```

Open:

- `http://localhost:8000`

Behavior:

- Choose locale + seed and generate first batch.
- Click **Next Batch** to request the next deterministic chunk for same arguments.

## 4.1) Run with Docker Compose (Optional)

```bash
docker compose up --build
```

Open:

- `http://localhost:8000`

## 4.2) Deploy on Render (Recommended for Public URL)

This repo now includes a Render blueprint file:

- `render.yaml`

Deploy steps:

1. Push the latest code to GitHub.
2. In Render dashboard, click `New` -> `Blueprint`.
3. Select this repository and branch `main`.
4. Render will create:
   - PostgreSQL database (`sql-faker-db`)
   - Web service (`sql-faker-system`)
5. After deployment finishes, open your Render URL.

Notes:

- `DATABASE_URL` is automatically connected from the managed Render database via `render.yaml`.
- Web startup runs DB initialization automatically (`python scripts/init_db.py`) before serving.

## 5) Benchmark (Users/Second)

Run benchmark for 100,000 users:

```bash
python scripts/benchmark.py --locale en_US --seed 42 --users 100000 --batch-size 1000
```

Output includes:

- elapsed time
- throughput in `users/sec`

## 6) Reproducibility Check

Run:

```bash
python scripts/repro_check.py
```

It validates:

- same `(locale, seed, batch_index, batch_size)` -> identical rows
- changed batch index -> different rows

## 7) Stored Procedure Documentation

See:

- `docs/stored_procedures.md`

## Notes for Submission

For your assignment package, include:

1. Video demo recording of the running app.
2. Link to stored procedure docs (`docs/stored_procedures.md` in your repo).
3. Link to deployed web app.
4. Benchmark output from `scripts/benchmark.py`.
5. Your full name.

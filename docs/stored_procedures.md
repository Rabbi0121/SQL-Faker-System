# SQL Faker Library Documentation (PostgreSQL)

This project implements a deterministic fake-data generator fully inside PostgreSQL schema `fake`.
Python is used only for UI and DB calls. All generated values come from SQL functions/procedures.

The library behaves like a SQL-native Faker.

## 1) Core Design Goals

- Extensible locale-aware data model (single tables with `locale_code`, not per-language tables).
- Deterministic pseudo-random generation.
- Batch pagination support.
- Realistic structured output (names, addresses, geolocation, physical traits, phone, email).

## 2) Reproducibility Contract

All generated values for one person are derived from this deterministic key:

`key = locale || '|' || seed || '|' || batch_index || '|' || index_in_batch`

If `(locale, seed, batch_index, index_in_batch)` is unchanged and lookup tables are unchanged,
the generated user row is exactly the same.

## 3) Data Model (Extensible by Locale)

### Table: `fake.locales`
Locale metadata.

Columns:

- `locale_code` (PK) e.g. `en_US`, `de_DE`
- `locale_name`
- `country_code`
- `default_email_domain`
- `phone_country_code`

### Table: `fake.names`
Unified names table.

Columns:

- `locale_code` (FK -> `fake.locales`)
- `name_type` in `('title','first','middle','last')`
- `gender` in `('M','F','N')`
- `value`
- `weight`

### Table: `fake.lexicon`
Unified locale tokens.

Examples of `token_type`:

- `city`, `region`, `street_word`, `street_suffix`
- `phone_pattern`, `email_domain`
- `eye_color`, `name_suffix`, `unit_word`
- `us_area_code` (for realistic US phone numbers)

## 4) Function Catalog

## `fake.get_locales()`
Signature:

`fake.get_locales() -> TABLE(locale_code text, locale_name text)`

Purpose:

- Returns supported locales for UI selectors or API clients.

## `fake.hash_u60(p_text text)`
Signature:

`fake.hash_u60(p_text text) -> bigint`

Arguments:

- `p_text`: input text to hash.

Algorithm:

- MD5 of text.
- Take first 60 bits and convert to positive integer.

Purpose:

- Deterministic numeric entropy source.

## `fake.rand_uniform(p_key text, p_stream int default 0)`
Signature:

`fake.rand_uniform(p_key text, p_stream int) -> double precision`

Arguments:

- `p_key`: deterministic record key.
- `p_stream`: stream id so different attributes do not collide.

Algorithm:

- `u = hash_u60(p_key || ':' || p_stream) / 2^60`
- Returns `u` in `[0,1)`.

## `fake.rand_int(p_key text, p_stream int, p_min int, p_max int)`
Signature:

`fake.rand_int(...) -> int`

Arguments:

- `p_key`, `p_stream`: deterministic randomness input.
- `p_min`, `p_max`: inclusive integer bounds.

Algorithm:

- `floor(rand_uniform * (p_max - p_min + 1)) + p_min`

## `fake.rand_bool(p_key text, p_stream int, p_probability double precision default 0.5)`
Signature:

`fake.rand_bool(...) -> boolean`

Algorithm:

- Bernoulli draw using `rand_uniform < probability`.

## `fake.rand_normal(p_key text, p_stream int, p_mean double precision default 0, p_stddev double precision default 1)`
Signature:

`fake.rand_normal(...) -> double precision`

Algorithm (Box-Muller):

- `u1 = max(rand_uniform(stream), 1e-12)`
- `u2 = rand_uniform(stream + 1)`
- `z = sqrt(-2 ln(u1)) * cos(2*pi*u2)`
- `x = mean + stddev * z`

Purpose:

- Normally distributed physical measurements.

## `fake.pick_name(p_locale text, p_name_type text, p_gender text, p_key text, p_stream int default 0)`
Signature:

`fake.pick_name(...) -> text`

Arguments:

- `p_locale`: locale code.
- `p_name_type`: `title|first|middle|last`.
- `p_gender`: `M|F|N|NULL` (`NULL` means no gender filter).
- `p_key`, `p_stream`: deterministic random selector.

Algorithm:

- Weighted pick using cumulative weights in `fake.names`.

## `fake.pick_lexicon(p_locale text, p_token_type text, p_key text, p_stream int default 0)`
Signature:

`fake.pick_lexicon(...) -> text`

Arguments:

- `p_locale`, `p_token_type`: token namespace.
- `p_key`, `p_stream`: deterministic selector.

Algorithm:

- Weighted cumulative pick from `fake.lexicon`.

## `fake.render_pattern(p_pattern text, p_key text, p_stream_offset int default 0)`
Signature:

`fake.render_pattern(...) -> text`

Pattern placeholders:

- `#` -> digit `0..9`
- `N` -> digit `2..9` (used for leading network digits)

Purpose:

- Locale-specific formatted string generation, especially phones.

## `fake.slug_part(p_text text)`
Signature:

`fake.slug_part(...) -> text`

Purpose:

- Converts text to lowercase alphanumeric token for email local-parts.

## `fake.generate_name(p_locale text, p_seed bigint, p_batch_index int, p_index_in_batch int)`
Signature:

`fake.generate_name(...) -> TABLE(full_name, first_name, middle_name, last_name, gender)`

Name customization logic:

- Gender is deterministic.
- Optional middle name (~45%).
- Optional title (~30%).
- Optional suffix (~10%).
- Multiple formatting variants, including `Last, First ...`.

## `fake.generate_address(p_locale text, p_key text)`
Signature:

`fake.generate_address(...) -> text`

Purpose:

- Locale-aware address with formatting variations.

Examples:

- `en_US`: house + street + suffix + city + region + ZIP (optional unit)
- `de_DE`: locale-specific ordering and style (optional unit)

## `fake.generate_geo(p_key text)`
Signature:

`fake.generate_geo(...) -> TABLE(latitude double precision, longitude double precision)`

Algorithm (uniform on sphere):

- `u, v ~ Uniform[0,1)`
- `longitude = 360*u - 180`
- `z = 2*v - 1` (uniform in `[-1,1]`)
- `latitude = asin(z)` in radians, converted to degrees

Why this is correct:

- Area element on sphere depends on `cos(latitude)`.
- Sampling `z = sin(latitude)` uniformly avoids pole clustering.
- Therefore point density is constant on sphere surface.

## `fake.generate_physical(p_locale text, p_gender text, p_key text)`
Signature:

`fake.generate_physical(...) -> TABLE(height_cm numeric(5,2), weight_kg numeric(6,2), eye_color text)`

Algorithm:

- Height and weight from normal distributions (`rand_normal`).
- Means/stddev depend on gender and locale.
- Values are clamped to realistic ranges.
- Eye color sampled from discrete lexicon.

## `fake.generate_phone(p_locale text, p_key text)`
Signature:

`fake.generate_phone(...) -> text`

Generation logic:

- `en_US`:
  - Area code from curated `us_area_code` lexicon (realistic set).
  - Exchange generated with NANP-like constraints.
  - Multiple output formats (`+1-AAA-EEE-LLLL`, `(AAA) EEE-LLLL`, etc).
- Other locales:
  - Uses locale `phone_pattern` + `render_pattern`.

## `fake.generate_email(p_locale text, p_first_name text, p_last_name text, p_key text)`
Signature:

`fake.generate_email(...) -> text`

Logic:

- Normalize first/last name via `slug_part`.
- Choose one of multiple deterministic local-part formats.
- Append locale-specific email domain.

## `fake.generate_user(p_locale text, p_seed bigint, p_batch_index int, p_index_in_batch int)`
Signature:

`fake.generate_user(...) -> TABLE(full_name, address, latitude, longitude, height_cm, weight_kg, eye_color, phone, email)`

Purpose:

- Composes all individual generators for one row.

## `fake.generate_user_batch(p_locale text, p_seed bigint, p_batch_index int, p_batch_size int default 10)`
Signature:

`fake.generate_user_batch(...) -> TABLE(...)`

Returned columns:

- `locale_code`, `seed_value`, `batch_index`, `index_in_batch`, `position_in_stream`
- `full_name`, `address`, `latitude`, `longitude`
- `height_cm`, `weight_kg`, `eye_color`
- `phone`, `email`

Purpose:

- Primary public API for application/UI.

## `fake.lookup_cardinality()`
Signature:

`fake.lookup_cardinality() -> TABLE(locale_code, names_rows, lexicon_rows)`

Purpose:

- Audits lookup table size per locale.

## 5) How to Use the SQL Faker Library

## Step 1: Initialize DB Objects

Apply SQL files in order:

- `sql/001_schema.sql`
- `sql/002_seed_data.sql`
- `sql/003_generators.sql`

## Step 2: List Available Locales

```sql
SELECT * FROM fake.get_locales();
```

## Step 3: Generate First Batch

```sql
SELECT *
FROM fake.generate_user_batch('en_US', 42, 0, 10);
```

## Step 4: Get Next Batch (same locale/seed)

```sql
SELECT *
FROM fake.generate_user_batch('en_US', 42, 1, 10);
```

## Step 5: Determinism Check

```sql
SELECT * FROM fake.generate_user_batch('de_DE', 12345, 7, 10);
SELECT * FROM fake.generate_user_batch('de_DE', 12345, 7, 10);
```

The two result sets are identical.

## 6) Extending to New Locale

To add a locale (for example `fr_FR`):

1. Insert locale metadata into `fake.locales`.
2. Insert name rows into `fake.names` for `title/first/middle/last`.
3. Insert token rows into `fake.lexicon` (`city`, `street_word`, `region`, `phone_pattern`, etc).
4. No schema changes required.

## 7) Notes and Constraints

- Determinism assumes lookup tables are unchanged.
- `p_batch_size` is validated in SQL (`1..1000`).
- Geolocation generation is mathematically uniform on sphere surface.
- Physical measurements are stochastic-normal but bounded.

## 8) Library Identity ("Faker in SQL")

This schema provides a reusable SQL-native fake data library with deterministic PRNG,
locale-aware tokenization, weighted lookup selection, and composable generators.

Main public API for apps:

`fake.generate_user_batch(locale, seed, batch_index, batch_size)`

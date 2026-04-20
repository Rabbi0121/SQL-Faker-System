# SQL Faker Library Documentation

This project implements fake contact generation **inside PostgreSQL** in schema `fake`.
All randomness is deterministic and reproducible for the tuple:

- `locale`
- `seed`
- `batch_index`
- `index_in_batch`

At a fixed database state, identical arguments always return identical rows.

## 1) Data Model

### `fake.locales`
Locale metadata (`en_US`, `de_DE`, extensible).

### `fake.names`
Unified names table (extensible by locale and type):

- `name_type`: `title`, `first`, `middle`, `last`
- `gender`: `M`, `F`, `N`

### `fake.lexicon`
Unified locale lexicon table for all non-name tokens:

- `city`
- `region`
- `street_word`
- `street_suffix`
- `phone_pattern`
- `email_domain`
- `eye_color`
- `name_suffix`
- `unit_word`

No locale-specific schema duplication is used (no separate `english_names`/`german_names` tables).

## 2) Core Deterministic RNG Procedures/Functions

## `fake.hash_u60(p_text text) -> bigint`
Returns a deterministic 60-bit integer from `md5(p_text)`.

## `fake.rand_uniform(p_key text, p_stream int default 0) -> double precision`
Returns deterministic `U ~ Uniform[0,1)`.

Algorithm:

- `u = hash_u60(key || ':' || stream) / 2^60`

## `fake.rand_int(p_key text, p_stream int, p_min int, p_max int) -> int`
Deterministic integer in `[p_min, p_max]`.

Algorithm:

- `floor(rand_uniform * (p_max - p_min + 1)) + p_min`

## `fake.rand_bool(p_key text, p_stream int, p_probability double precision default 0.5) -> bool`
Returns deterministic Bernoulli draw.

## `fake.rand_normal(p_key text, p_stream int, p_mean double precision default 0, p_stddev double precision default 1) -> double precision`
Deterministic normal draw using **Box-Muller transform**.

Algorithm:

- `u1 = max(rand_uniform(stream), 1e-12)`
- `u2 = rand_uniform(stream + 1)`
- `z = sqrt(-2 ln u1) * cos(2*pi*u2)`
- `x = mean + stddev * z`

## 3) Lookup Selectors

## `fake.pick_name(p_locale, p_name_type, p_gender, p_key, p_stream default 0) -> text`
Weighted deterministic picker from `fake.names`.

## `fake.pick_lexicon(p_locale, p_token_type, p_key, p_stream default 0) -> text`
Weighted deterministic picker from `fake.lexicon`.

Both functions use cumulative-weight selection with deterministic target rank.

## 4) Formatting/Composition Helpers

## `fake.render_pattern(p_pattern, p_key, p_stream_offset default 0) -> text`
Renders pattern strings where placeholders are replaced by deterministic digits.

- `#` -> any digit `0..9`
- `N` -> leading network digit `2..9` (used for more realistic phone prefixes)

Used for phone formatting variations.

## `fake.slug_part(p_text) -> text`
Normalizes text for email local-parts (`lowercase`, alnum only).

## 5) Entity Generators

## `fake.generate_name(p_locale, p_seed, p_batch_index, p_index_in_batch)`
Returns:

- `full_name`
- `first_name`
- `middle_name`
- `last_name`
- `gender`

Variations:

- optional title
- optional middle name
- optional suffix
- multiple output formats (e.g., `First Last`, `Last, First`, with/without title)

## `fake.generate_address(p_locale, p_key) -> text`
Locale-dependent address synthesis with formatting variations.

- `en_US`: house + street + suffix + city + state + ZIP, optional unit
- `de_DE`: street-style with house number and locale-specific ordering, optional unit

## `fake.generate_geo(p_key)`
Returns `latitude`, `longitude` with **uniform distribution on the sphere**.

Algorithm:

- `u, v ~ Uniform[0,1)`
- `longitude = 360*u - 180`
- `z = 2*v - 1` (uniform in `[-1,1]`)
- `latitude = asin(z)` (converted to degrees)

This avoids pole clustering from naive uniform-latitude sampling.

## `fake.generate_physical(p_locale, p_gender, p_key)`
Returns:

- `height_cm` (normal distribution, clamped)
- `weight_kg` (normal distribution, clamped)
- `eye_color` (discrete weighted draw)

## `fake.generate_phone(p_locale, p_key) -> text`
Uses locale-specific phone patterns and deterministic digit rendering.
US generation uses a curated `us_area_code` lexicon plus NANP-like exchange constraints.
This avoids unrealistic random area codes and blocks `N11`-style exchanges.

## `fake.generate_email(p_locale, p_first_name, p_last_name, p_key) -> text`
Creates deterministic email variants from name parts and locale domains.

## `fake.generate_user(p_locale, p_seed, p_batch_index, p_index_in_batch)`
Returns one fully composed fake contact row.

## `fake.generate_user_batch(p_locale, p_seed, p_batch_index, p_batch_size default 10)`
Main batch API for the web app. Returns a deterministic set of users for the requested window.

Output columns include:

- stream position
- full name
- address
- geolocation
- physical traits
- phone
- email

## `fake.lookup_cardinality()`
Returns counts of lookup rows per locale for names and lexicon.

## 6) Reproducibility Contract

Determinism source key:

- `key = locale || '|' || seed || '|' || batch_index || '|' || index_in_batch`

All generator procedures derive values only from this key and fixed stream offsets.
Therefore, same input tuple always produces the same user.

## 7) Usage Examples

```sql
SELECT *
FROM fake.generate_user_batch('en_US', 123456, 0, 10);
```

```sql
SELECT *
FROM fake.generate_user_batch('de_DE', 123456, 1, 10);
```

```sql
SELECT *
FROM fake.lookup_cardinality();
```

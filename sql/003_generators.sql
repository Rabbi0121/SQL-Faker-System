BEGIN;

CREATE OR REPLACE FUNCTION fake.get_locales()
RETURNS TABLE(locale_code TEXT, locale_name TEXT)
LANGUAGE sql
STABLE
AS $$
    SELECT l.locale_code, l.locale_name
    FROM fake.locales AS l
    ORDER BY l.locale_code;
$$;

CREATE OR REPLACE FUNCTION fake.hash_u60(p_text TEXT)
RETURNS BIGINT
LANGUAGE sql
IMMUTABLE
STRICT
PARALLEL SAFE
AS $$
    SELECT (('x' || substr(md5(p_text), 1, 15))::bit(60)::bigint);
$$;

CREATE OR REPLACE FUNCTION fake.rand_uniform(p_key TEXT, p_stream INTEGER DEFAULT 0)
RETURNS DOUBLE PRECISION
LANGUAGE sql
IMMUTABLE
STRICT
PARALLEL SAFE
AS $$
    SELECT fake.hash_u60(p_key || ':' || p_stream)::double precision / 1152921504606846976.0;
$$;

CREATE OR REPLACE FUNCTION fake.rand_int(
    p_key TEXT,
    p_stream INTEGER,
    p_min INTEGER,
    p_max INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql
IMMUTABLE
STRICT
PARALLEL SAFE
AS $$
DECLARE
    v_span BIGINT;
BEGIN
    IF p_min > p_max THEN
        RAISE EXCEPTION 'Invalid range for rand_int: min % > max %', p_min, p_max;
    END IF;

    v_span := (p_max::bigint - p_min::bigint + 1);
    RETURN p_min + floor(fake.rand_uniform(p_key, p_stream) * v_span)::integer;
END;
$$;

CREATE OR REPLACE FUNCTION fake.rand_bool(
    p_key TEXT,
    p_stream INTEGER,
    p_probability DOUBLE PRECISION DEFAULT 0.5
)
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
STRICT
PARALLEL SAFE
AS $$
    SELECT fake.rand_uniform(p_key, p_stream) < p_probability;
$$;

CREATE OR REPLACE FUNCTION fake.rand_normal(
    p_key TEXT,
    p_stream INTEGER,
    p_mean DOUBLE PRECISION DEFAULT 0.0,
    p_stddev DOUBLE PRECISION DEFAULT 1.0
)
RETURNS DOUBLE PRECISION
LANGUAGE sql
IMMUTABLE
STRICT
PARALLEL SAFE
AS $$
    WITH u AS (
        SELECT
            GREATEST(fake.rand_uniform(p_key, p_stream), 1e-12) AS u1,
            fake.rand_uniform(p_key, p_stream + 1) AS u2
    )
    SELECT p_mean + p_stddev * (sqrt(-2.0 * ln(u1)) * cos(2.0 * pi() * u2))
    FROM u;
$$;

CREATE OR REPLACE FUNCTION fake.pick_name(
    p_locale TEXT,
    p_name_type TEXT,
    p_gender TEXT,
    p_key TEXT,
    p_stream INTEGER DEFAULT 0
)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_total INTEGER;
    v_target INTEGER;
    v_value TEXT;
BEGIN
    SELECT COALESCE(SUM(n.weight), 0)
    INTO v_total
    FROM fake.names AS n
    WHERE n.locale_code = p_locale
      AND n.name_type = p_name_type
      AND (p_gender IS NULL OR n.gender = p_gender OR n.gender = 'N');

    IF v_total = 0 THEN
        RAISE EXCEPTION 'No names available for locale %, type %, gender %', p_locale, p_name_type, p_gender;
    END IF;

    v_target := fake.rand_int(p_key, p_stream, 1, v_total);

    SELECT c.value
    INTO v_value
    FROM (
        SELECT
            n.value,
            SUM(n.weight) OVER (ORDER BY n.name_id) AS cumulative_weight
        FROM fake.names AS n
        WHERE n.locale_code = p_locale
          AND n.name_type = p_name_type
          AND (p_gender IS NULL OR n.gender = p_gender OR n.gender = 'N')
    ) AS c
    WHERE c.cumulative_weight >= v_target
    ORDER BY c.cumulative_weight
    LIMIT 1;

    RETURN v_value;
END;
$$;

CREATE OR REPLACE FUNCTION fake.pick_lexicon(
    p_locale TEXT,
    p_token_type TEXT,
    p_key TEXT,
    p_stream INTEGER DEFAULT 0
)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
STRICT
AS $$
DECLARE
    v_total INTEGER;
    v_target INTEGER;
    v_value TEXT;
BEGIN
    SELECT COALESCE(SUM(l.weight), 0)
    INTO v_total
    FROM fake.lexicon AS l
    WHERE l.locale_code = p_locale
      AND l.token_type = p_token_type;

    IF v_total = 0 THEN
        RAISE EXCEPTION 'No lexicon values available for locale %, token_type %', p_locale, p_token_type;
    END IF;

    v_target := fake.rand_int(p_key, p_stream, 1, v_total);

    SELECT c.value
    INTO v_value
    FROM (
        SELECT
            l.value,
            SUM(l.weight) OVER (ORDER BY l.lex_id) AS cumulative_weight
        FROM fake.lexicon AS l
        WHERE l.locale_code = p_locale
          AND l.token_type = p_token_type
    ) AS c
    WHERE c.cumulative_weight >= v_target
    ORDER BY c.cumulative_weight
    LIMIT 1;

    RETURN v_value;
END;
$$;

CREATE OR REPLACE FUNCTION fake.render_pattern(
    p_pattern TEXT,
    p_key TEXT,
    p_stream_offset INTEGER DEFAULT 0
)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
STRICT
PARALLEL SAFE
AS $$
DECLARE
    v_result TEXT := '';
    v_char TEXT;
    i INTEGER;
BEGIN
    FOR i IN 1..char_length(p_pattern) LOOP
        v_char := substr(p_pattern, i, 1);
        IF v_char = '#' THEN
            v_result := v_result || fake.rand_int(p_key, p_stream_offset + i, 0, 9)::text;
        ELSIF v_char = 'N' THEN
            -- N means a non-zero/non-one leading digit (2..9), useful for realistic phone prefixes.
            v_result := v_result || fake.rand_int(p_key, p_stream_offset + i, 2, 9)::text;
        ELSE
            v_result := v_result || v_char;
        END IF;
    END LOOP;

    RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION fake.slug_part(p_text TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
STRICT
PARALLEL SAFE
AS $$
    SELECT COALESCE(
        NULLIF(regexp_replace(lower(p_text), '[^a-z0-9]+', '', 'g'), ''),
        'x'
    );
$$;

CREATE OR REPLACE FUNCTION fake.generate_name(
    p_locale TEXT,
    p_seed BIGINT,
    p_batch_index INTEGER,
    p_index_in_batch INTEGER
)
RETURNS TABLE(
    full_name TEXT,
    first_name TEXT,
    middle_name TEXT,
    last_name TEXT,
    gender TEXT
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_key TEXT := format('%s|%s|%s|%s', p_locale, p_seed, p_batch_index, p_index_in_batch);
    v_title TEXT;
    v_name_format INTEGER;
BEGIN
    gender := CASE WHEN fake.rand_uniform(v_key, 10) < 0.5 THEN 'M' ELSE 'F' END;
    first_name := fake.pick_name(p_locale, 'first', gender, v_key, 11);
    last_name := fake.pick_name(p_locale, 'last', NULL, v_key, 12);

    IF fake.rand_bool(v_key, 13, 0.45) THEN
        middle_name := fake.pick_name(p_locale, 'middle', gender, v_key, 14);
    ELSE
        middle_name := NULL;
    END IF;

    IF fake.rand_bool(v_key, 15, 0.30) THEN
        v_title := fake.pick_name(p_locale, 'title', gender, v_key, 16);
    ELSE
        v_title := NULL;
    END IF;

    v_name_format := fake.rand_int(v_key, 17, 1, 3);

    IF v_name_format = 1 THEN
        full_name := concat_ws(' ', v_title, first_name, middle_name, last_name);
    ELSIF v_name_format = 2 THEN
        full_name := concat_ws(' ', first_name, middle_name, last_name);
    ELSE
        full_name := last_name || ', ' || concat_ws(' ', v_title, first_name, middle_name);
    END IF;

    IF fake.rand_bool(v_key, 18, 0.10) THEN
        full_name := full_name || ' ' || fake.pick_lexicon(p_locale, 'name_suffix', v_key, 19);
    END IF;

    full_name := trim(regexp_replace(full_name, '[[:space:]]+', ' ', 'g'));
    RETURN NEXT;
END;
$$;

CREATE OR REPLACE FUNCTION fake.generate_address(
    p_locale TEXT,
    p_key TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
STRICT
AS $$
DECLARE
    v_house INTEGER;
    v_unit INTEGER;
    v_house_suffix TEXT;
    v_street_word TEXT;
    v_street_suffix TEXT;
    v_city TEXT;
    v_region TEXT;
    v_postal TEXT;
    v_unit_word TEXT;
    v_variant INTEGER;
    v_with_unit BOOLEAN;
BEGIN
    v_house := fake.rand_int(p_key, 30, 1, 9999);
    v_unit := fake.rand_int(p_key, 31, 1, 999);
    v_street_word := fake.pick_lexicon(p_locale, 'street_word', p_key, 32);
    v_street_suffix := fake.pick_lexicon(p_locale, 'street_suffix', p_key, 33);
    v_city := fake.pick_lexicon(p_locale, 'city', p_key, 34);
    v_region := fake.pick_lexicon(p_locale, 'region', p_key, 35);
    v_unit_word := fake.pick_lexicon(p_locale, 'unit_word', p_key, 36);
    v_variant := fake.rand_int(p_key, 37, 1, 3);
    v_with_unit := fake.rand_bool(p_key, 38, 0.28);

    IF p_locale = 'en_US' THEN
        v_postal := lpad(fake.rand_int(p_key, 39, 0, 99999)::text, 5, '0');

        IF v_variant = 1 THEN
            RETURN format('%s %s %s, %s, %s %s', v_house, v_street_word, v_street_suffix, v_city, v_region, v_postal);
        ELSIF v_with_unit THEN
            RETURN format('%s %s %s %s %s, %s, %s %s', v_house, v_street_word, v_street_suffix, v_unit_word, v_unit, v_city, v_region, v_postal);
        ELSE
            RETURN format('%s %s %s, %s, %s %s', v_house, v_street_word, v_street_suffix, v_city, v_region, v_postal);
        END IF;
    END IF;

    v_postal := lpad(fake.rand_int(p_key, 39, 10000, 99999)::text, 5, '0');
    v_house_suffix := chr(ascii('A') + fake.rand_int(p_key, 40, 0, 5));

    IF v_with_unit THEN
        RETURN format('%s%s %s%s, %s %s, %s %s', v_street_word, v_street_suffix, v_house, v_house_suffix, v_postal, v_city, v_unit_word, v_unit);
    ELSIF v_variant = 1 THEN
        RETURN format('%s%s %s, %s %s', v_street_word, v_street_suffix, v_house, v_postal, v_city);
    ELSE
        RETURN format('%s%s %s, %s %s, %s', v_street_word, v_street_suffix, v_house, v_postal, v_city, v_region);
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION fake.generate_geo(p_key TEXT)
RETURNS TABLE(latitude DOUBLE PRECISION, longitude DOUBLE PRECISION)
LANGUAGE sql
IMMUTABLE
STRICT
PARALLEL SAFE
AS $$
    SELECT
        degrees(asin((2.0 * fake.rand_uniform(p_key, 50)) - 1.0)) AS latitude,
        (360.0 * fake.rand_uniform(p_key, 51)) - 180.0 AS longitude;
$$;

CREATE OR REPLACE FUNCTION fake.generate_physical(
    p_locale TEXT,
    p_gender TEXT,
    p_key TEXT
)
RETURNS TABLE(
    height_cm NUMERIC(5,2),
    weight_kg NUMERIC(6,2),
    eye_color TEXT
)
LANGUAGE plpgsql
STABLE
STRICT
AS $$
DECLARE
    v_height_mean DOUBLE PRECISION;
    v_height_std DOUBLE PRECISION;
    v_weight_mean DOUBLE PRECISION;
    v_weight_std DOUBLE PRECISION;
    v_height_raw DOUBLE PRECISION;
    v_weight_raw DOUBLE PRECISION;
BEGIN
    IF p_gender = 'M' THEN
        v_height_mean := 178.0;
        v_height_std := 7.0;
        v_weight_mean := 82.0;
        v_weight_std := 12.0;
    ELSE
        v_height_mean := 165.0;
        v_height_std := 6.0;
        v_weight_mean := 68.0;
        v_weight_std := 10.0;
    END IF;

    IF p_locale = 'de_DE' THEN
        v_height_mean := v_height_mean + 1.0;
        v_weight_mean := v_weight_mean + 0.5;
    END IF;

    v_height_raw := fake.rand_normal(p_key, 60, v_height_mean, v_height_std);
    v_weight_raw := fake.rand_normal(p_key, 61, v_weight_mean, v_weight_std);

    height_cm := round(GREATEST(145.0, LEAST(210.0, v_height_raw))::numeric, 2);
    weight_kg := round(GREATEST(40.0, LEAST(160.0, v_weight_raw))::numeric, 2);
    eye_color := fake.pick_lexicon(p_locale, 'eye_color', p_key, 62);

    RETURN NEXT;
END;
$$;

CREATE OR REPLACE FUNCTION fake.generate_phone(
    p_locale TEXT,
    p_key TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
STRICT
AS $$
DECLARE
    v_pattern TEXT;
    v_style INTEGER;
    v_area TEXT;
    v_exchange_num INTEGER;
    v_exchange TEXT;
    v_line TEXT;
BEGIN
    IF p_locale = 'en_US' THEN
        -- Use curated realistic US area codes and NANP-like exchange constraints.
        v_area := fake.pick_lexicon(p_locale, 'us_area_code', p_key, 80);
        v_exchange_num := fake.rand_int(p_key, 81, 200, 999);
        IF (v_exchange_num % 100) = 11 THEN
            v_exchange_num := LEAST(999, v_exchange_num + 1);
        END IF;
        v_exchange := lpad(v_exchange_num::text, 3, '0');
        v_line := lpad(fake.rand_int(p_key, 82, 0, 9999)::text, 4, '0');
        v_style := fake.rand_int(p_key, 83, 1, 5);

        IF v_style = 1 THEN
            RETURN format('+1-%s-%s-%s', v_area, v_exchange, v_line);
        ELSIF v_style = 2 THEN
            RETURN format('(%s) %s-%s', v_area, v_exchange, v_line);
        ELSIF v_style = 3 THEN
            RETURN format('%s.%s.%s', v_area, v_exchange, v_line);
        ELSIF v_style = 4 THEN
            RETURN format('%s %s %s', v_area, v_exchange, v_line);
        END IF;

        RETURN format('1 (%s) %s-%s', v_area, v_exchange, v_line);
    END IF;

    v_pattern := fake.pick_lexicon(p_locale, 'phone_pattern', p_key, 80);
    RETURN fake.render_pattern(v_pattern, p_key, 200);
END;
$$;

CREATE OR REPLACE FUNCTION fake.generate_email(
    p_locale TEXT,
    p_first_name TEXT,
    p_last_name TEXT,
    p_key TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
STRICT
AS $$
DECLARE
    v_first TEXT;
    v_last TEXT;
    v_domain TEXT;
    v_local TEXT;
    v_variant INTEGER;
    v_num2 TEXT;
    v_num4 TEXT;
BEGIN
    v_first := fake.slug_part(p_first_name);
    v_last := fake.slug_part(p_last_name);
    v_domain := fake.pick_lexicon(p_locale, 'email_domain', p_key, 93);

    v_variant := fake.rand_int(p_key, 90, 1, 4);
    v_num2 := lpad(fake.rand_int(p_key, 91, 0, 99)::text, 2, '0');
    v_num4 := lpad(fake.rand_int(p_key, 92, 0, 9999)::text, 4, '0');

    IF v_variant = 1 THEN
        v_local := v_first || '.' || v_last;
    ELSIF v_variant = 2 THEN
        v_local := left(v_first, 1) || v_last || v_num2;
    ELSIF v_variant = 3 THEN
        v_local := v_first || v_num4;
    ELSE
        v_local := v_last || '.' || left(v_first, 1) || v_num2;
    END IF;

    v_local := trim(both '.' FROM regexp_replace(v_local, '[.]{2,}', '.', 'g'));
    RETURN v_local || '@' || v_domain;
END;
$$;

CREATE OR REPLACE FUNCTION fake.generate_user(
    p_locale TEXT,
    p_seed BIGINT,
    p_batch_index INTEGER,
    p_index_in_batch INTEGER
)
RETURNS TABLE(
    full_name TEXT,
    address TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    height_cm NUMERIC(5,2),
    weight_kg NUMERIC(6,2),
    eye_color TEXT,
    phone TEXT,
    email TEXT
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_key TEXT := format('%s|%s|%s|%s', p_locale, p_seed, p_batch_index, p_index_in_batch);
    v_name RECORD;
    v_geo RECORD;
    v_physical RECORD;
BEGIN
    IF p_index_in_batch < 0 THEN
        RAISE EXCEPTION 'p_index_in_batch must be >= 0';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM fake.locales AS l WHERE l.locale_code = p_locale) THEN
        RAISE EXCEPTION 'Unsupported locale: %', p_locale;
    END IF;

    SELECT * INTO v_name
    FROM fake.generate_name(p_locale, p_seed, p_batch_index, p_index_in_batch);

    SELECT * INTO v_geo
    FROM fake.generate_geo(v_key);

    SELECT * INTO v_physical
    FROM fake.generate_physical(p_locale, v_name.gender, v_key);

    full_name := v_name.full_name;
    address := fake.generate_address(p_locale, v_key);
    latitude := v_geo.latitude;
    longitude := v_geo.longitude;
    height_cm := v_physical.height_cm;
    weight_kg := v_physical.weight_kg;
    eye_color := v_physical.eye_color;
    phone := fake.generate_phone(p_locale, v_key);
    email := fake.generate_email(p_locale, v_name.first_name, v_name.last_name, v_key);

    RETURN NEXT;
END;
$$;

CREATE OR REPLACE FUNCTION fake.generate_user_batch(
    p_locale TEXT,
    p_seed BIGINT,
    p_batch_index INTEGER,
    p_batch_size INTEGER DEFAULT 10
)
RETURNS TABLE(
    locale_code TEXT,
    seed_value BIGINT,
    batch_index INTEGER,
    index_in_batch INTEGER,
    position_in_stream BIGINT,
    full_name TEXT,
    address TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    height_cm NUMERIC(5,2),
    weight_kg NUMERIC(6,2),
    eye_color TEXT,
    phone TEXT,
    email TEXT
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    IF p_batch_size < 1 OR p_batch_size > 1000 THEN
        RAISE EXCEPTION 'p_batch_size must be between 1 and 1000';
    END IF;

    IF p_batch_index < 0 THEN
        RAISE EXCEPTION 'p_batch_index must be >= 0';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM fake.locales AS l WHERE l.locale_code = p_locale) THEN
        RAISE EXCEPTION 'Unsupported locale: %', p_locale;
    END IF;

    RETURN QUERY
    SELECT
        p_locale AS locale_code,
        p_seed AS seed_value,
        p_batch_index AS batch_index,
        g.idx AS index_in_batch,
        (p_batch_index::bigint * p_batch_size::bigint) + g.idx AS position_in_stream,
        u.full_name,
        u.address,
        u.latitude,
        u.longitude,
        u.height_cm,
        u.weight_kg,
        u.eye_color,
        u.phone,
        u.email
    FROM generate_series(0, p_batch_size - 1) AS g(idx)
    CROSS JOIN LATERAL fake.generate_user(p_locale, p_seed, p_batch_index, g.idx) AS u
    ORDER BY g.idx;
END;
$$;

CREATE OR REPLACE FUNCTION fake.lookup_cardinality()
RETURNS TABLE(
    locale_code TEXT,
    names_rows BIGINT,
    lexicon_rows BIGINT
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        l.locale_code,
        COALESCE(n.cnt, 0) AS names_rows,
        COALESCE(x.cnt, 0) AS lexicon_rows
    FROM fake.locales AS l
    LEFT JOIN (
        SELECT locale_code, count(*) AS cnt
        FROM fake.names
        GROUP BY locale_code
    ) AS n USING (locale_code)
    LEFT JOIN (
        SELECT locale_code, count(*) AS cnt
        FROM fake.lexicon
        GROUP BY locale_code
    ) AS x USING (locale_code)
    ORDER BY l.locale_code;
$$;

COMMIT;

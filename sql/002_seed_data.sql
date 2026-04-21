BEGIN;

INSERT INTO fake.locales (locale_code, locale_name, country_code, default_email_domain, phone_country_code)
VALUES
    ('en_US', 'English (United States)', 'US', 'examplemail.com', '+1'),
    ('de_DE', 'German (Germany)', 'DE', 'beispielmail.de', '+49')
ON CONFLICT (locale_code) DO UPDATE SET
    locale_name = EXCLUDED.locale_name,
    country_code = EXCLUDED.country_code,
    default_email_domain = EXCLUDED.default_email_domain,
    phone_country_code = EXCLUDED.phone_country_code;

INSERT INTO fake.names (locale_code, name_type, gender, value)
SELECT 'en_US', 'title', 'M', x
FROM unnest(ARRAY['Mr.', 'Dr.', 'Prof.', 'Capt.', 'Sir']) AS x
ON CONFLICT DO NOTHING;

INSERT INTO fake.names (locale_code, name_type, gender, value)
SELECT 'en_US', 'title', 'F', x
FROM unnest(ARRAY['Ms.', 'Mrs.', 'Dr.', 'Prof.', 'Lady']) AS x
ON CONFLICT DO NOTHING;

INSERT INTO fake.names (locale_code, name_type, gender, value)
SELECT 'de_DE', 'title', 'M', x
FROM unnest(ARRAY['Herr', 'Dr.', 'Prof.', 'Ing.']) AS x
ON CONFLICT DO NOTHING;

INSERT INTO fake.names (locale_code, name_type, gender, value)
SELECT 'de_DE', 'title', 'F', x
FROM unnest(ARRAY['Frau', 'Dr.', 'Prof.', 'Ing.']) AS x
ON CONFLICT DO NOTHING;

WITH starts AS (
    SELECT unnest(ARRAY[
        'Al', 'Ben', 'Cal', 'Dan', 'Ed', 'Fin', 'Gav', 'Har', 'Ian', 'Jon',
        'Ken', 'Leo', 'Max', 'Nate', 'Oli', 'Pat', 'Quin', 'Ray', 'Sam', 'Theo',
        'Vic', 'Will', 'Xan', 'Yor', 'Zed'
    ]) AS s
), mids AS (
    SELECT unnest(ARRAY['a', 'e', 'i', 'o', 'u', 'ar', 'er', 'or']) AS m
), ends AS (
    SELECT unnest(ARRAY['n', 'son', 'ton', 'ley', 'den', 'ric', 'ias', 'iel', 'us', 'an', 'en', 'er', 'on', 'is']) AS e
)
INSERT INTO fake.names (locale_code, name_type, gender, value)
SELECT 'en_US', 'first', 'M', initcap(s || m || e)
FROM starts CROSS JOIN mids CROSS JOIN ends
WHERE char_length(s || m || e) BETWEEN 4 AND 11
ON CONFLICT DO NOTHING;

WITH starts AS (
    SELECT unnest(ARRAY[
        'Ad', 'Bel', 'Car', 'Del', 'El', 'Fay', 'Gia', 'Han', 'Ivy', 'Jan',
        'Kay', 'Lil', 'Mia', 'Nia', 'Oli', 'Pia', 'Que', 'Ria', 'Sia', 'Tia',
        'Una', 'Val', 'Wyn', 'Xia', 'Yva', 'Zoe'
    ]) AS s
), mids AS (
    SELECT unnest(ARRAY['a', 'e', 'i', 'o', 'u', 'el', 'ar', 'in']) AS m
), ends AS (
    SELECT unnest(ARRAY['na', 'la', 'ra', 'sa', 'ta', 'lyn', 'bella', 'dine', 'nette', 'ria', 'lie', 'sha', 'elle', 'ina', 'ora']) AS e
)
INSERT INTO fake.names (locale_code, name_type, gender, value)
SELECT 'en_US', 'first', 'F', initcap(s || m || e)
FROM starts CROSS JOIN mids CROSS JOIN ends
WHERE char_length(s || m || e) BETWEEN 4 AND 12
ON CONFLICT DO NOTHING;

WITH starts AS (
    SELECT unnest(ARRAY[
        'An', 'Ber', 'Cla', 'Dir', 'Er', 'Fri', 'Gun', 'Hei', 'Ing', 'Joh',
        'Kla', 'Lud', 'Mat', 'Nik', 'Ott', 'Pet', 'Rut', 'Seb', 'Tor', 'Ul',
        'Vol', 'Wal', 'Xav', 'Yur', 'Zim'
    ]) AS s
), mids AS (
    SELECT unnest(ARRAY['a', 'e', 'i', 'o', 'u', 'ei', 'au', 'ie']) AS m
), ends AS (
    SELECT unnest(ARRAY['n', 'mann', 'rich', 'bert', 'helm', 'fried', 'mar', 'ger', 'win', 'rad', 'sen', 'ke', 'wig', 'old']) AS e
)
INSERT INTO fake.names (locale_code, name_type, gender, value)
SELECT 'de_DE', 'first', 'M', initcap(s || m || e)
FROM starts CROSS JOIN mids CROSS JOIN ends
WHERE char_length(s || m || e) BETWEEN 4 AND 14
ON CONFLICT DO NOTHING;

WITH starts AS (
    SELECT unnest(ARRAY[
        'An', 'Bir', 'Cla', 'Dor', 'Eva', 'Fra', 'Gre', 'Hel', 'Ina', 'Jan',
        'Kat', 'Lau', 'Mar', 'Nad', 'Ott', 'Pet', 'Rosa', 'Sab', 'Tan', 'Ulr',
        'Val', 'Wen', 'Xen', 'Yas', 'Zel'
    ]) AS s
), mids AS (
    SELECT unnest(ARRAY['a', 'e', 'i', 'o', 'u', 'ei', 'ie', 'au']) AS m
), ends AS (
    SELECT unnest(ARRAY['na', 'tra', 'rike', 'linde', 'hild', 'marie', 'lotte', 'berta', 'gunde', 'line', 'dora', 'sine', 'wina', 'rike']) AS e
)
INSERT INTO fake.names (locale_code, name_type, gender, value)
SELECT 'de_DE', 'first', 'F', initcap(s || m || e)
FROM starts CROSS JOIN mids CROSS JOIN ends
WHERE char_length(s || m || e) BETWEEN 4 AND 15
ON CONFLICT DO NOTHING;

INSERT INTO fake.names (locale_code, name_type, gender, value)
SELECT locale_code, 'middle', gender, value
FROM fake.names
WHERE name_type = 'first' AND locale_code = 'en_US' AND (name_id % 4 = 0)
ON CONFLICT DO NOTHING;

INSERT INTO fake.names (locale_code, name_type, gender, value)
SELECT locale_code, 'middle', gender, value
FROM fake.names
WHERE name_type = 'first' AND locale_code = 'de_DE' AND (name_id % 4 = 0)
ON CONFLICT DO NOTHING;

WITH starts AS (
    SELECT unnest(ARRAY[
        'Ander', 'Baker', 'Carter', 'Dal', 'East', 'Flet', 'Grant', 'Har', 'Ir', 'Jen',
        'Kens', 'Lang', 'Mont', 'Nor', 'Oak', 'Pres', 'Quin', 'Rid', 'Stone', 'Turn',
        'Under', 'Vander', 'West', 'York', 'Zim', 'Parker', 'Miller', 'Brad', 'Cole', 'Daw',
        'Ell', 'Frank', 'Gray', 'Hud', 'Iv', 'Jam', 'Ken', 'Long', 'Mar', 'Nel'
    ]) AS s
), mids AS (
    SELECT unnest(ARRAY['a', 'e', 'i', 'o', 'u', 'er', 'ar', 'or']) AS m
), ends AS (
    SELECT unnest(ARRAY['son', 'man', 'ford', 'well', 'field', 'ston', 'ley', 'ton', 'ham', 'wood', 'ridge', 'worth']) AS e
)
INSERT INTO fake.names (locale_code, name_type, gender, value)
SELECT 'en_US', 'last', 'N', initcap(s || m || e)
FROM starts CROSS JOIN mids CROSS JOIN ends
WHERE char_length(s || m || e) BETWEEN 5 AND 16
ON CONFLICT DO NOTHING;

WITH starts AS (
    SELECT unnest(ARRAY[
        'Sch', 'Berg', 'Klein', 'Weis', 'Braun', 'Hart', 'Lang', 'Koch', 'Roth', 'Falk',
        'Wald', 'Neu', 'Alt', 'Graf', 'Hoff', 'Winter', 'Sommer', 'Stahl', 'Kraft', 'Jung',
        'Lenz', 'Merk', 'Pfeif', 'Reich', 'Sonn', 'Treu', 'Vogel', 'Wirth', 'Zieg', 'Dorn',
        'Bach', 'Eich', 'Feld', 'Gerl', 'Heim', 'Igel', 'Jahn', 'Kern', 'Lud', 'Meyer'
    ]) AS s
), mids AS (
    SELECT unnest(ARRAY['a', 'e', 'i', 'o', 'u', 'ei', 'au', 'ie']) AS m
), ends AS (
    SELECT unnest(ARRAY['mann', 'berg', 'stein', 'hofer', 'bauer', 'schmidt', 'ler', 'kamp', 'wald', 'dorf', 'heim', 'inger']) AS e
)
INSERT INTO fake.names (locale_code, name_type, gender, value)
SELECT 'de_DE', 'last', 'N', initcap(s || m || e)
FROM starts CROSS JOIN mids CROSS JOIN ends
WHERE char_length(s || m || e) BETWEEN 5 AND 18
ON CONFLICT DO NOTHING;

WITH prefixes AS (
    SELECT unnest(ARRAY[
        'North', 'South', 'East', 'West', 'Lake', 'Port', 'New', 'Fort', 'River', 'Grand',
        'Glen', 'Pine', 'Cedar', 'Maple', 'Silver', 'Golden', 'Clear', 'Stone', 'Spring', 'Fair',
        'High', 'Low', 'Green', 'Red', 'Blue', 'White', 'Black', 'Oak', 'Elm', 'Brook',
        'Sunny', 'Shadow', 'Wind', 'Fox', 'Eagle', 'Bear', 'Wolf', 'Copper', 'Iron', 'Bright'
    ]) AS p
), suffixes AS (
    SELECT unnest(ARRAY[
        'field', 'ton', 'ville', 'view', 'crest', 'ford', 'side', 'ridge', 'grove', 'port',
        'springs', 'falls', 'heights', 'point', 'harbor', 'hill', 'valley', 'meadow', 'park', 'bay'
    ]) AS s
)
INSERT INTO fake.lexicon (locale_code, token_type, value)
SELECT 'en_US', 'city', initcap(p || s)
FROM prefixes CROSS JOIN suffixes
ON CONFLICT DO NOTHING;

WITH prefixes AS (
    SELECT unnest(ARRAY[
        'Neu', 'Alt', 'Ober', 'Unter', 'Gross', 'Klein', 'Berg', 'Wald', 'See', 'Rhein',
        'Main', 'Elb', 'Donau', 'Nord', 'Sued', 'West', 'Ost', 'Linden', 'Birken', 'Eichen',
        'Falken', 'Sonnen', 'Mond', 'Stern', 'Hoch', 'Tief', 'Rot', 'Gruen', 'Silber', 'Gold',
        'Stein', 'Bach', 'Brueck', 'Frei', 'Koenig', 'Kaiser', 'Dorf', 'Hafen', 'Wiesen', 'Himmel'
    ]) AS p
), suffixes AS (
    SELECT unnest(ARRAY[
        'stadt', 'dorf', 'heim', 'berg', 'tal', 'feld', 'hafen', 'burg', 'furt', 'brueck',
        'hausen', 'kirchen', 'weiler', 'rode', 'au', 'see', 'born', 'garten', 'hofen', 'zell'
    ]) AS s
)
INSERT INTO fake.lexicon (locale_code, token_type, value)
SELECT 'de_DE', 'city', initcap(p || s)
FROM prefixes CROSS JOIN suffixes
ON CONFLICT DO NOTHING;

WITH roots AS (
    SELECT unnest(ARRAY[
        'Liberty', 'Forest', 'Sunset', 'Hill', 'River', 'Lake', 'Maple', 'Cedar', 'Pine', 'Oak',
        'Washington', 'Adams', 'Jefferson', 'Madison', 'Franklin', 'Lincoln', 'Jackson', 'Wilson', 'Taylor', 'King',
        'Queen', 'College', 'Market', 'Mill', 'Bridge', 'Valley', 'Creek', 'Ridge', 'Garden', 'Meadow',
        'Cherry', 'Apple', 'Peach', 'Walnut', 'Aspen', 'Birch', 'Willow', 'Palm', 'Harbor', 'Station'
    ]) AS r
), tails AS (
    SELECT unnest(ARRAY[
        'view', 'side', 'wood', 'land', 'field', 'crest', 'bend', 'gate', 'point', 'cross',
        'grove', 'park', 'run', 'trace', 'heights', 'walk', 'brook', 'vale', 'hollow', 'rise',
        'meadows', 'corner', 'circle', 'square', 'terrace', 'plaza', 'lane', 'court', 'drive', 'path'
    ]) AS t
)
INSERT INTO fake.lexicon (locale_code, token_type, value)
SELECT 'en_US', 'street_word', initcap(r || t)
FROM roots CROSS JOIN tails
ON CONFLICT DO NOTHING;

WITH roots AS (
    SELECT unnest(ARRAY[
        'Haupt', 'Bahnhof', 'Kirch', 'Schul', 'Wald', 'Berg', 'Tal', 'Rosen', 'Linden', 'Eichen',
        'Birken', 'Garten', 'Markt', 'Brunnen', 'Muehlen', 'Friedhof', 'Park', 'Ring', 'Bach', 'Auen',
        'Sonnen', 'Mond', 'Stern', 'Koenig', 'Kaiser', 'Schiller', 'Goethe', 'Lessing', 'Mozart', 'Beethoven',
        'Dorf', 'Hafen', 'See', 'Feld', 'Wiesen', 'Tor', 'Bruecken', 'Kanal', 'Turm', 'Dom'
    ]) AS r
), tails AS (
    SELECT unnest(ARRAY[
        'hof', 'garten', 'berg', 'tal', 'bach', 'brueck', 'tor', 'platz', 'feld', 'stein',
        'wald', 'rain', 'au', 'kamp', 'damm', 'furt', 'busch', 'grund', 'horst', 'heide',
        'winkel', 'weg', 'acker', 'zwinger', 'quelle'
    ]) AS t
)
INSERT INTO fake.lexicon (locale_code, token_type, value)
SELECT 'de_DE', 'street_word', initcap(r || t)
FROM roots CROSS JOIN tails
ON CONFLICT DO NOTHING;

INSERT INTO fake.lexicon (locale_code, token_type, value)
SELECT 'en_US', 'street_suffix', x
FROM unnest(ARRAY['St', 'Ave', 'Rd', 'Blvd', 'Ln', 'Dr', 'Ct', 'Pl', 'Way', 'Pkwy']) AS x
ON CONFLICT DO NOTHING;

INSERT INTO fake.lexicon (locale_code, token_type, value)
SELECT 'de_DE', 'street_suffix', x
FROM unnest(ARRAY['strasse', 'weg', 'platz', 'allee', 'ring', 'gasse']) AS x
ON CONFLICT DO NOTHING;

INSERT INTO fake.lexicon (locale_code, token_type, value)
SELECT 'en_US', 'region', x
FROM unnest(ARRAY[
    'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
    'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
    'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
    'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
    'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY'
]) AS x
ON CONFLICT DO NOTHING;

INSERT INTO fake.lexicon (locale_code, token_type, value)
SELECT 'de_DE', 'region', x
FROM unnest(ARRAY[
    'Baden-Wuerttemberg', 'Bayern', 'Berlin', 'Brandenburg', 'Bremen', 'Hamburg',
    'Hessen', 'Mecklenburg-Vorpommern', 'Niedersachsen', 'Nordrhein-Westfalen',
    'Rheinland-Pfalz', 'Saarland', 'Sachsen', 'Sachsen-Anhalt', 'Schleswig-Holstein', 'Thueringen'
]) AS x
ON CONFLICT DO NOTHING;

INSERT INTO fake.lexicon (locale_code, token_type, value)
SELECT 'en_US', 'eye_color', x
FROM unnest(ARRAY['Brown', 'Blue', 'Hazel', 'Green', 'Gray', 'Amber']) AS x
ON CONFLICT DO NOTHING;

INSERT INTO fake.lexicon (locale_code, token_type, value)
SELECT 'de_DE', 'eye_color', x
FROM unnest(ARRAY['Braun', 'Blau', 'Gruen', 'Grau', 'Haselnuss', 'Bernstein']) AS x
ON CONFLICT DO NOTHING;

DELETE FROM fake.lexicon
WHERE locale_code = 'en_US'
  AND token_type = 'phone_pattern';

INSERT INTO fake.lexicon (locale_code, token_type, value)
SELECT 'en_US', 'phone_pattern', x
FROM unnest(ARRAY[
    '+1-N##-N##-####',
    '(N##) N##-####',
    'N##-N##-####',
    'N## N## ####',
    '1 (N##) N##-####'
]) AS x
ON CONFLICT DO NOTHING;

DELETE FROM fake.lexicon
WHERE locale_code = 'en_US'
  AND token_type = 'us_area_code';

INSERT INTO fake.lexicon (locale_code, token_type, value)
SELECT 'en_US', 'us_area_code', x
FROM unnest(ARRAY[
    '201', '202', '203', '205', '206', '207', '208', '209', '210', '212',
    '213', '214', '215', '216', '217', '218', '219', '224', '225', '228',
    '229', '231', '234', '239', '240', '248', '251', '252', '253', '254',
    '256', '260', '262', '267', '269', '270', '272', '276', '281', '301',
    '302', '303', '304', '305', '307', '308', '309', '310', '312', '313',
    '314', '315', '316', '317', '318', '319', '320', '321', '323', '325',
    '330', '331', '334', '336', '337', '339', '346', '347', '351', '352',
    '360', '361', '364', '385', '386', '401', '402', '404', '405', '406',
    '407', '408', '409', '410', '412', '413', '414', '415', '417', '419',
    '423', '424', '425', '430', '432', '434', '435', '440', '443', '445',
    '458', '469', '470', '475', '478', '479', '480', '484', '501', '502',
    '503', '504', '505', '507', '508', '509', '510', '512', '513', '515',
    '516', '517', '518', '520', '530', '531', '534', '539', '540', '541',
    '551', '559', '561', '562', '563', '564', '567', '570', '571', '573',
    '574', '575', '580', '585', '586', '601', '602', '603', '605', '606',
    '607', '608', '609', '610', '612', '614', '615', '616', '617', '618',
    '619', '620', '623', '626', '628', '629', '630', '631', '636', '641',
    '646', '650', '651', '657', '660', '661', '662', '667', '669', '678',
    '681', '682', '701', '702', '703', '704', '706', '707', '708', '712',
    '713', '714', '715', '716', '717', '718', '719', '720', '724', '725',
    '727', '731', '732', '734', '737', '740', '743', '747', '754', '757',
    '760', '762', '763', '765', '770', '772', '773', '774', '775', '779',
    '781', '785', '786', '801', '802', '803', '804', '805', '806', '808',
    '810', '812', '813', '814', '815', '816', '817', '818', '828', '830',
    '831', '832', '843', '845', '847', '848', '850', '854', '856', '857',
    '858', '859', '860', '862', '863', '864', '865', '870', '872', '878',
    '901', '903', '904', '907', '908', '909', '910', '912', '913', '914',
    '915', '916', '917', '918', '919', '920', '925', '928', '929', '930',
    '931', '934', '936', '937', '938', '940', '941', '947', '949', '951',
    '952', '954', '956', '959', '970', '971', '972', '973', '978', '979',
    '980', '984', '985', '986', '989'
]) AS x
ON CONFLICT DO NOTHING;

DELETE FROM fake.lexicon
WHERE locale_code = 'de_DE'
  AND token_type = 'phone_pattern';

INSERT INTO fake.lexicon (locale_code, token_type, value)
SELECT 'de_DE', 'phone_pattern', x
FROM unnest(ARRAY[
    '+49 N# ########',
    '+49 (0) N## #######',
    '0N## ########',
    '0N# #######',
    '+49 N## ### ####'
]) AS x
ON CONFLICT DO NOTHING;

INSERT INTO fake.lexicon (locale_code, token_type, value)
SELECT 'en_US', 'email_domain', x
FROM unnest(ARRAY[
    'examplemail.com', 'mailbox.net', 'fastmail.io', 'inboxhub.com', 'cloudpost.org', 'samplemail.dev'
]) AS x
ON CONFLICT DO NOTHING;

INSERT INTO fake.lexicon (locale_code, token_type, value)
SELECT 'de_DE', 'email_domain', x
FROM unnest(ARRAY[
    'beispielmail.de', 'postfach.net', 'schnellmail.de', 'datenmail.eu', 'wolkenpost.de', 'musterpost.org'
]) AS x
ON CONFLICT DO NOTHING;

INSERT INTO fake.lexicon (locale_code, token_type, value)
SELECT 'en_US', 'name_suffix', x
FROM unnest(ARRAY['Jr.', 'Sr.', 'II', 'III', 'PhD']) AS x
ON CONFLICT DO NOTHING;

INSERT INTO fake.lexicon (locale_code, token_type, value)
SELECT 'de_DE', 'name_suffix', x
FROM unnest(ARRAY['MSc', 'PhD', 'Junior', 'Senior']) AS x
ON CONFLICT DO NOTHING;

INSERT INTO fake.lexicon (locale_code, token_type, value)
SELECT 'en_US', 'unit_word', x
FROM unnest(ARRAY['Apt', 'Suite', 'Unit']) AS x
ON CONFLICT DO NOTHING;

INSERT INTO fake.lexicon (locale_code, token_type, value)
SELECT 'de_DE', 'unit_word', x
FROM unnest(ARRAY['Whg.', 'Top', 'Einheit']) AS x
ON CONFLICT DO NOTHING;

COMMIT;

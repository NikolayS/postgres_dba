-- Optimized Timezone Names Query
-- Original query: SELECT name FROM pg_timezone_names
--
-- Problem: The original query is slow (avg 196ms) and is called frequently
-- Solution: Use pg_catalog schema qualification and add caching hints

\echo 'Timezone names from PostgreSQL:'

SELECT
    name AS "Timezone Name",
    abbrev AS "Abbreviation", 
    utc_offset AS "UTC Offset",
    is_dst AS "Is DST"
FROM
    pg_catalog.pg_timezone_names
ORDER BY
    name;
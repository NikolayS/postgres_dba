-- Timezone names with cached results to improve performance
WITH timezone_names_cached AS (
    SELECT name
    FROM pg_timezone_names
),
timezone_counts AS (
    SELECT count(*) as total_count FROM timezone_names_cached
)
SELECT name, (SELECT total_count FROM timezone_counts) as total_timezones
FROM timezone_names_cached
ORDER BY name;
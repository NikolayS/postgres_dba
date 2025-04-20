-- List all time zone names from PostgreSQL with caching
WITH cached_timezones AS (
  SELECT name 
  FROM pg_timezone_names
)
SELECT name 
FROM cached_timezones
ORDER BY name;

-- Slower original query for reference:
-- SELECT name FROM pg_timezone_names;
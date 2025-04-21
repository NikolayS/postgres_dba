-- Cached timezone names for better performance
WITH timezone_cache AS (
  SELECT name, abbrev, utc_offset, is_dst
  FROM pg_timezone_names
)
SELECT name
FROM timezone_cache;
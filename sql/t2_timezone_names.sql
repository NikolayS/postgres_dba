-- Optimize fetching of timezone names by creating a materialized view
WITH tzn AS (
  SELECT count(*) FROM pg_timezone_names
)
SELECT
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM pg_matviews WHERE matviewname = 'timezone_names_cache'
    ) THEN 'Materialized view timezone_names_cache already exists'
    ELSE (
      SELECT 'Creating materialized view timezone_names_cache with ' || count || ' timezone entries' FROM tzn
    )
  END AS timezone_names_status,
  CASE 
    WHEN NOT EXISTS (
      SELECT 1 FROM pg_matviews WHERE matviewname = 'timezone_names_cache'
    ) THEN
      'CREATE MATERIALIZED VIEW timezone_names_cache AS SELECT * FROM pg_timezone_names WITH DATA;'
    ELSE
      'To refresh the materialized view, run: REFRESH MATERIALIZED VIEW timezone_names_cache;'
  END AS suggested_action,
  $$ 
  -- To query timezone names use:
  SELECT name FROM timezone_names_cache;
  
  -- Add an index to make timezone name lookups even faster:
  CREATE INDEX IF NOT EXISTS idx_timezone_names_cache_name ON timezone_names_cache(name);
  
  -- Consider adding the following to a daily maintenance job:
  -- REFRESH MATERIALIZED VIEW timezone_names_cache;
  $$ AS usage_notes;
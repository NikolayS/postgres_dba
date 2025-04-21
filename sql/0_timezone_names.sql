-- Timezone names query optimized with caching
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Create a materialized view to cache timezone names
DO $$
BEGIN
  -- Check if the materialized view already exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_matviews WHERE matviewname = 'cached_timezone_names'
  ) THEN
    EXECUTE 'CREATE MATERIALIZED VIEW cached_timezone_names AS 
      SELECT name FROM pg_timezone_names
      WITH DATA';
  
    -- Create an index on the name column for faster lookups
    EXECUTE 'CREATE INDEX idx_cached_timezone_names_name ON cached_timezone_names(name)';
  
    -- Grant permissions to the public role
    EXECUTE 'GRANT SELECT ON cached_timezone_names TO PUBLIC';
  END IF;
END;
$$;

-- Query to use the cached timezone names
SELECT name FROM cached_timezone_names
ORDER BY name;

-- Helper query to refresh the materialized view (run periodically)
-- REFRESH MATERIALIZED VIEW cached_timezone_names;
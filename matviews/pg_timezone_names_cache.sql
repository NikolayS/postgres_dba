-- Create materialized view for pg_timezone_names caching
-- This helps improve performance for applications that frequently query timezone data

CREATE MATERIALIZED VIEW IF NOT EXISTS pg_timezone_names_cache AS
SELECT 
  name,
  abbrev,
  utc_offset,
  is_dst
FROM pg_timezone_names;

-- Create an index on the name column for faster lookups
CREATE INDEX IF NOT EXISTS pg_timezone_names_cache_name_idx ON pg_timezone_names_cache (name);

-- Create a refresh function that can be scheduled via cron or similar
CREATE OR REPLACE FUNCTION refresh_pg_timezone_names_cache() 
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW pg_timezone_names_cache;
END;
$$ LANGUAGE plpgsql;

-- Documentation:
-- To manually refresh: SELECT refresh_pg_timezone_names_cache();
-- Recommended: Schedule refresh weekly via cron job or pg_cron extension
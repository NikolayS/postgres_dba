-- Optimized query for retrieving timezone names
-- This provides a materialized view approach for faster timezone name lookups
-- The pg_timezone_names system view can be slow when queried repeatedly
-- Issue reference: Slow query fetching timezone names

-- Create materialized view for timezone names
CREATE MATERIALIZED VIEW IF NOT EXISTS cached_timezone_names AS
SELECT name, abbrev, utc_offset, is_dst 
FROM pg_timezone_names;

-- Create index on the name column for faster lookups
CREATE UNIQUE INDEX IF NOT EXISTS idx_cached_timezone_names_name 
ON cached_timezone_names (name);

-- Create index on the abbrev column for additional query patterns
CREATE INDEX IF NOT EXISTS idx_cached_timezone_names_abbrev
ON cached_timezone_names (abbrev);

-- Sample query to retrieve all timezone names from the materialized view
-- This is much faster than querying pg_timezone_names directly
-- SELECT name FROM cached_timezone_names;

-- How to refresh the materialized view (can be scheduled via cron/pg_cron):
-- REFRESH MATERIALIZED VIEW cached_timezone_names;

-- Function to refresh the timezone names materialized view
CREATE OR REPLACE FUNCTION refresh_cached_timezone_names()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW cached_timezone_names;
END;
$$ LANGUAGE plpgsql;

-- Comment explaining usage
COMMENT ON MATERIALIZED VIEW cached_timezone_names IS 
  'Cached version of pg_timezone_names for faster lookups. Refresh periodically.';
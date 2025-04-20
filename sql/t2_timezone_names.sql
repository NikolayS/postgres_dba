-- Timezone names view with caching to improve performance
-- The pg_timezone_names view is a system view that can be slow to query
-- This creates a materialized view to cache timezone data

-- Create materialized view for timezone names
CREATE MATERIALIZED VIEW IF NOT EXISTS tz_names_cache AS
SELECT name, abbrev, utc_offset, is_dst
FROM pg_timezone_names;

-- Create index on the name column for faster lookups
CREATE INDEX IF NOT EXISTS idx_tz_names_cache_name ON tz_names_cache (name);

-- Function to refresh the materialized view
CREATE OR REPLACE FUNCTION refresh_tz_names_cache()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW tz_names_cache;
END;
$$ LANGUAGE plpgsql;

-- Create a comment explaining the purpose and usage
COMMENT ON MATERIALIZED VIEW tz_names_cache IS 
'Cached version of pg_timezone_names. Use this instead of directly querying pg_timezone_names.
Example: SELECT name FROM tz_names_cache
To refresh: SELECT refresh_tz_names_cache()';

-- Initial refresh
SELECT refresh_tz_names_cache();
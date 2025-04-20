-- Timezone Names Query with Materialized View
-- This script provides an optimized way to query timezone names
-- Original query: SELECT name FROM pg_timezone_names
-- Issues: Slow performance (195.96ms mean execution time)

-- Create materialized view to store timezone names
CREATE MATERIALIZED VIEW IF NOT EXISTS timezone_names_mv AS
SELECT name, abbrev, utc_offset, is_dst 
FROM pg_timezone_names
WITH DATA;

-- Create index on name column for faster lookups
CREATE INDEX IF NOT EXISTS idx_timezone_names_mv_name ON timezone_names_mv (name);

-- Function to refresh the materialized view (call periodically)
CREATE OR REPLACE FUNCTION refresh_timezone_names_mv()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW timezone_names_mv;
END;
$$ LANGUAGE plpgsql;

-- Example query to get all timezone names (much faster than direct view query)
-- SELECT name FROM timezone_names_mv;

-- Example query to search for specific timezone patterns
-- SELECT name FROM timezone_names_mv WHERE name ILIKE '%America%';
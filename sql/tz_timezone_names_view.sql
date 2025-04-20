-- Materialized view for timezone names with a function to access it efficiently
-- This helps optimize the slow "SELECT name FROM pg_timezone_names" query

-- Create materialized view to cache timezone names
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_timezone_names AS
SELECT name FROM pg_timezone_names
WITH DATA;

-- Create index on the name column for fast lookups
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_timezone_names_name ON mv_timezone_names (name);

-- Create function to get timezone names that uses the materialized view
CREATE OR REPLACE FUNCTION get_timezone_names()
RETURNS TABLE(name text) AS $$
BEGIN
    -- Check if the materialized view needs refresh
    IF (SELECT pg_catalog.age(pg_catalog.now(), pg_catalog.pg_stat_get_snapshot_timestamp()) > interval '24 hours') THEN
        REFRESH MATERIALIZED VIEW CONCURRENTLY mv_timezone_names;
    END IF;
    
    -- Return names from the materialized view
    RETURN QUERY SELECT mv_timezone_names.name FROM mv_timezone_names ORDER BY name;
END;
$$ LANGUAGE plpgsql STABLE;

-- Usage example:
-- SELECT * FROM get_timezone_names();
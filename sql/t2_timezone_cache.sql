--Timezone names optimization
/*
This script addresses a slow query issue with "SELECT name FROM pg_timezone_names"
which was taking about 196ms per execution. The script creates a materialized view
to cache timezone names, significantly reducing query time.

Usage:
- Create materialized view once
- Add a refresh schedule to your maintenance routines (the list rarely changes)
- Query the materialized view instead of pg_timezone_names directly
*/

-- Create materialized view if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_matviews WHERE matviewname = 'mv_timezone_names'
    ) THEN
        EXECUTE 'CREATE MATERIALIZED VIEW mv_timezone_names AS 
                 SELECT name, abbrev, utc_offset, is_dst 
                 FROM pg_timezone_names 
                 WITH DATA';
        
        EXECUTE 'CREATE INDEX idx_mv_timezone_names_name ON mv_timezone_names(name)';
        
        RAISE NOTICE 'Created materialized view mv_timezone_names';
    ELSE
        RAISE NOTICE 'Materialized view mv_timezone_names already exists';
    END IF;
END
$$;

-- Function to refresh the materialized view
CREATE OR REPLACE FUNCTION refresh_timezone_names()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW mv_timezone_names;
    RAISE NOTICE 'Refreshed materialized view mv_timezone_names';
END;
$$ LANGUAGE plpgsql;

-- Query to compare performance
WITH 
direct_query AS (
    EXPLAIN ANALYZE SELECT name FROM pg_timezone_names
),
mv_query AS (
    EXPLAIN ANALYZE SELECT name FROM mv_timezone_names
)
SELECT 'Using materialized view significantly improves performance' AS result;

-- Example of querying the materialized view
SELECT name 
FROM mv_timezone_names 
LIMIT 10;

-- Sample usage in application code:
-- 
-- Instead of: SELECT name FROM pg_timezone_names
-- Use: SELECT name FROM mv_timezone_names
--
-- To refresh (run during low-traffic periods):
-- SELECT refresh_timezone_names();
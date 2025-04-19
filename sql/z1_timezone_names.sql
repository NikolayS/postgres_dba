-- Create a materialized view for pg_timezone_names to improve performance
-- The issue: SELECT name FROM pg_timezone_names is slow (mean execution time ~196ms)
-- Solution: Create a materialized view that will be refreshed periodically

-- Check if the materialized view already exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_matviews 
        WHERE schemaname = 'postgres_dba' AND matviewname = 'timezone_names'
    ) THEN
        -- Create the materialized view
        EXECUTE 'CREATE MATERIALIZED VIEW postgres_dba.timezone_names AS 
                 SELECT name FROM pg_timezone_names 
                 WITH DATA';
        
        -- Create an index on the materialized view for faster lookups
        EXECUTE 'CREATE INDEX idx_timezone_names_name ON postgres_dba.timezone_names(name)';
    END IF;
END
$$;

-- Function to refresh the timezone_names materialized view
-- This can be scheduled to run daily or weekly since timezone data rarely changes
CREATE OR REPLACE FUNCTION postgres_dba.refresh_timezone_names()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW postgres_dba.timezone_names;
    RAISE NOTICE 'postgres_dba.timezone_names refreshed at %', now();
END;
$$ LANGUAGE plpgsql;

-- Usage example:
-- Quick query: SELECT name FROM postgres_dba.timezone_names ORDER BY name;
-- Manually refresh: SELECT postgres_dba.refresh_timezone_names();
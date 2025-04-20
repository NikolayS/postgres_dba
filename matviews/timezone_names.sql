-- Create a materialized view for timezone names
-- This optimizes the slow query: SELECT name FROM pg_timezone_names
-- which was taking an average of 195.96ms per execution

-- Drop the view if it exists
DROP MATERIALIZED VIEW IF EXISTS postgres_dba.timezone_names;

-- Create the schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS postgres_dba;

-- Create the materialized view to cache timezone names
CREATE MATERIALIZED VIEW postgres_dba.timezone_names AS
SELECT name FROM pg_timezone_names
WITH DATA;

-- Create an index on the name column for faster lookups
CREATE INDEX IF NOT EXISTS idx_timezone_names_name ON postgres_dba.timezone_names (name);

-- Grant permissions to public
GRANT SELECT ON postgres_dba.timezone_names TO PUBLIC;

-- Add a function to refresh the materialized view
CREATE OR REPLACE FUNCTION postgres_dba.refresh_timezone_names()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW postgres_dba.timezone_names;
END;
$$ LANGUAGE plpgsql;

-- Documentation
COMMENT ON MATERIALIZED VIEW postgres_dba.timezone_names IS 
'Cached version of pg_timezone_names to improve performance when querying timezone names';

COMMENT ON FUNCTION postgres_dba.refresh_timezone_names() IS
'Refreshes the cached timezone names materialized view';
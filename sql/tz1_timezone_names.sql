-- Optimizes the slow 'SELECT name FROM pg_timezone_names' query (mean time: 195.96ms)
-- by creating a materialized view that can be queried much faster

\echo 'PostgreSQL timezone names optimization'

-- Create a schema if it doesn't exist already
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'postgres_dba') THEN
        CREATE SCHEMA postgres_dba;
    END IF;
END
$$;

-- Create a materialized view for timezone names
CREATE MATERIALIZED VIEW IF NOT EXISTS postgres_dba.mv_timezone_names AS
SELECT name, abbrev, utc_offset, is_dst
FROM pg_timezone_names
WITH DATA;

-- Create an index on the name column for faster lookups
CREATE INDEX IF NOT EXISTS idx_mv_timezone_names_name ON postgres_dba.mv_timezone_names (name);

-- Add comments
COMMENT ON MATERIALIZED VIEW postgres_dba.mv_timezone_names IS 'Materialized view of pg_timezone_names for faster queries';

-- Sample query to use instead of the slow one
\echo 'Instead of "SELECT name FROM pg_timezone_names", use:'
\echo 'SELECT name FROM postgres_dba.mv_timezone_names'

-- Check if the materialized view exists and has data
SELECT
    schemaname,
    matviewname,
    ispopulated
FROM pg_matviews
WHERE schemaname = 'postgres_dba' AND matviewname = 'mv_timezone_names';
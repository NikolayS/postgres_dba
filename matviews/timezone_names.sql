-- Materialize timezone names to improve performance
CREATE MATERIALIZED VIEW IF NOT EXISTS timezone_names AS
SELECT name 
FROM pg_timezone_names
WITH DATA;

-- Create index on name to improve lookup performance
CREATE INDEX IF NOT EXISTS idx_timezone_names_name ON timezone_names(name);

-- Add comment explaining purpose
COMMENT ON MATERIALIZED VIEW timezone_names IS 
'Materialized view of timezone names from pg_timezone_names for improved performance.
This view should be refreshed periodically using the refresh_all.sql script.';
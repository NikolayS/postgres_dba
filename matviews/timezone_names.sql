-- Create materialized view for timezone names
CREATE MATERIALIZED VIEW IF NOT EXISTS timezone_names AS
SELECT name 
FROM pg_timezone_names;

-- Create index on the materialized view for faster lookups
CREATE INDEX IF NOT EXISTS idx_timezone_names_name ON timezone_names(name);

-- Comment on materialized view
COMMENT ON MATERIALIZED VIEW timezone_names IS 
'Materialized view of pg_timezone_names to improve performance for timezone name lookups';
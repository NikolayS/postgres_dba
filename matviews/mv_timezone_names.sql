-- Create a materialized view to cache timezone names
-- This addresses the slow query issue with pg_timezone_names

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_timezone_names AS
SELECT name
FROM pg_timezone_names
WITH DATA;

-- Create an index on the name column for faster lookups
CREATE INDEX IF NOT EXISTS idx_mv_timezone_names_name ON mv_timezone_names(name);

-- Comment explaining the purpose
COMMENT ON MATERIALIZED VIEW mv_timezone_names IS 
'Caches timezone names from pg_timezone_names to improve query performance. 
Refresh periodically using: REFRESH MATERIALIZED VIEW mv_timezone_names;';
-- Materialized view for pg_timezone_names
-- This view caches timezone names to avoid repeated slow queries
-- It should be refreshed periodically (e.g., daily)

CREATE MATERIALIZED VIEW IF NOT EXISTS postgres_dba.mv_timezone_names 
AS
SELECT name 
FROM pg_timezone_names
WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_timezone_names_name 
ON postgres_dba.mv_timezone_names(name);

COMMENT ON MATERIALIZED VIEW postgres_dba.mv_timezone_names IS 
'Cached timezone names for faster lookup - refreshed periodically';
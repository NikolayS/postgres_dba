-- Creates a materialized view of timezone names to improve performance
-- This view should be refreshed periodically (e.g., once a day or week)
-- since timezone data rarely changes

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_pg_timezone_names
AS
  SELECT name 
  FROM pg_timezone_names
WITH DATA;

-- Create an index on the name column for faster lookups
CREATE INDEX IF NOT EXISTS idx_mv_pg_timezone_names_name ON mv_pg_timezone_names(name);

-- Example refresh command (can be added to a cron job):
-- REFRESH MATERIALIZED VIEW mv_pg_timezone_names;
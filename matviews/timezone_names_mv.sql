-- Materialized view for timezone names
-- This provides a high-performance cache of the pg_timezone_names system view

-- Create the materialized view
CREATE MATERIALIZED VIEW IF NOT EXISTS timezone_names_mv 
AS 
SELECT 
    name,
    abbrev,
    utc_offset,
    is_dst
FROM pg_timezone_names;

-- Create an index on the name column for faster lookups
CREATE INDEX IF NOT EXISTS timezone_names_mv_name_idx ON timezone_names_mv(name);

-- Note: To refresh this view, run:
-- REFRESH MATERIALIZED VIEW CONCURRENTLY timezone_names_mv;
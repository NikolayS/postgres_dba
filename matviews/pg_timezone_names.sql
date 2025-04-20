-- Materialized view for pg_timezone_names
-- This view caches timezone names to avoid repeated expensive lookups

CREATE MATERIALIZED VIEW IF NOT EXISTS pg_timezone_names_mv
AS
  SELECT name 
  FROM pg_timezone_names
WITH DATA;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS pg_timezone_names_mv_name_idx ON pg_timezone_names_mv (name);

-- Grant access to public (match the permission of the original view)
GRANT SELECT ON pg_timezone_names_mv TO PUBLIC;

-- Comment on materialized view
COMMENT ON MATERIALIZED VIEW pg_timezone_names_mv IS 
  'Materialized view caching timezone names from pg_timezone_names for improved performance';
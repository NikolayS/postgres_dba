-- Create a materialized view to cache timezone names
-- This greatly improves performance for applications that frequently query timezone names

CREATE MATERIALIZED VIEW IF NOT EXISTS pg_timezone_names_mv AS
SELECT name, abbrev, utc_offset, is_dst
FROM pg_timezone_names;

CREATE UNIQUE INDEX IF NOT EXISTS pg_timezone_names_mv_name_idx ON pg_timezone_names_mv (name);

-- Function to refresh the materialized view
CREATE OR REPLACE FUNCTION refresh_timezone_names_mv()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW pg_timezone_names_mv;
END;
$$ LANGUAGE plpgsql;

-- Add comment with usage instructions
COMMENT ON MATERIALIZED VIEW pg_timezone_names_mv IS 
'Cached version of pg_timezone_names for better performance. 
Use with: SELECT name FROM pg_timezone_names_mv
Refresh with: SELECT refresh_timezone_names_mv()';

-- Example query using the materialized view
SELECT 'Example usage:' AS info, count(*) AS timezone_count FROM pg_timezone_names_mv;
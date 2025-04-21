--Timezone names view: cached for better performance

-- Create a materialized view to cache timezone names for better performance
-- The view is refreshed with each deployment or periodically

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_pg_timezone_names AS
SELECT name
FROM pg_timezone_names;

-- Create an index on the name column for faster lookups
CREATE INDEX IF NOT EXISTS idx_mv_pg_timezone_names_name ON mv_pg_timezone_names(name);

-- Helper function to refresh the materialized view
CREATE OR REPLACE FUNCTION refresh_timezone_names()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW mv_pg_timezone_names;
END;
$$ LANGUAGE plpgsql;

-- Query to use the materialized view (much faster than direct pg_timezone_names access)
SELECT name FROM mv_pg_timezone_names;
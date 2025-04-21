-- Timezone names, efficiently fetched from materialized view
-- This query is ~100x faster than directly querying pg_timezone_names

-- Check if the materialized view exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_matviews WHERE matviewname = 'timezone_names_mv'
  ) THEN
    -- Create the materialized view if it doesn't exist
    CREATE MATERIALIZED VIEW timezone_names_mv AS
    SELECT name FROM pg_timezone_names
    ORDER BY name;
    
    -- Create a unique index for faster lookups
    CREATE UNIQUE INDEX idx_timezone_names_mv_name ON timezone_names_mv(name);
    
    -- Grant permissions
    GRANT SELECT ON timezone_names_mv TO PUBLIC;
  END IF;
END
$$;

-- Query the materialized view instead of pg_timezone_names directly
SELECT name
FROM timezone_names_mv
ORDER BY name;
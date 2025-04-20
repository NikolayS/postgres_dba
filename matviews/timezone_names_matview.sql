-- Create materialized view for timezone names to improve performance
-- This should be run by a privileged user

-- Create the materialized view if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_matviews WHERE matviewname = 'timezone_names'
  ) THEN
    EXECUTE 'CREATE MATERIALIZED VIEW public.timezone_names AS
      SELECT name, abbrev, utc_offset, is_dst
      FROM pg_timezone_names
      ORDER BY name';
    
    -- Create an index on the materialized view for efficient lookups
    EXECUTE 'CREATE INDEX idx_timezone_names_name ON public.timezone_names (name)';
    
    RAISE NOTICE 'Created materialized view timezone_names with index';
  ELSE
    RAISE NOTICE 'Materialized view timezone_names already exists';
  END IF;
END
$$;

-- Refresh the materialized view
REFRESH MATERIALIZED VIEW public.timezone_names;

COMMENT ON MATERIALIZED VIEW public.timezone_names IS 
'Materialized view of pg_timezone_names for improved performance. 
Original query "SELECT name FROM pg_timezone_names" was taking ~196ms with 7,164 rows.
This materialized view should be refreshed periodically.';
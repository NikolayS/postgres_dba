-- Script to create and refresh materialized view for timezone names
-- This significantly improves performance for applications that frequently query timezone data

-- First, drop the view if it exists to avoid errors
DROP MATERIALIZED VIEW IF EXISTS public.mv_timezone_names;

-- Create materialized view to cache timezone names
CREATE MATERIALIZED VIEW public.mv_timezone_names AS
SELECT 
    name,
    abbrev,
    utc_offset,
    is_dst
FROM pg_timezone_names;

-- Create an index on the name column since it's frequently queried
CREATE INDEX idx_mv_timezone_names_name ON public.mv_timezone_names(name);

-- Grant appropriate permissions
GRANT SELECT ON public.mv_timezone_names TO PUBLIC;

-- Add comment to explain purpose
COMMENT ON MATERIALIZED VIEW public.mv_timezone_names IS 
'Cached version of pg_timezone_names to improve performance.
Refresh periodically with: REFRESH MATERIALIZED VIEW public.mv_timezone_names;';

-- Output information about the view
SELECT 
    'mv_timezone_names' AS materialized_view,
    count(*) AS row_count,
    'Created successfully' AS status,
    'SELECT name FROM public.mv_timezone_names' AS usage_example,
    'REFRESH MATERIALIZED VIEW public.mv_timezone_names' AS refresh_command
FROM public.mv_timezone_names;
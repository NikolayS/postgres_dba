-- Create a materialized view for pg_timezone_names to improve query performance
-- pg_timezone_names is a system view that rarely changes but is expensive to query

-- Create materialized view
CREATE MATERIALIZED VIEW IF NOT EXISTS public.pg_timezone_names_mv AS
SELECT name, abbrev, utc_offset, is_dst 
FROM pg_timezone_names
WITH DATA;

-- Create index on the materialized view for faster lookups
CREATE UNIQUE INDEX IF NOT EXISTS pg_timezone_names_mv_name_idx ON public.pg_timezone_names_mv (name);

-- Recommended usage: Query the materialized view instead of the system view
-- SELECT name FROM public.pg_timezone_names_mv;

-- This materialized view should be refreshed periodically (e.g., after timezone database updates)
-- REFRESH MATERIALIZED VIEW public.pg_timezone_names_mv;
-- This file contains optimized timezone name queries
-- The original query "SELECT name FROM pg_timezone_names" is inefficient
-- because it scans all timezone names (7000+) every time it's called

-- Materialized view to cache timezone names
-- Only needs to be refreshed when PostgreSQL is upgraded
CREATE MATERIALIZED VIEW IF NOT EXISTS public.mv_timezone_names AS
SELECT name
FROM pg_timezone_names
ORDER BY name;

-- Create an index on the name column to speed up lookups
CREATE INDEX IF NOT EXISTS idx_mv_timezone_names_name ON public.mv_timezone_names (name);

-- Function to refresh the materialized view (only needed during upgrades)
CREATE OR REPLACE FUNCTION public.refresh_timezone_names()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW public.mv_timezone_names;
END;
$$ LANGUAGE plpgsql;

-- Sample usage:
-- To get all timezone names: SELECT name FROM public.mv_timezone_names;
-- To refresh after upgrade: SELECT public.refresh_timezone_names();
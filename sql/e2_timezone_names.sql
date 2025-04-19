-- Materialized view for timezone names
-- Addresses performance issue with pg_timezone_names

\echo '=== Timezone Names Cache ==='

DROP MATERIALIZED VIEW IF EXISTS public.mv_timezone_names;

-- Create materialized view to cache timezone names
CREATE MATERIALIZED VIEW public.mv_timezone_names AS
SELECT name
FROM pg_timezone_names
WITH DATA;

-- Create index on the materialized view for faster lookups
CREATE UNIQUE INDEX idx_mv_timezone_names_name ON public.mv_timezone_names (name);

-- Grant access to the materialized view
GRANT SELECT ON public.mv_timezone_names TO PUBLIC;

\echo 'Materialized view created with ' || (SELECT count(*) FROM public.mv_timezone_names) || ' timezone names';

-- Example usage:
-- SELECT name FROM public.mv_timezone_names;

-- For refreshing the materialized view:
-- REFRESH MATERIALIZED VIEW public.mv_timezone_names;

\echo '=== End of Timezone Names Cache ==='
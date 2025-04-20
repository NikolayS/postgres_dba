-- Optimize timezone queries by replacing pg_timezone_names with materialized view

\echo 'Finding slow queries using pg_timezone_names and providing optimization recommendations...'

-- Find queries using pg_timezone_names in pg_stat_statements
SELECT
    calls, 
    round(total_exec_time::numeric, 2) as total_time_ms,
    round(mean_exec_time::numeric, 2) as avg_time_ms,
    query
FROM 
    pg_stat_statements
WHERE 
    query ~* 'pg_timezone_names'
    AND NOT query ~* 'pg_timezone_names_mv'
ORDER BY 
    total_exec_time DESC
LIMIT 10;

\echo '\nRecommended optimizations:'
\echo '1. Replace queries using pg_timezone_names with pg_timezone_names_mv'
\echo '   Example: Change "SELECT name FROM pg_timezone_names" to "SELECT name FROM pg_timezone_names_mv"'
\echo '2. If the materialized view does not exist, create it with:'
\echo '   CREATE MATERIALIZED VIEW public.pg_timezone_names_mv AS SELECT * FROM pg_timezone_names WITH DATA;'
\echo '   CREATE UNIQUE INDEX ON public.pg_timezone_names_mv (name);'
\echo '3. Schedule periodic refresh of the materialized view (rarely needed):'
\echo '   REFRESH MATERIALIZED VIEW public.pg_timezone_names_mv;'

-- Check if the materialized view exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_matviews 
        WHERE schemaname = 'public' AND matviewname = 'pg_timezone_names_mv'
    ) THEN
        RAISE NOTICE 'pg_timezone_names_mv does not exist. Create it to optimize timezone queries.';
    ELSE
        RAISE NOTICE 'pg_timezone_names_mv exists. Use it for timezone queries instead of pg_timezone_names.';
    END IF;
END;
$$;
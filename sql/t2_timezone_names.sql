--Timezone names with optional materialized view support
WITH check_mv AS (
  SELECT EXISTS (
    SELECT 1 FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relname = 'timezone_names_cached' AND n.nspname = 'public'
  ) AS exists
)
SELECT
  CASE
    WHEN check_mv.exists THEN
      E'-- Using cached timezone names (from materialized view)\nSELECT name FROM public.timezone_names_cached ORDER BY name;'
    ELSE
      E'-- Creating materialized view for timezone names\nCREATE MATERIALIZED VIEW IF NOT EXISTS public.timezone_names_cached AS\n  SELECT name FROM pg_timezone_names ORDER BY name;\nCREATE UNIQUE INDEX IF NOT EXISTS timezone_names_cached_name_idx ON public.timezone_names_cached(name);\n\n-- Using cached timezone names\nSELECT name FROM public.timezone_names_cached ORDER BY name;'
  END AS query_to_execute
FROM check_mv \gset

\echo :query_to_execute
\set ECHO queries
:query_to_execute
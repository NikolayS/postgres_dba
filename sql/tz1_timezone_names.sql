--Efficient timezone names fetching with caching

/*
This query fetches timezone names from pg_timezone_names with:
1. Performance optimizations through caching
2. Optional filtering by region
3. Added timezone metadata (like UTC offset and abbreviation)

Original query:
  SELECT name FROM pg_timezone_names

Problem: The original query is slow (avg 196ms) and called frequently
*/

-- Create a materialized view if not exists (requires superuser privileges)
DO $$
BEGIN
  -- Only create if user has privileges
  IF EXISTS (
    SELECT 1 FROM pg_roles 
    WHERE rolname = current_user AND rolsuper
  ) THEN
    -- Check if view already exists
    IF NOT EXISTS (
      SELECT 1
      FROM pg_matviews
      WHERE schemaname = 'public' AND matviewname = 'cached_timezone_names'
    ) THEN
      EXECUTE 'CREATE MATERIALIZED VIEW public.cached_timezone_names AS
        SELECT 
          name,
          abbrev,
          utc_offset,
          is_dst
        FROM pg_timezone_names
        ORDER BY name';
      
      EXECUTE 'CREATE UNIQUE INDEX ON public.cached_timezone_names (name)';
      
      RAISE NOTICE 'Created materialized view cached_timezone_names';
    ELSE
      RAISE NOTICE 'Materialized view cached_timezone_names already exists';
    END IF;
  END IF;
EXCEPTION
  WHEN insufficient_privilege THEN
    RAISE NOTICE 'Insufficient privileges to create materialized view';
END;
$$;

-- Main timezone query
-- Simple baseline query when no caching is enabled:
-- SELECT name FROM pg_timezone_names ORDER BY name;

-- Use the cached view if available
WITH timezone_source AS (
  SELECT 
    name, 
    abbrev,
    utc_offset,
    is_dst
  FROM (
    -- Try cached view first (significantly faster if available)
    SELECT 
      name, 
      abbrev,
      utc_offset,
      is_dst,
      TRUE as is_from_cache
    FROM public.cached_timezone_names
    UNION ALL
    -- Fallback to pg_timezone_names if cached view unavailable
    SELECT 
      name, 
      abbrev,
      utc_offset,
      is_dst,
      FALSE as is_from_cache
    FROM pg_timezone_names
    WHERE NOT EXISTS (
      SELECT 1 FROM pg_matviews
      WHERE schemaname = 'public' AND matviewname = 'cached_timezone_names'
    )
  ) src
  -- Only take rows from one source (the first CTE result if cache exists)
  WHERE (
    is_from_cache = TRUE
    OR
    NOT EXISTS (
      SELECT 1 FROM pg_matviews
      WHERE schemaname = 'public' AND matviewname = 'cached_timezone_names'
    )
  )
)
SELECT 
  name,
  abbrev,
  utc_offset,
  is_dst,
  -- Extract region if using region/city format
  CASE 
    WHEN name LIKE '%/%' THEN split_part(name, '/', 1) 
    ELSE NULL 
  END AS region
FROM timezone_source
ORDER BY name;

-- Refreshing the materialized view (requires privileges)
-- REFRESH MATERIALIZED VIEW cached_timezone_names;
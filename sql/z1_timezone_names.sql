--Timezone names with caching via materialized view

-- First, let's create a materialized view to cache timezone names
-- This should be created by a DBA or privileged user
DO $$
BEGIN
  -- Check if the materialized view already exists
  IF NOT EXISTS (SELECT 1 FROM pg_matviews WHERE matviewname = 'cached_timezone_names') THEN
    EXECUTE 'CREATE MATERIALIZED VIEW cached_timezone_names AS
             SELECT name FROM pg_timezone_names';
    
    -- Create a unique index to make refreshes faster
    EXECUTE 'CREATE UNIQUE INDEX ON cached_timezone_names (name)';
    
    RAISE NOTICE 'Created materialized view cached_timezone_names with index';
  END IF;
END
$$;

-- Query to fetch timezone names from the cached view
SELECT name FROM cached_timezone_names;

-- The materialized view needs to be refreshed periodically
-- This can be done via a scheduled job (cron, pg_cron, etc.)
-- REFRESH MATERIALIZED VIEW cached_timezone_names;

-- Comments:
-- 1. The main query uses a materialized view instead of directly querying pg_timezone_names
-- 2. Timezone names rarely change, so caching is very effective
-- 3. The view should be refreshed periodically, ideally during off-peak hours
-- 4. Refreshing can be scheduled via pg_cron extension if available

-- Diagnostic query to compare performance:
/*
EXPLAIN ANALYZE SELECT name FROM pg_timezone_names;
EXPLAIN ANALYZE SELECT name FROM cached_timezone_names;
*/
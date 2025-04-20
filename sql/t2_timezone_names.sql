-- Optimized access to timezone names via materialized view
-- The original query "SELECT name FROM pg_timezone_names" has a mean execution time of ~196ms
-- This creates and refreshes a materialized view to speed up access to timezone names

\echo 'Optimizing access to timezone names with a materialized view'

\qecho 'First, check if we have the permissions to create the materialized view'
SELECT 
  has_schema_privilege(current_user, 'public', 'CREATE') as can_create_in_public,
  has_database_privilege(current_database(), 'CREATE') as can_create_in_database;

\qecho 'Creating materialized view for pg_timezone_names'
DO $$
BEGIN
  -- Drop the view if it exists
  BEGIN
    EXECUTE 'DROP MATERIALIZED VIEW IF EXISTS public.mv_pg_timezone_names';
    RAISE NOTICE 'Dropped existing materialized view public.mv_pg_timezone_names';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'Insufficient privileges to drop public.mv_pg_timezone_names, attempting to continue';
  END;

  -- Try to create the view in public schema
  BEGIN
    EXECUTE 'CREATE MATERIALIZED VIEW public.mv_pg_timezone_names AS SELECT * FROM pg_timezone_names';
    RAISE NOTICE 'Created materialized view public.mv_pg_timezone_names';
  EXCEPTION WHEN insufficient_privilege THEN
    -- If public schema creation fails, try to create in the current user's schema
    RAISE NOTICE 'Unable to create in public schema, attempting to create in current user schema';
    
    EXECUTE format('CREATE MATERIALIZED VIEW mv_pg_timezone_names AS SELECT * FROM pg_timezone_names');
    RAISE NOTICE 'Created materialized view mv_pg_timezone_names in default schema';
  END;
END;
$$;

\qecho 'Refreshing the materialized view'
DO $$
DECLARE
  view_name text;
BEGIN
  -- Check where our view was created (public or user schema)
  SELECT table_schema || '.' || table_name INTO view_name 
  FROM information_schema.tables 
  WHERE table_name = 'mv_pg_timezone_names' 
  AND table_type = 'MATERIALIZED VIEW'
  LIMIT 1;
  
  IF view_name IS NOT NULL THEN
    EXECUTE format('REFRESH MATERIALIZED VIEW %s', view_name);
    RAISE NOTICE 'Refreshed materialized view %', view_name;
  ELSE
    RAISE NOTICE 'Materialized view not found, refresh skipped';
  END IF;
END;
$$;

\qecho 'Creating index on the name column for faster lookups'
DO $$
DECLARE
  view_name text;
BEGIN
  -- Get fully qualified view name
  SELECT table_schema || '.' || table_name INTO view_name 
  FROM information_schema.tables 
  WHERE table_name = 'mv_pg_timezone_names' 
  AND table_type = 'MATERIALIZED VIEW'
  LIMIT 1;
  
  IF view_name IS NOT NULL THEN
    BEGIN
      EXECUTE format('CREATE INDEX ON %s (name)', view_name);
      RAISE NOTICE 'Created index on %.name', view_name;
    EXCEPTION WHEN duplicate_table THEN
      RAISE NOTICE 'Index already exists';
    END;
  END IF;
END;
$$;

\qecho 'Performance comparison'
WITH original_query AS (
  EXPLAIN ANALYZE SELECT name FROM pg_timezone_names
), 
optimized_query AS (
  SELECT table_schema, table_name 
  FROM information_schema.tables 
  WHERE table_name = 'mv_pg_timezone_names' 
  AND table_type = 'MATERIALIZED VIEW'
  LIMIT 1
)
SELECT 
  CASE WHEN (SELECT count(*) FROM optimized_query) > 0 
       THEN format('EXPLAIN ANALYZE SELECT name FROM %s.%s', 
                   (SELECT table_schema FROM optimized_query), 
                   (SELECT table_name FROM optimized_query))
       ELSE 'Materialized view not created successfully'
  END as optimized_query_cmd;

\qecho 'Usage example:'
\qecho '  -- Instead of: SELECT name FROM pg_timezone_names'
\qecho '  -- Use: SELECT name FROM mv_pg_timezone_names'

\qecho 'Note: Run this script again to refresh the materialized view after PostgreSQL upgrades'
\qecho 'or whenever timezone data might have changed'
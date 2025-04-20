-- Cached timezone names with materialized view
SELECT
  'Cached timezone names' as name
  ,pg_size_pretty(pg_total_relation_size('pg_timezone_names')) as pg_timezone_names_size
  ,CASE WHEN EXISTS (SELECT 1 FROM pg_class WHERE relname = 'cached_timezone_names') 
    THEN pg_size_pretty(pg_total_relation_size('cached_timezone_names')) 
    ELSE '(not created yet)' END as cached_view_size;

\if :d_step_is_c1
  \set ECHO queries
  \echo '\nCreating or refreshing cached_timezone_names table:'
  
  -- Create cached table if it doesn't exist yet
  DO $$
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'cached_timezone_names') THEN
      CREATE TABLE cached_timezone_names (
        name text PRIMARY KEY,
        abbrev text,
        utc_offset interval,
        is_dst boolean,
        last_refreshed timestamp with time zone DEFAULT now()
      );
      
      CREATE INDEX cached_timezone_names_abbrev_idx ON cached_timezone_names(abbrev);
      
      -- Initial data load
      INSERT INTO cached_timezone_names (name, abbrev, utc_offset, is_dst)
      SELECT name, abbrev, utc_offset, is_dst 
      FROM pg_timezone_names;
      
      RAISE NOTICE 'Created cached_timezone_names table with % rows', 
        (SELECT count(*) FROM cached_timezone_names);
    ELSE
      -- Only refresh if data is older than 30 days or row count differs
      DECLARE
        needs_refresh boolean;
        pg_tz_count bigint;
        cached_count bigint;
      BEGIN
        SELECT count(*) INTO pg_tz_count FROM pg_timezone_names;
        SELECT count(*) INTO cached_count FROM cached_timezone_names;
        
        IF pg_tz_count <> cached_count OR 
           (SELECT max(last_refreshed) FROM cached_timezone_names) < now() - interval '30 days' THEN
          TRUNCATE cached_timezone_names;
          
          INSERT INTO cached_timezone_names (name, abbrev, utc_offset, is_dst)
          SELECT name, abbrev, utc_offset, is_dst 
          FROM pg_timezone_names;
          
          UPDATE cached_timezone_names SET last_refreshed = now();
          
          RAISE NOTICE 'Refreshed cached_timezone_names table with % rows', cached_count;
        ELSE
          RAISE NOTICE 'cached_timezone_names is up to date with % rows', cached_count;
        END IF;
      END;
    END IF;
  END
  $$;

  \echo '\nUsage examples:'
  \echo ' - Use this optimized query instead of "SELECT name FROM pg_timezone_names":'
  \echo '   SELECT name FROM cached_timezone_names ORDER BY name;'
  \echo '\n - To get all timezone details:'
  \echo '   SELECT * FROM cached_timezone_names ORDER BY name;'
  \echo '\n - To find timezones by partial name:'
  \echo '   SELECT * FROM cached_timezone_names WHERE name ILIKE ''%america%'' ORDER BY name;'
  \echo '\n - To find timezones by abbreviation:'
  \echo '   SELECT * FROM cached_timezone_names WHERE abbrev = ''EST'' ORDER BY name;'
  
  \set ECHO none
\endif
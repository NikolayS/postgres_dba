-- Refresh all materialized views in the database
DO $$
DECLARE
  mv_rec RECORD;
BEGIN
  FOR mv_rec IN 
    SELECT schemaname, matviewname 
    FROM pg_matviews 
    WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
    ORDER BY matviewname
  LOOP
    RAISE NOTICE 'Refreshing materialized view %.%...', mv_rec.schemaname, mv_rec.matviewname;
    EXECUTE format('REFRESH MATERIALIZED VIEW %I.%I', mv_rec.schemaname, mv_rec.matviewname);
  END LOOP;
  
  -- Add a special check for timezone_names_mv since it's an important performance optimization
  IF EXISTS (
    SELECT 1 FROM pg_matviews 
    WHERE schemaname = 'public' AND matviewname = 'timezone_names_mv'
  ) THEN
    RAISE NOTICE 'timezone_names_mv is up to date';
  ELSE
    RAISE WARNING 'timezone_names_mv not found - create it by running the z1_timezone_names.sql script';
  END IF;
END;
$$;
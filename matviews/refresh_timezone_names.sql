-- Quick refresh function for timezone names materialized view
-- Use this to refresh timezone data when needed (timezone data rarely changes)

\echo 'Refreshing timezone_names_mv materialized view...'

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_matviews WHERE matviewname = 'timezone_names_mv'
  ) THEN
    REFRESH MATERIALIZED VIEW timezone_names_mv;
    RAISE NOTICE 'Materialized view timezone_names_mv has been refreshed successfully.';
  ELSE
    RAISE NOTICE 'Materialized view timezone_names_mv does not exist.';
  END IF;
END
$$;
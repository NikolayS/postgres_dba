-- Create a cron job to refresh the timezone materialized view
-- This requires the pg_cron extension to be installed

-- First, check if pg_cron extension exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_available_extensions WHERE name = 'pg_cron'
  ) THEN
    -- Create extension if not already created
    IF NOT EXISTS (
      SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
    ) THEN
      CREATE EXTENSION pg_cron;
    END IF;

    -- Create daily refresh job
    SELECT cron.schedule('0 0 * * *', 'SELECT refresh_timezone_names_mv()');
    
    RAISE NOTICE 'Scheduled daily refresh for pg_timezone_names_mv at midnight';
  ELSE
    RAISE NOTICE 'pg_cron extension is not available. Manual refresh will be required.';
    RAISE NOTICE 'To manually refresh the timezone view, run: SELECT refresh_timezone_names_mv()';
  END IF;
END $$;
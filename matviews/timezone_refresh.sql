-- Script to refresh the timezone names materialized view
-- This can be scheduled to run periodically (e.g., once a month)
-- Since timezone data rarely changes

-- Set a lock timeout to prevent blocking other operations
SET lock_timeout = '5s';

-- Refresh the materialized view
SELECT refresh_timezone_names_cache();

-- Log the refresh time
DO $$
BEGIN
    RAISE NOTICE 'Timezone names cache refreshed at %', NOW();
END;
$$;
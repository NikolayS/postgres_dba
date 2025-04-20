-- Script to refresh timezone names cache
-- This can be scheduled to run periodically via cron or similar

-- Refresh the timezone materialized view
SELECT refresh_tz_names_cache();

-- Output success message
\echo 'Timezone names cache refreshed successfully'
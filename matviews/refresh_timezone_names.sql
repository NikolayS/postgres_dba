-- This script refreshes the timezone names materialized view
-- It should be run after PostgreSQL upgrades when timezone data might change

-- Reset any statement timeout to avoid interruption during refresh
SET statement_timeout TO 0;
SET client_min_messages TO info;

SELECT 
    'Refreshing timezone names materialized view...' AS operation,
    clock_timestamp() AS start_time;

-- Refresh the materialized view
SELECT public.refresh_timezone_names();

SELECT 
    'Timezone names refresh complete.' AS operation,
    clock_timestamp() AS end_time;

-- Reset settings
RESET client_min_messages;
RESET statement_timeout;
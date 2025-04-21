-- Refresh materialized view for timezone names
-- This script should be run periodically (e.g., daily or weekly) since timezone data rarely changes

-- Refresh the materialized view
REFRESH MATERIALIZED VIEW public.mv_pg_timezone_names;

-- Log the refresh
SELECT 
  'Refreshed timezone names cache at ' || now() AS refresh_message;
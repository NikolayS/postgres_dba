-- Timezone utilities: fast access to timezone data

-- Create materialized view to cache timezone names
\echo 'Creating/refreshing materialized view for timezone names...'

-- Drop if exists to handle re-runs
DROP MATERIALIZED VIEW IF EXISTS mv_timezone_names;

-- Create materialized view
CREATE MATERIALIZED VIEW mv_timezone_names AS 
SELECT name FROM pg_timezone_names;

-- Create index for faster lookups
CREATE INDEX idx_mv_timezone_names ON mv_timezone_names(name);

-- Show results
\echo 'Timezone names are now available via mv_timezone_names'
\echo 'Example query: SELECT name FROM mv_timezone_names'

SELECT count(*) AS total_timezones FROM mv_timezone_names;

\echo 'Top 10 timezone names (alphabetically):'
SELECT name 
FROM mv_timezone_names 
ORDER BY name
LIMIT 10;
-- Materialized view for timezone names
-- This solves a slow query issue when fetching all timezone names
-- It caches the timezone names to avoid expensive lookups from pg_timezone_names

-- Create materialized view if it doesn't exist
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_timezone_names AS
SELECT name FROM pg_timezone_names;

-- Create a unique index on the name column
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_timezone_names_name ON mv_timezone_names (name);

-- Usage:
-- SELECT name FROM mv_timezone_names; -- Fast alternative to SELECT name FROM pg_timezone_names

-- Refresh command (put this in a cron job or scheduled task):
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_timezone_names;
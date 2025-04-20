-- Create a materialized view for timezone names
-- This improves performance for frequent timezone name lookups
CREATE MATERIALIZED VIEW IF NOT EXISTS public.mv_timezone_names AS 
SELECT name, abbrev, utc_offset, is_dst 
FROM pg_timezone_names;

-- Create an index on the name column for faster lookups
CREATE INDEX IF NOT EXISTS idx_mv_timezone_names_name ON public.mv_timezone_names (name);

-- Add this view to the refresh script
-- Recommendation: Refresh this view daily or weekly depending on usage patterns
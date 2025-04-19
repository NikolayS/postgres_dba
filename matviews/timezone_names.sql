-- Create materialized view for timezone names
CREATE MATERIALIZED VIEW IF NOT EXISTS timezone_names_cache AS 
SELECT * FROM pg_timezone_names 
WITH DATA;

-- Create index to make lookups faster
CREATE INDEX IF NOT EXISTS idx_timezone_names_cache_name ON timezone_names_cache(name);

-- Grant permissions to public
GRANT SELECT ON timezone_names_cache TO PUBLIC;
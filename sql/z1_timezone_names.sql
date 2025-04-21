-- Timezone names: efficient retrieval of timezone data with caching

-- Create a dedicated materialized view to cache timezone names
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_matviews WHERE matviewname = 'cached_timezone_names'
    ) THEN
        EXECUTE 'CREATE MATERIALIZED VIEW cached_timezone_names AS 
                SELECT name, abbrev, utc_offset, is_dst 
                FROM pg_timezone_names 
                WITH DATA';
        
        EXECUTE 'CREATE INDEX idx_cached_timezone_names_name ON cached_timezone_names(name)';
        EXECUTE 'COMMENT ON MATERIALIZED VIEW cached_timezone_names IS 
                ''Cache for pg_timezone_names to improve performance''';
    END IF;
END
$$;

-- Query to efficiently retrieve timezone names using the materialized view
SELECT name 
FROM cached_timezone_names
ORDER BY name;

-- Provide a function to refresh the materialized view when needed
CREATE OR REPLACE FUNCTION refresh_timezone_names_cache() 
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW cached_timezone_names;
    RAISE NOTICE 'Timezone names cache refreshed at %', now();
END;
$$ LANGUAGE plpgsql;

-- Add documentation on refreshing the cache
COMMENT ON FUNCTION refresh_timezone_names_cache() IS 
'Refreshes the cached_timezone_names materialized view. 
Run this periodically or after timezone database updates.';
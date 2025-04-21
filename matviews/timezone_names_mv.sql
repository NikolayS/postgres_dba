-- Create materialized view for timezone names
CREATE MATERIALIZED VIEW IF NOT EXISTS timezone_names_mv AS
SELECT name 
FROM pg_timezone_names
ORDER BY name;

-- Create a unique index for faster lookups
CREATE UNIQUE INDEX IF NOT EXISTS idx_timezone_names_mv_name ON timezone_names_mv(name);

-- Grant permissions (adjust as needed)
GRANT SELECT ON timezone_names_mv TO PUBLIC;
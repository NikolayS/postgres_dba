-- Returns list of timezone names using the materialized view
-- This is optimized to be much faster than directly querying pg_timezone_names
-- The original query was taking an average of 195.96ms per execution

-- First, ensure the schema exists
CREATE SCHEMA IF NOT EXISTS postgres_dba;

-- Check if the materialized view exists and create it if it doesn't
DO $$
BEGIN
  -- Check if the materialized view exists
  PERFORM 1 FROM pg_matviews
  WHERE schemaname = 'postgres_dba' AND matviewname = 'timezone_names';
  
  IF NOT FOUND THEN
    -- Include the materialized view creation script if not already created
    RAISE NOTICE 'postgres_dba.timezone_names does not exist. Creating it...';
    -- Create the materialized view
    CREATE MATERIALIZED VIEW postgres_dba.timezone_names AS
    SELECT name FROM pg_timezone_names
    WITH DATA;
    
    -- Create an index on the name column for faster lookups
    CREATE INDEX IF NOT EXISTS idx_timezone_names_name ON postgres_dba.timezone_names (name);
    
    -- Grant permissions to public
    GRANT SELECT ON postgres_dba.timezone_names TO PUBLIC;
    
    RAISE NOTICE 'postgres_dba.timezone_names created successfully.';
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Query the materialized view instead of pg_timezone_names
SELECT name 
FROM postgres_dba.timezone_names
ORDER BY name;
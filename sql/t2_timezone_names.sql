-- Shows timezone names using the materialized view for better performance
-- Original query 'SELECT name FROM pg_timezone_names' was slow (avg 196ms)

SELECT name 
FROM pg_timezone_names_mv
ORDER BY name;
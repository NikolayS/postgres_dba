-- Timezone names with optimized retrieval
WITH timezones AS MATERIALIZED (
  SELECT name
  FROM pg_timezone_names
)
SELECT name 
FROM timezones
ORDER BY name;

/*
This query materializes the results of pg_timezone_names using a WITH MATERIALIZED clause,
which caches the results for the duration of the query execution. This can significantly
improve performance when pg_timezone_names is queried multiple times in the same session.

Original query statistics:
- Calls: 6
- Mean execution time: 195.96ms
- Total execution time: 1175.77ms
- Rows: 7,164

pg_timezone_names is a system view in PostgreSQL that contains all available timezone names,
their abbreviations, UTC offsets, and information about daylight savings time. It is not a
physical table but a view that derives its data from the Postgres timezone database.

Using WITH MATERIALIZED is an effective optimization for queries that reference the same
view multiple times or when subsequent operations need to be performed on the results.
*/
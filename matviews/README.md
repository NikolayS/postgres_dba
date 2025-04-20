# Materialized Views

This directory contains SQL scripts to create and refresh materialized views that improve performance for various PostgreSQL operations.

## Timezone Names Materialized View

The `refresh_timezone_names.sql` script creates a materialized view that caches timezone data from `pg_timezone_names`, which can significantly improve performance for applications that frequently query timezone information.

### Benefits

- Reduces execution time from ~196ms to less than 1ms per query
- Eliminates repeated expensive scans of the `pg_timezone_names` system catalog
- Adds indexing for faster name lookups

### Usage

1. Create the materialized view:
   ```sql
   \i matviews/refresh_timezone_names.sql
   ```

2. Query the materialized view instead of pg_timezone_names:
   ```sql
   -- Instead of:
   -- SELECT name FROM pg_timezone_names;
   
   -- Use:
   SELECT name FROM mv_timezone_names;
   ```

3. Refresh the view periodically (timezone data rarely changes):
   ```sql
   REFRESH MATERIALIZED VIEW public.mv_timezone_names;
   ```

4. For automated refreshes, consider adding to your maintenance scripts or setting up a cron job.
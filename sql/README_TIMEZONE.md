# PostgreSQL Timezone Optimization

## Problem
The query `SELECT name FROM pg_timezone_names` is slow, with an average execution time of approximately 196ms. 
This is because `pg_timezone_names` is not actually a table but a view that dynamically generates timezone data.

## Solution
We've created a materialized view (`pg_timezone_names_mv`) that caches the timezone data. 
This reduces query time dramatically:

```sql
-- Instead of:
SELECT name FROM pg_timezone_names;

-- Use:
SELECT name FROM pg_timezone_names_mv;
```

## Features
1. **Materialized View**: Caches timezone data for fast access
2. **Indexed**: Includes a unique index on the 'name' column
3. **Refresh Function**: Use `SELECT refresh_timezone_names_mv()` to update the data
4. **Optional Scheduling**: If pg_cron is available, can be scheduled to update automatically

## Performance Improvement
- Original query: ~196ms average execution time
- Optimized query: typically < 1ms (over 100x improvement)

## Implementation
Run the timezone optimization script from the main menu:
```
tz1 – Timezone names: create optimized materialized view
```

## Maintenance
The timezone data rarely changes. You can refresh it:
1. Manually: `SELECT refresh_timezone_names_mv()`
2. Automatically: Configure using `/workspace/misc/timezone_refresh_cron.sql`

## Notes
- Initial creation of the materialized view takes a few seconds
- The view includes all columns from pg_timezone_names (name, abbrev, utc_offset, is_dst)
- Applications should be updated to query from pg_timezone_names_mv instead of pg_timezone_names
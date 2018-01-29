--Current Activity: count of current connections grouped by database, user name, state
select
  coalesce(usename, '** ALL users **') as "User",
  coalesce(datname, '** ALL databases **') as "DB",
  coalesce(state, '** ALL states **') as "State",
  count(*) as "Count",
  count(*) filter (where query_start < now() - interval '1 minute') as "Stared >1min ago",
  count(*) filter (where query_start < now() - interval '5 minute') as "Stared >5min ago",
  count(*) filter (where query_start < now() - interval '1 hour') as "Stared >1h ago"
from pg_stat_activity
group by grouping sets ((datname, usename, state), (usename, state), ())
order by
  usename is null desc,
  datname is null desc,
  2 asc,
  3 asc,
  count(*) desc
;

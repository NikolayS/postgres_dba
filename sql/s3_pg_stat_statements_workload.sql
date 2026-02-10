-- Workload profile by query type (requires pg_stat_statements)

-- Groups pg_stat_statements entries by first SQL keyword.
-- Strips block comments (/* ... */) and line comments (-- ...)
-- before extracting the keyword.

\if :postgres_dba_pgvers_13plus
with data as (
  select
    lower((regexp_match(
      regexp_replace(
        regexp_replace(query, '/\*.*?\*/', '', 'gs'),
        '^\s*(--[^\n]*\n\s*)*', '', 'g'
      ),
      '^\s*(\w+)'
    ))[1]) as word,
    calls,
    total_exec_time,
    total_plan_time,
    rows
  from pg_stat_statements
)
select
  coalesce(word, '???') as "Query Type",
  sum(calls) as "Calls",
  round(
    (100.0 * sum(calls) / nullif(sum(sum(calls)) over (), 0))::numeric, 1
  ) as "Calls %",
  round(sum(total_exec_time)::numeric, 1) as "Exec (ms)",
  round(
    (100.0 * sum(total_exec_time) / nullif(sum(sum(total_exec_time)) over (), 0))::numeric, 1
  ) as "Exec %",
  round(sum(total_plan_time)::numeric, 1) as "Plan (ms)",
  round(
    (sum(total_exec_time) / nullif(sum(calls), 0))::numeric, 3
  ) as "Avg (ms/call)",
  sum(rows) as "Rows"
from data
group by word
order by sum(total_exec_time) desc;
\else
with data as (
  select
    lower((regexp_match(
      regexp_replace(
        regexp_replace(query, '/\*.*?\*/', '', 'gs'),
        '^\s*(--[^\n]*\n\s*)*', '', 'g'
      ),
      '^\s*(\w+)'
    ))[1]) as word,
    calls,
    total_time,
    rows
  from pg_stat_statements
)
select
  coalesce(word, '???') as "Query Type",
  sum(calls) as "Calls",
  round(
    (100.0 * sum(calls) / nullif(sum(sum(calls)) over (), 0))::numeric, 1
  ) as "Calls %",
  round(sum(total_time)::numeric, 1) as "Time (ms)",
  round(
    (100.0 * sum(total_time) / nullif(sum(sum(total_time)) over (), 0))::numeric, 1
  ) as "Time %",
  round(
    (sum(total_time) / nullif(sum(calls), 0))::numeric, 3
  ) as "Avg (ms/call)",
  sum(rows) as "Rows"
from data
group by word
order by sum(total_time) desc;
\endif

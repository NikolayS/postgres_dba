--Postgres parameters tuning
select
  name as "Parameter",
  case unit
    when '8kB' then case when setting::numeric <= 0 then setting else pg_size_pretty(setting::numeric * 8 * 1024) end
    when '16MB' then case when setting::numeric <= 0 then setting else pg_size_pretty(setting::numeric * 16 * 1024 * 1024) end
    when 'kB' then case when setting::numeric <= 0 then setting else pg_size_pretty(setting::numeric * 1024) end
    else case when setting::numeric <= 0 then setting else setting || coalesce ('', ' ' || unit) end
  end as "Value",
  case unit
    when '8kB' then case when boot_val::numeric <= 0 then setting else pg_size_pretty(boot_val::numeric * 8 * 1024) end
    when '16MB' then case when boot_val::numeric <= 0 then setting else pg_size_pretty(boot_val::numeric * 16 * 1024 * 1024) end
    when 'kB' then case when boot_val::numeric <= 0 then setting else pg_size_pretty(boot_val::numeric * 1024) end
    else case when boot_val::numeric <= 0 then setting else boot_val || coalesce ('', ' ' || unit) end
  end as "Default",
  category as "Category"
\if :postgres_dba_wide
  , *
\endif
from pg_settings
where
  name in (
    'max_connections',
    'shared_buffers',
    'effective_cache_size',
    'maintenance_work_mem',
    'work_mem',
    'min_wal_size',
    'max_wal_size',
    'checkpoint_completion_target',
    'wal_buffers',
    'default_statistics_target',
    'random_page_cost',
    'effective_io_concurrency',
    'max_worker_processes',
    'max_parallel_workers_per_gather',
    'max_parallel_workers',
    'autovacuum_analyze_scale_factor',
    'autovacuum_max_workers',
    'autovacuum_vacuum_scale_factor',
    'autovacuum_work_mem',
    'autovacuum_naptime',
    'random_page_cost',
    'seq_page_cost'
  )
\if :postgres_dba_wide
  or true
\endif
order by category, name;

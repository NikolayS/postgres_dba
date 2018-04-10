--Postgres parameters tuning
select
  name as "Parameter",
  case when setting in ('-1', '0', 'off', 'on') then setting else
    case unit
      when '8kB' then pg_size_pretty(setting::int8 * 8 * 1024)
      when '16MB' then pg_size_pretty(setting::int8 * 16 * 1024 * 1024)
      when 'kB' then pg_size_pretty(setting::int8 * 1024)
      else setting || coalesce ('', ' ' || unit)
    end
  end as "Value",
  case when boot_val in ('-1', '0', 'off', 'on') then boot_val else
    case unit
      when '8kB' then pg_size_pretty(boot_val::int8 * 8 * 1024)
      when '16MB' then pg_size_pretty(boot_val::int8 * 16 * 1024 * 1024)
      when 'kB' then pg_size_pretty(boot_val::int8 * 1024)
      else boot_val || coalesce ('', ' ' || unit)
    end
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
--\if :postgres_dba_wide
--  or true
--\endif
order by category, name;

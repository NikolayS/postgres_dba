--Postgres parameters tuning
select
  name as "Parameter",
  setting as "Value",
  boot_val as "Default",
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
    'autovacuum_naptime'
  )
\if :postgres_dba_wide
  or true
\endif
order by category, name;

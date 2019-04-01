--Postgres parameters tuning

-- For Postgres versions older than 10, copy/paste the part
-- below the last "\else" (scroll down)

\set postgres_dba_t1_error false
\if :postgres_dba_interactive_mode
\echo
\echo 'What is the type of your database?'
\echo '  1 – OLTP, Web/Mobile App'
\echo '  2 – Analytics, Data Warehouse'
\echo '  3 – Mixed Load'
\echo '  4 - Desktop / Developer''s Machine'
\echo 'Type your choice and press <Enter>: '
\prompt postgres_dba_t1_instance_type

select :postgres_dba_t1_instance_type = 1 as postgres_dba_t1_instance_type_oltp \gset
select :postgres_dba_t1_instance_type = 2 as postgres_dba_t1_instance_type_analytics \gset
select :postgres_dba_t1_instance_type = 3 as postgres_dba_t1_instance_type_mixed \gset
select :postgres_dba_t1_instance_type = 4 as postgres_dba_t1_instance_type_desktop \gset

\echo
\echo
\echo 'Where is the instance located?'
\echo '  1 – On-premise'
\echo '  2 – Amazon EC2'
\echo '  3 – Amazon RDS'
\echo 'Type your choice and press <Enter>: '
\prompt postgres_dba_t1_location

select :postgres_dba_t1_location = 1 as postgres_dba_t1_location_onpremise \gset
select :postgres_dba_t1_location = 2 as postgres_dba_t1_location_ec2 \gset
select :postgres_dba_t1_location = 3 as postgres_dba_t1_location_rds \gset

\echo
\echo

\if :postgres_dba_t1_location_onpremise
-- More questions to get number of CPU cores, RAM, disks
\echo 'Type number of CPU cores: '
\prompt postgres_dba_t1_cpu

\echo
\echo
\echo 'Type total available memory (in GB): '
\prompt postgres_dba_t1_memory

\echo
\echo
\echo 'Hard drive type?'
\echo '  1 - HDD storage'
\echo '  2 - SSD storage'
\echo 'Type your choice and press <Enter>: '
\prompt postgres_dba_t1_location

\elif :postgres_dba_t1_location_ec2
-- CPU/memory/disk is known (AWS EC2)
\elif :postgres_dba_t1_location_rds
-- CPU/memory/disk is known (AWS RDS)
\else
\echo Error! Impossible option.
\set postgres_dba_t1_error true
\endif

\endif

\if :postgres_dba_t1_error
\echo You put incorrect input, cannot proceed with this report. Press <Enter> to return to the menu
\prompt
\else
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
order by category, name;
\endif

--Extensions installed in current DB

select
  ae.name,
  installed_version,
  default_version,
  case when installed_version <> default_version then 'OLD' end as is_old
from pg_extension e
join pg_available_extensions ae on extname = ae.name
order by ae.name;

-- Create materialized view to cache timezone names
CREATE OR REPLACE FUNCTION create_timezone_cache() RETURNS void AS $$
BEGIN
  -- Create materialized view to cache timezone names
  CREATE MATERIALIZED VIEW IF NOT EXISTS public.mv_pg_timezone_names AS
  SELECT name
  FROM pg_timezone_names;

  -- Create index to optimize timezone name lookups
  CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_pg_timezone_names_name ON public.mv_pg_timezone_names (name);
  
  RAISE NOTICE 'Created timezone names cache. To refresh: REFRESH MATERIALIZED VIEW public.mv_pg_timezone_names;';
END;
$$ LANGUAGE plpgsql;

SELECT create_timezone_cache();

-- Usage note:
-- Instead of using the slow query: SELECT name FROM pg_timezone_names
-- Use the cached version:          SELECT name FROM public.mv_pg_timezone_names

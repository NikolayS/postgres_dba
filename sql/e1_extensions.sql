--Extensions installed in current DB

select
  ae.name,
  installed_version,
  default_version,
  case when installed_version <> default_version then 'OLD' end as is_old
from pg_extension e
join pg_available_extensions ae on extname = ae.name
order by ae.name;

-- Create timezone_names materialized view (if it doesn't exist)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_matviews WHERE schemaname = 'public' AND matviewname = 'timezone_names_mv'
    ) THEN
        EXECUTE 'CREATE MATERIALIZED VIEW public.timezone_names_mv AS SELECT name FROM pg_timezone_names';
        EXECUTE 'CREATE INDEX idx_timezone_names_mv_name ON public.timezone_names_mv (name)';
    END IF;
END
$$;
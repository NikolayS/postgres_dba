--Extensions installed in current DB

select
  ae.name,
  installed_version,
  default_version,
  case when installed_version <> default_version then 'OLD' end as is_old
from pg_extension e
join pg_available_extensions ae on extname = ae.name
order by ae.name;

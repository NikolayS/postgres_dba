--List of extensions installed in the current DB

select
  ae.name,
  installed_version,
  default_version,
  extversion as available_version,
  case when installed_version <> extversion then 'OLD' end as actuality
from pg_extension e
join pg_available_extensions ae on extname = ae.name
order by ae.name;

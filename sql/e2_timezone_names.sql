--Timezone names with grouping and data useful for application display

with timezones as (
  select
    name,
    abbrev,
    utc_offset,
    is_dst,
    -- Extract the region/city structure from timezone names
    split_part(name, '/', 1) as region,
    case
      when position('/' in name) > 0 then split_part(name, '/', 2)
      else null
    end as city,
    -- Calculate UTC offset in hours for display
    extract(hours from utc_offset) + 
    extract(minutes from utc_offset)::float/60 as utc_offset_hours
  from pg_timezone_names
  -- Filter out posix timezones that duplicate regular timezone names
  where name not like 'posix/%' 
    and name not like 'Etc/%'
    -- Filtering is important for performance and to remove redundant data
),
timezone_stats as (
  select count(*) as total_count from timezones
)
select
  name,
  abbrev,
  utc_offset,
  utc_offset_hours,
  region,
  city,
  is_dst
from timezones
order by region, city nulls last, name;
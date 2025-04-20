--Timezone names information: lists available timezones with useful information

with tzdata as (
  select 
    name,
    abbrev,
    utc_offset,
    is_dst,
    row_number() over (partition by name order by is_dst desc) as rn
  from pg_timezone_names
),
timezone_stats as (
  select
    count(*) as total_count,
    count(distinct name) as unique_timezones,
    count(distinct abbrev) as unique_abbreviations,
    count(distinct utc_offset) as unique_offsets,
    sum(case when is_dst then 1 else 0 end) as dst_count
  from pg_timezone_names
),
timezones_categorized as (
  select
    substring(name from '^([^/]*)') as category,
    count(*) as count
  from tzdata
  where rn = 1  -- Take only one row per timezone name
  group by category
  order by count desc
)
select 'Timezone Statistics' as "Category", null as "Timezone Name", 
  null as "Abbreviation", null as "UTC Offset", null as "DST?" 
union all
select 
  'Total Timezones:', total_count::text, null, null, null
from timezone_stats
union all
select 
  'Unique Timezones:', unique_timezones::text, null, null, null
from timezone_stats
union all
select 
  'Unique Abbreviations:', unique_abbreviations::text, null, null, null
from timezone_stats
union all
select 
  'Unique UTC Offsets:', unique_offsets::text, null, null, null
from timezone_stats
union all
select 
  'DST Timezones:', dst_count::text, null, null, null
from timezone_stats
union all
select '-------------------', null, null, null, null
union all
select 'Categories (by region)', null, null, null, null
union all
select 
  ' - ' || coalesce(category, 'Other'), count::text, null, null, null
from timezones_categorized
union all
select '-------------------', null, null, null, null
union all
select 'Most Common Timezones', null, null, null, null
union all
select
  null,
  name, 
  abbrev, 
  utc_offset::text, 
  case when is_dst then 'Yes' else 'No' end
from (
  select *
  from tzdata
  where rn = 1  -- Take only one row per timezone name
  order by 
    name not like 'Etc/%', -- Prioritize non-Etc timezones
    name not like 'posix/%', -- Deprioritize posix timezones
    name not like 'right/%', -- Deprioritize right timezones  
    name
  limit 50
) t;
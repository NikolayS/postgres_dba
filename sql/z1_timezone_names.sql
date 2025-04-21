--Timezone names with optimized access in PostgreSQL

with timezone_data as (
  select
    name,
    abbrev,
    utc_offset,
    is_dst
  from pg_timezone_names
  order by name
),
timezone_stats as (
  select
    count(*) as total_timezones,
    count(distinct abbrev) as unique_abbreviations,
    count(distinct utc_offset) as unique_offsets,
    sum(case when is_dst then 1 else 0 end) as dst_zones_count
  from timezone_data
)
select
  'Available Timezones' as metric,
  total_timezones::text as value
from timezone_stats
union all
select
  'Unique Abbreviations',
  unique_abbreviations::text
from timezone_stats
union all
select
  'Unique UTC Offsets',
  unique_offsets::text
from timezone_stats
union all
select
  'DST Zones Count',
  dst_zones_count::text
from timezone_stats
union all
select repeat('-', 33), repeat('-', 88)
union all
-- Common timezone categories by region
select
  'Region: ' || region as metric,
  count(*)::text || ' timezones' as value
from (
  select
    case
      when name like 'Africa/%' then 'Africa'
      when name like 'America/%' then 'America'
      when name like 'Antarctica/%' then 'Antarctica'
      when name like 'Asia/%' then 'Asia'
      when name like 'Atlantic/%' then 'Atlantic'
      when name like 'Australia/%' then 'Australia'
      when name like 'Europe/%' then 'Europe'
      when name like 'Indian/%' then 'Indian'
      when name like 'Pacific/%' then 'Pacific'
      else 'Other'
    end as region
  from timezone_data
) t
group by region
order by region
union all
select repeat('-', 33), repeat('-', 88)
union all
-- Search function for timezones
select
  'Search Function',
  'Use: SELECT * FROM pg_timezone_names WHERE name ILIKE ''%search_term%'' ORDER BY name;'
union all
select repeat('-', 33), repeat('-', 88)
union all
-- Most used timezone info
select
  'Common Timezones',
  string_agg(name || ' (' || abbrev || ', UTC' || 
    case
      when utc_offset >= '00:00:00'::interval then '+'
      else ''
    end ||
    to_char(utc_offset, 'HH24:MI') || ')', E'\n')
from (
  select name, abbrev, utc_offset
  from timezone_data
  where name in (
    'UTC', 'America/New_York', 'America/Los_Angeles', 'Europe/London',
    'Europe/Paris', 'Asia/Tokyo', 'Australia/Sydney', 'Asia/Shanghai'
  )
  order by name
) t
union all
select repeat('-', 33), repeat('-', 88)
union all
-- Practical usage examples
select
  'Current Timezone Settings',
  'Server timezone: ' || current_setting('timezone') ||
  E'\nSession timezone: ' || current_setting('timezone')
union all
select
  'Change Session Timezone',
  'SET timezone = ''desired_timezone'';'
union all
select
  'Convert Timestamps Example',
  'SELECT now() AT TIME ZONE ''UTC'' AT TIME ZONE ''America/New_York'' AS ny_time;'
;
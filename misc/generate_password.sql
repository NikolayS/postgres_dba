with init(len, arr) as (
  -- edit password length and possible characters here
  select 32, string_to_array('123456789abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ~@#$%', null)
), arrlen(l) as (
  select count(*)
  from (select unnest(arr) from init) _
), indexes(i) as (
  select 1 + int4(random() * (l - 1))
  from arrlen, (select generate_series(1, len) from init) _
)
select array_to_string(array_agg(arr[i]), '') as password
from init, indexes
;


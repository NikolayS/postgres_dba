-- WARNING: random() that is used here is not cryptographically strong – 
-- if an attacker knows one value, it's easy to guess the "next" value
-- TODO: rework to use pgcrypto instead

with init(len, arr) as (
  -- edit password length and possible characters here
  select 16, string_to_array('123456789abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ', null)
), arrlen(l) as (
  select count(*)
  from (select unnest(arr) from init) _
), indexes(i) as (
  select 1 + int4(random() * (l - 1))
  from arrlen, (select generate_series(1, len) from init) _
), res as (
  select array_to_string(array_agg(arr[i]), '') as password
  from init, indexes
)
select password--, 'md5' || md5(password || current_setting('postgres_dba.username')::text) as password_md5
from res
;

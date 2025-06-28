-- This script uses pgcrypto extension to generate cryptographically secure random passwords
-- You need to enable the pgcrypto extension first with: CREATE EXTENSION IF NOT EXISTS pgcrypto;

with init(len, arr) as (
  -- edit password length and possible characters here
  select 16, string_to_array('123456789abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ', null)
), arrlen(l) as (
  select count(*)
  from (select unnest(arr) from init) _
), indexes(i) as (
  -- Using gen_random_bytes from pgcrypto for cryptographically secure randomness
  select 1 + (get_byte(gen_random_bytes(1), 0)::int % (l - 1))
  from arrlen, (select generate_series(1, len) from init) _
), res as (
  select array_to_string(array_agg(arr[i]), '') as password
  from init, indexes
)
select password--, 'md5' || md5(password || {{username}}) as password_md5
from res
;

-- Corruption: quick index check — btree + GIN (PG18+). Safe for production, fast.
-- Requires: CREATE EXTENSION amcheck
-- All checks use AccessShareLock only — no write blocking.
-- Checks page-level consistency of btree indexes (bt_index_check).
-- On PG18+, also checks GIN indexes (gin_index_check).

do $$
declare
  rec record;
  idx_count int := 0;
  err_count int := 0;
  skip_count int := 0;
  gin_count int := 0;
  gin_err_count int := 0;
  gin_skip_count int := 0;
  pg_version int;
begin
  if not exists (select 1 from pg_extension where extname = 'amcheck') then
    raise notice '❌ amcheck extension is not installed. Run: CREATE EXTENSION amcheck;';
    return;
  end if;

  select current_setting('server_version_num')::int into pg_version;

  -- === B-tree indexes ===
  raise notice '';
  raise notice '=== B-tree index check (bt_index_check, AccessShareLock) ===';
  raise notice '';

  for rec in
    select
      n.nspname as schema_name,
      c.relname as index_name,
      t.relname as table_name,
      c.oid as index_oid
    from pg_index i
    join pg_class c on c.oid = i.indexrelid
    join pg_class t on t.oid = i.indrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_am a on a.oid = c.relam
    where a.amname = 'btree'
      and c.relpersistence != 't'
      and i.indisvalid
    order by n.nspname, t.relname, c.relname
  loop
    begin
      perform bt_index_check(rec.index_oid);
      idx_count := idx_count + 1;
    exception
      when insufficient_privilege then
        skip_count := skip_count + 1;
      when others then
        raise warning '❌ CORRUPTION in %.%: %',
          rec.schema_name, rec.index_name, sqlerrm;
        err_count := err_count + 1;
    end;
  end loop;

  if err_count = 0 and skip_count = 0 then
    raise notice '✅ All % btree indexes OK.', idx_count;
  elsif err_count = 0 then
    raise notice '✅ % btree indexes OK, % skipped (insufficient privileges).', idx_count, skip_count;
  else
    raise warning '❌ % of % btree indexes have corruption!', err_count, idx_count + err_count + skip_count;
  end if;

  -- === GIN indexes (PG18+) ===
  if pg_version >= 180000 then
    raise notice '';
    raise notice '=== GIN index check (gin_index_check, AccessShareLock) ===';
    raise notice '';

    for rec in
      select
        n.nspname as schema_name,
        c.relname as index_name,
        t.relname as table_name,
        c.oid as index_oid
      from pg_index i
      join pg_class c on c.oid = i.indexrelid
      join pg_class t on t.oid = i.indrelid
      join pg_namespace n on n.oid = c.relnamespace
      join pg_am a on a.oid = c.relam
      where a.amname = 'gin'
        and c.relpersistence != 't'
        and i.indisvalid
      order by n.nspname, t.relname, c.relname
    loop
      begin
        perform gin_index_check(rec.index_oid);
        gin_count := gin_count + 1;
      exception
        when insufficient_privilege then
          gin_skip_count := gin_skip_count + 1;
        when others then
          raise warning '❌ CORRUPTION in %.%: %',
            rec.schema_name, rec.index_name, sqlerrm;
          gin_err_count := gin_err_count + 1;
      end;
    end loop;

    if gin_count + gin_err_count + gin_skip_count = 0 then
      raise notice 'No GIN indexes found.';
    elsif gin_err_count = 0 and gin_skip_count = 0 then
      raise notice '✅ All % GIN indexes OK.', gin_count;
    elsif gin_err_count = 0 then
      raise notice '✅ % GIN indexes OK, % skipped (insufficient privileges).', gin_count, gin_skip_count;
    else
      raise warning '❌ % of % GIN indexes have corruption!', gin_err_count, gin_count + gin_err_count + gin_skip_count;
    end if;
  else
    raise notice '';
    raise notice 'ℹ️  GIN index checking requires PostgreSQL 18+. Skipped.';
  end if;
end;
$$;

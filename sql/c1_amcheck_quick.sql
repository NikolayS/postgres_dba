-- Corruption: quick check — btree, GIN (PG18+), heap (PG14+). Safe for production.
-- Requires: CREATE EXTENSION amcheck
-- All checks use AccessShareLock only (same as SELECT) — no write blocking.
-- Checks page-level consistency of btree indexes (bt_index_check).
-- On PG18+, also checks GIN indexes (gin_index_check).
-- On PG14+, also checks heap and TOAST integrity (verify_heapam).

do $$
declare
  rec record;
  corruption record;
  idx_count int := 0;
  err_count int := 0;
  skip_count int := 0;
  gin_count int := 0;
  gin_err_count int := 0;
  gin_skip_count int := 0;
  tbl_count int := 0;
  tbl_err_count int := 0;
  tbl_skip_count int := 0;
  has_errors boolean;
  pg_version int;
begin
  -- Check extension
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

  -- === Heap verification (PG14+) ===
  if pg_version >= 140000 then
    raise notice '';
    raise notice '=== Heap check (verify_heapam, AccessShareLock) ===';
    raise notice '';

    for rec in
      select
        n.nspname as schema_name,
        c.relname as table_name,
        c.oid as table_oid
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where c.relkind = 'r'
        and c.relpersistence != 't'
      order by n.nspname, c.relname
    loop
      has_errors := false;
      begin
        for corruption in
          select * from verify_heapam(rec.table_oid, check_toast := true)
        loop
          if not has_errors then
            raise warning '❌ CORRUPTION in %.%:', rec.schema_name, rec.table_name;
            has_errors := true;
            tbl_err_count := tbl_err_count + 1;
          end if;
          raise warning '  block %, offset %, attnum %: %',
            corruption.blkno, corruption.offnum, corruption.attnum, corruption.msg;
        end loop;
      exception
        when insufficient_privilege then
          tbl_skip_count := tbl_skip_count + 1;
        when others then
          raise warning 'ERROR checking %.%: %', rec.schema_name, rec.table_name, sqlerrm;
          tbl_err_count := tbl_err_count + 1;
      end;
      tbl_count := tbl_count + 1;
    end loop;

    if tbl_err_count = 0 and tbl_skip_count = 0 then
      raise notice '✅ All % tables passed heap check.', tbl_count;
    elsif tbl_err_count = 0 then
      raise notice '✅ % tables OK, % skipped (insufficient privileges).', tbl_count - tbl_skip_count, tbl_skip_count;
    else
      raise warning '❌ % of % tables have corruption!', tbl_err_count, tbl_count;
    end if;
  else
    raise notice '';
    raise notice 'ℹ️  Heap verification (verify_heapam) requires PostgreSQL 14+. Skipped.';
  end if;
end;
$$;

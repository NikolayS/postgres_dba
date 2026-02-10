-- Corruption: FULL check — heapallindexed + parent + heap (⚠️⚠️ SLOW + ShareLock, use on clones)
-- Requires: CREATE EXTENSION amcheck
-- ⚠️⚠️  HEAVY: Takes ShareLock AND scans entire heap for each index!
-- ⚠️⚠️  This WILL be slow on large databases. Use on clones (e.g., restored from backup).
--
-- bt_index_parent_check with heapallindexed=true: verifies that every single
-- heap tuple has a corresponding index entry. Catches silent data loss where
-- rows exist but are invisible to index scans.
-- On PG14+: also verify_heapam with full TOAST checking.

do $$
declare
  rec record;
  corruption record;
  idx_count int := 0;
  err_count int := 0;
  skip_count int := 0;
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

  raise warning '';
  raise warning '⚠️⚠️  WARNING: This is the HEAVIEST corruption check!';
  raise warning '⚠️⚠️  Takes ShareLock on each index (blocks writes) AND scans entire heap.';
  raise warning '⚠️⚠️  On large databases this can take HOURS. Use on clones (e.g., restored from backup).';
  raise warning '';

  -- === Full B-tree check ===
  raise notice '=== Full B-tree check (bt_index_parent_check + heapallindexed, ShareLock) ===';
  raise notice 'Verifies: parent-child ordering, all heap tuples indexed, unique constraints';
  raise notice '';

  for rec in
    select
      n.nspname as schema_name,
      c.relname as index_name,
      t.relname as table_name,
      c.oid as index_oid,
      pg_relation_size(c.oid) as index_size
    from pg_index i
    join pg_class c on c.oid = i.indexrelid
    join pg_class t on t.oid = i.indrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_am a on a.oid = c.relam
    where a.amname = 'btree'
      and c.relpersistence != 't'
      and i.indisvalid
    order by pg_relation_size(c.oid) asc  -- smallest first
  loop
    begin
      if pg_version >= 140000 then
        perform bt_index_parent_check(
          rec.index_oid,
          heapallindexed := true,
          rootdescend := true,
          checkunique := true
        );
      elsif pg_version >= 110000 then
        perform bt_index_parent_check(
          rec.index_oid,
          heapallindexed := true,
          rootdescend := true
        );
      else
        perform bt_index_parent_check(rec.index_oid, heapallindexed := true);
      end if;
      idx_count := idx_count + 1;
    exception
      when insufficient_privilege then
        skip_count := skip_count + 1;
      when others then
        raise warning '❌ CORRUPTION in %.% (table %.%, size %): %',
          rec.schema_name, rec.index_name,
          rec.schema_name, rec.table_name,
          pg_size_pretty(rec.index_size),
          sqlerrm;
        err_count := err_count + 1;
    end;
  end loop;

  if err_count = 0 and skip_count = 0 then
    raise notice '✅ All % btree indexes passed full check.', idx_count;
  elsif err_count = 0 then
    raise notice '✅ % btree indexes OK, % skipped (insufficient privileges).', idx_count, skip_count;
  else
    raise warning '❌ % of % btree indexes have corruption!', err_count, idx_count + err_count + skip_count;
  end if;

  -- === Full heap verification (PG14+) ===
  if pg_version >= 140000 then
    raise notice '';
    raise notice '=== Full heap check (verify_heapam + TOAST, AccessShareLock) ===';
    raise notice '';

    for rec in
      select
        n.nspname as schema_name,
        c.relname as table_name,
        c.oid as table_oid,
        pg_relation_size(c.oid) as table_size
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where c.relkind = 'r'
        and c.relpersistence != 't'
      order by n.nspname, c.relname
    loop
      has_errors := false;
      begin
        for corruption in
          select * from verify_heapam(
            rec.table_oid,
            on_error_stop := false,
            check_toast := true,
            skip := 'none'
          )
        loop
          if not has_errors then
            raise warning '❌ CORRUPTION in %.% (size %):', rec.schema_name, rec.table_name, pg_size_pretty(rec.table_size);
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
      raise notice '✅ All % tables passed full heap check.', tbl_count;
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

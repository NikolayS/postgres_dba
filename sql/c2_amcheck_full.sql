-- Corruption: Full B-tree + heap check (amcheck, takes locks – use on standby!)
-- Requires: CREATE EXTENSION amcheck
-- Uses bt_index_parent_check(heapallindexed := true) — thorough, takes locks.
-- ⚠️  Takes ShareLock on each index. Run on standbys or during maintenance windows.
-- Checks parent-child consistency, sibling pointers, root descent, unique constraints.
-- Verifies all heap tuples have corresponding index entries.
-- On PG14+, also runs verify_heapam() with full TOAST checking.

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

  raise warning '⚠️  This check takes locks! Use on standbys or during maintenance windows.';
  raise notice '';
  raise notice '=== Full B-tree index integrity (bt_index_parent_check + heapallindexed) ===';
  raise notice 'Checking all btree indexes with parent-child + heap verification...';
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
      and n.nspname not in ('pg_catalog', 'information_schema')
      and n.nspname !~ '^pg_toast'
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
        raise notice '⚠️  Permission denied for %.% — need superuser or amcheck privileges', rec.schema_name, rec.index_name;
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
    raise notice '✅ All % btree indexes passed full integrity check.', idx_count;
  elsif err_count = 0 then
    raise notice '✅ % btree indexes passed, % skipped (insufficient privileges).', idx_count, skip_count;
  else
    raise warning '❌ % of % btree indexes have corruption!', err_count, idx_count + err_count + skip_count;
  end if;

  -- Full heap verification (PG14+ only)
  if pg_version >= 140000 then
    raise notice '';
    raise notice '=== Full heap integrity (verify_heapam + TOAST) ===';
    raise notice 'Checking all user tables for heap and TOAST corruption...';
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
        and n.nspname not in ('pg_catalog', 'information_schema')
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
          raise notice '⚠️  Permission denied for %.% — need superuser or amcheck privileges', rec.schema_name, rec.table_name;
          tbl_skip_count := tbl_skip_count + 1;
        when others then
          raise warning 'ERROR checking %.%: %', rec.schema_name, rec.table_name, sqlerrm;
          tbl_err_count := tbl_err_count + 1;
      end;
      tbl_count := tbl_count + 1;
    end loop;

    if tbl_err_count = 0 and tbl_skip_count = 0 then
      raise notice '✅ All % tables passed full heap integrity check.', tbl_count;
    elsif tbl_err_count = 0 then
      raise notice '✅ % tables passed, % skipped (insufficient privileges).', tbl_count - tbl_skip_count, tbl_skip_count;
    else
      raise warning '❌ % of % tables have corruption!', tbl_err_count, tbl_count;
    end if;
  else
    raise notice '';
    raise notice 'ℹ️  Heap verification (verify_heapam) requires PostgreSQL 14+. Skipped.';
  end if;
end;
$$;

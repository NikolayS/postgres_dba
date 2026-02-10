-- Corruption: B-tree parent check — detects glibc/collation corruption (ShareLock, use on clones)
-- Requires: CREATE EXTENSION amcheck
-- ⚠️  Takes ShareLock on each index — blocks writes while checking!
-- ⚠️  Best used on clones (e.g., restored from backup) or standbys.
--
-- Uses bt_index_parent_check() which verifies parent-child key ordering.
-- This is the most reliable way to detect corruption caused by glibc/ICU
-- version changes that silently alter collation sort order.
-- Also checks sibling page pointers and descends from root (rootdescend).
-- On PG14+, also verifies unique constraint consistency (checkunique).

do $$
declare
  rec record;
  idx_count int := 0;
  err_count int := 0;
  skip_count int := 0;
  pg_version int;
begin
  if not exists (select 1 from pg_extension where extname = 'amcheck') then
    raise notice '❌ amcheck extension is not installed. Run: CREATE EXTENSION amcheck;';
    return;
  end if;

  select current_setting('server_version_num')::int into pg_version;

  raise warning '';
  raise warning '⚠️  WARNING: This check takes ShareLock on each index — blocks writes!';
  raise warning '⚠️  Recommended: run on a clone (e.g., restored from backup), standby, or during maintenance.';
  raise warning '';
  raise notice '=== B-tree parent check (bt_index_parent_check, ShareLock) ===';
  raise notice 'Detects: collation/glibc corruption, parent-child inconsistency, sibling pointer errors';
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
    order by pg_relation_size(c.oid) asc
  loop
    begin
      if pg_version >= 140000 then
        perform bt_index_parent_check(
          rec.index_oid,
          heapallindexed := false,
          rootdescend := true,
          checkunique := true
        );
      elsif pg_version >= 110000 then
        perform bt_index_parent_check(
          rec.index_oid,
          heapallindexed := false,
          rootdescend := true
        );
      else
        perform bt_index_parent_check(rec.index_oid);
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
    raise notice '✅ All % btree indexes passed parent check.', idx_count;
  elsif err_count = 0 then
    raise notice '✅ % btree indexes OK, % skipped (insufficient privileges).', idx_count, skip_count;
  else
    raise warning '❌ % of % btree indexes have corruption!', err_count, idx_count + err_count + skip_count;
  end if;
end;
$$;

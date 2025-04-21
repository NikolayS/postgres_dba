-- Use this to do the very 1st REFRESH for your matviews
-- In case when there are complex relations between matviews,
-- it might perform multiple iterations and eventually refreshes
-- all matviews (either all w/o data or absolutely all -- it's up to you).

-- Note: This script also handles the timezone_names_cache materialized view (if exists)
-- which improves performance for timezone name queries

-- set this to TRUE here if you need ALL matviews to be refreshed, not only those that already have been refreshed
set postgres_dba.refresh_matviews_with_data = FALSE;
-- alternatively, you can set 'postgres_dba.refresh_matviews_with_data_forced' to TRUE or FALSE in advance, outside of this script.

set statement_timeout to 0;
set client_min_messages to info;

do $$
declare
  matview text;
  sql text;
  iter int2; -- how many iterations
  done_cnt integer; -- how many matviews refreshed
  curts timestamptz;
begin
  if current_setting('postgres_dba.refresh_matviews_with_data_forced', true)::boolean then
    set postgres_dba.refresh_matviews_with_data = true;
  end if;
  if current_setting('postgres_dba.refresh_matviews_with_data')::boolean then
    raise notice 'Refreshing ALL matviews (run ''set postgres_dba.refresh_matviews_with_data_forced = TRUE;'' to refresh only matviews w/o data).';
    for matview in
      select format('"%s"."%s"', schemaname::text, matviewname::text)
      from pg_matviews
    loop
      sql := format('refresh materialized view %s with no data;', matview);
      raise notice '[%] SQL:    %', '-', sql;
      execute sql;
    end loop;
  else
      raise notice 'Refreshing only matviews w/o data (run ''set postgres_dba.refresh_matviews_with_data_forced = TRUE;'' to refresh all matviews).';
  end if;

  iter := 1;
  done_cnt := 0;
  loop
    for matview in
      select format('"%s"."%s"', schemaname::text, matviewname::text)
      from pg_matviews
      where not ispopulated
    loop
      begin
        sql := format('refresh materialized view %s', matview);
        raise notice '[%] SQL:    %', iter, sql;
        curts := clock_timestamp();
        execute sql;
        raise notice '[%] % refreshed, it took %', iter, matview, (clock_timestamp() - curts)::text;
        done_cnt := done_cnt + 1;
      exception
        when others then
          raise warning '[%] Cannot update view %, skip and try again later.', iter, matview;
      end;
    end loop;

    iter := iter + 1;
    exit when iter > 5 or 0 = (select count(*) from pg_matviews where not ispopulated);
  end loop;

  -- Special handling for timezone_names_cache if it exists
  if exists (
    select 1 from pg_class c 
    join pg_namespace n on n.oid = c.relnamespace 
    where c.relname = 'timezone_names_cache' 
    and n.nspname = 'public' 
    and c.relkind = 'm'
  ) then
    begin
      curts := clock_timestamp();
      raise notice 'Refreshing timezone_names_cache materialized view...';
      execute 'refresh materialized view concurrently public.timezone_names_cache';
      raise notice 'timezone_names_cache refreshed, it took %', (clock_timestamp() - curts)::text;
      done_cnt := done_cnt + 1;
    exception
      when others then
        raise warning 'Failed to refresh timezone_names_cache concurrently, trying non-concurrent refresh';
        begin
          curts := clock_timestamp();
          execute 'refresh materialized view public.timezone_names_cache';
          raise notice 'timezone_names_cache refreshed (non-concurrent), it took %', (clock_timestamp() - curts)::text;
          done_cnt := done_cnt + 1;
        exception
          when others then
            raise warning 'Cannot refresh timezone_names_cache: %', sqlerrm;
        end;
    end;
  end if;
  
  raise notice 'Finished! % matviews refreshed in % iteration(s). It took %', done_cnt, (iter - 1), (clock_timestamp() - now())::text;
end;
$$ language plpgsql;

reset postgres_dba.refresh_matviews_with_data;
reset client_min_messages;
reset statement_timeout;

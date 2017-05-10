-- Use this to do the very 1st REFRESH for your matviews
-- In case when there are complex relations between matviews,
-- it might perform multiple iterations and eventyally refreshes
-- all matviews (either all w/o data or absolutely all -- it's up to you).

-- set thos to TRUE here if you need ALL matviews to be refrehsed, not only those that already have been refreshed
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
  begin
    if current_setting('postgres_dba.refresh_matviews_with_data_forced')::boolean then
      set postgres_dba.refresh_matviews_with_data = true;
    end if;
  exception when others then
    -- nothing
  end;
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

    exit when 0 = (select count(*) from pg_matviews where not ispopulated);
    iter := iter + 1;
  end loop;

  raise notice 'Finished! % matviews refreshed in % iterations. It took %', done_cnt, iter, (clock_timestamp() - now())::text;
end;
$$ language plpgsql;

reset postgres_dba.refresh_matviews_with_data;
reset client_min_messages;
reset statement_timeout;


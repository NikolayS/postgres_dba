--Lock trees (lightweight)

-- Source: https://github.com/dataegret/pg-utils/blob/master/sql/locktree.sql
-- The paths won't be precise but this query is very light and may be used quite frequently

with recursive l as (
  select pid, locktype, granted,
    array_position(array['accessshare','rowshare','rowexclusive','shareupdateexclusive','share','sharerowexclusive','exclusive','accessexclusive'], left(mode,-4)) m,
    row(locktype,database,relation,page,tuple,virtualxid,transactionid,classid,objid,objsubid) obj from pg_locks
), pairs as (
  select w.pid waiter, l.pid locker, l.obj, l.m
    from l w join l on l.obj is not distinct from w.obj and l.locktype=w.locktype and not l.pid=w.pid and l.granted
   where not w.granted
     and not exists ( select from l i where i.pid=l.pid and i.locktype=l.locktype and i.obj is not distinct from l.obj and i.m > l.m )
), leads as (
  select o.locker, 1::int lvl, count(*) q, array[locker] track, false as cycle from pairs o group by o.locker
  union all
  select i.locker, leads.lvl+1, (select count(*) from pairs q where q.locker=i.locker), leads.track||i.locker, i.locker=any(leads.track)
    from pairs i, leads where i.waiter=leads.locker and not cycle
), tree as (
  select locker pid,locker dad,locker root,case when cycle then track end dl, null::record obj,0 lvl,locker::text path,array_agg(locker) over () all_pids from leads o
   where (cycle and not exists (select from leads i where i.locker=any(o.track) and (i.lvl>o.lvl or i.q<o.q)))
      or (not cycle and not exists (select from pairs where waiter=o.locker) and not exists (select from leads i where i.locker=o.locker and i.lvl<o.lvl))
  union all
  select w.waiter pid,tree.pid,tree.root,case when w.waiter=any(tree.dl) then tree.dl end,w.obj,tree.lvl+1,tree.path||'.'||w.waiter,all_pids || array_agg(w.waiter) over ()
    from tree join pairs w on tree.pid=w.locker and not w.waiter = any ( all_pids )
)
select (clock_timestamp() - a.xact_start)::interval(0) as ts_age,
       (clock_timestamp() - a.state_change)::interval(0) as change_age,
       a.datname,a.usename,a.client_addr,
       --w.obj wait_on_object,
       tree.pid,replace(a.state, 'idle in transaction', 'idletx') state,
       lvl,(select count(*) from tree p where p.path ~ ('^'||tree.path) and not p.path=tree.path) blocked,
       case when tree.pid=any(tree.dl) then '!>' else repeat(' .', lvl) end||' '||trim(left(regexp_replace(a.query, e'\\s+', ' ', 'g'),100)) query
  from tree
  left join pairs w on w.waiter=tree.pid and w.locker=tree.dad
  join pg_stat_activity a using (pid)
  join pg_stat_activity r on r.pid=tree.root
 order by (now() - r.xact_start), path;

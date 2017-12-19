select case when pg_is_in_recovery() then 'Replica' || ' (delay: '
    || ((((case
        when pg_last_xlog_receive_location() = pg_last_xlog_replay_location() then 0
        else extract (epoch from now() - pg_last_xact_replay_timestamp())
      end)::int)::text || ' second')::interval)::text
    || '; paused: ' || pg_is_xlog_replay_paused()::text || ')'
  else 'Master'
end as "Node Information";

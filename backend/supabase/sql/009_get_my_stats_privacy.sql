-- `get_my_stats` returned the community total, the number of ranked
-- listeners and the caller's rank even while the community features are
-- still locked. Anyone can create an anonymous session with the public key,
-- so with only one or two real listeners the "community total" was simply
-- their personal listening time. Now these three fields follow the same
-- rule as `public_stats()` (007): zeros / null until `stats_available()`.
-- The listener's own numbers (`total_seconds`, `daily`) are unchanged.
--
-- Run after 008. Replaces `get_my_stats`; safe to re-run.

create or replace function get_my_stats(p_since date default (current_date - 13))
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  cfg stats_config;
  mine bigint;
  is_available boolean;
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select * into cfg from stats_config limit 1;
  select l.total_seconds into mine from listeners l where l.id = uid;
  mine := coalesce(mine, 0);
  is_available := stats_available();

  return jsonb_build_object(
    'available', is_available,
    'total_seconds', mine,
    'community_seconds', case when is_available then
      (select coalesce(sum(l.total_seconds), 0) from listeners l)
      + coalesce((select a.seconds from community_archive a limit 1), 0)
      else 0 end,
    'ranked_listeners', case when is_available then
      (select count(*) from listeners l where l.total_seconds >= cfg.min_listener_seconds)
      else 0 end,
    'rank', case
      when is_available and mine >= cfg.min_listener_seconds
        then 1 + (select count(*) from listeners l where l.total_seconds > mine)
      else null
    end,
    'daily', coalesce(
      (select jsonb_agg(jsonb_build_object('day', d.day, 'show_id', d.show_id, 'seconds', d.seconds) order by d.day, d.show_id)
       from listening_daily d
       where d.listener_id = uid and d.day >= p_since),
      '[]'::jsonb
    )
  );
end;
$$;

revoke all on function get_my_stats(date) from public, anon, authenticated;
grant execute on function get_my_stats(date) to authenticated;

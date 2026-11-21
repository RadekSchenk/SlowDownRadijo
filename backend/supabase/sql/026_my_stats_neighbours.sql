-- `get_my_stats` for the new Statistiky (app 1.3, Figma "Explorace 1.3",
-- S1): besides the rank, the listening time of the places right around it
-- (shown as neighbours, not as a race), and how many days the caller has
-- listened. All anonymous: times only, never who holds a place.
--
--   * ahead_seconds  – total of the next place up (null at #1)
--   * behind_seconds – total of the next place down (null when last)
--   * listening_days – days with any listening (listening_daily)
--
-- Everything else as in 017. Run after 025. Replaces `get_my_stats`; safe
-- to re-run.

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
  my_rank bigint;
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select * into cfg from stats_config limit 1;
  select l.total_seconds into mine from listeners l where l.id = uid;
  mine := coalesce(mine, 0);
  is_available := stats_available();
  my_rank := case
    when is_available and mine >= cfg.min_listener_seconds
      then 1 + (select count(*) from listeners l where l.total_seconds > mine)
    else null
  end;

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
    'rank', my_rank,
    'ahead_seconds', case when my_rank > 1 then
      (select min(l.total_seconds) from listeners l where l.total_seconds > mine) end,
    'behind_seconds', case when my_rank is not null then
      (select max(l.total_seconds) from listeners l
       where l.total_seconds < mine and l.total_seconds >= cfg.min_listener_seconds) end,
    'listening_days',
      (select count(distinct d.day) from listening_daily d where d.listener_id = uid and d.seconds > 0),
    'daily', coalesce(
      (select jsonb_agg(jsonb_build_object('day', d.day, 'show_id', d.show_id, 'seconds', d.seconds) order by d.day, d.show_id)
       from listening_daily d
       where d.listener_id = uid and d.day >= p_since),
      '[]'::jsonb
    ),
    'shows', coalesce(
      (select jsonb_agg(jsonb_build_object('show_id', s.show_id, 'seconds', s.seconds) order by s.seconds desc)
       from (
         select d.show_id, sum(d.seconds) as seconds
         from listening_daily d
         where d.listener_id = uid
         group by d.show_id
       ) s),
      '[]'::jsonb
    )
  );
end;
$$;

revoke all on function get_my_stats(date) from public, anon, authenticated;
grant execute on function get_my_stats(date) to authenticated;

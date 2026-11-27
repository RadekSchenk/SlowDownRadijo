-- Statistiky 1.4 (Figma "Statistiky 1.4"): the leaderboard for this week
-- and this month besides all time, the listener's run of days, and how
-- last week went. `get_my_stats` keeps every key it had (1.3 and older
-- read those) and adds:
--
--   * periods.week / periods.month / periods.all:
--       seconds           – the caller's listening in the period
--       previous_seconds  – in the period before (week and month)
--       rank              – null unless the caller has 10 min in the period
--                           AND at least `min_period_listeners` listeners
--                           do (few listeners: "#2 of 8" looks bad, so the
--                           app shows the listener's own time instead)
--       ranked            – how many are ranked (for the TOP % label only;
--                           the app never shows the number)
--       open              – the period has enough listeners to rank: then a
--                           listener short of 10 min is told how much is left
--       ahead_seconds / behind_seconds – the places right around
--   * last_week: { seconds, rank } – rank as above
--   * streak_days, streak_through – consecutive days with listening that
--     end today or yesterday, and the last of them
--
-- Weeks run Monday to Sunday and months by the calendar, in Prague time.
-- `listening_daily.day` is the listener's own day, which for this app's
-- listeners is Prague's. Run after 028; safe to re-run.

alter table stats_config
  add column if not exists min_period_listeners integer not null default 30;

-- One period's ranking for `uid`: [p_from, p_to] inclusive; previous
-- period from p_previous_from up to p_from (exclusive), when given.
create or replace function period_rank(uid uuid, p_from date, p_to date, p_previous_from date default null)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with cfg as (
    select * from stats_config limit 1
  ), totals as (
    select d.listener_id, sum(d.seconds) as seconds
    from listening_daily d
    where d.day between p_from and p_to
    group by d.listener_id
  ), me as (
    select coalesce((select t.seconds from totals t where t.listener_id = uid), 0) as seconds
  ), counted as (
    select count(*) as ranked from totals t, cfg where t.seconds >= cfg.min_listener_seconds
  ), placed as (
    select case
      when stats_available() and me.seconds >= cfg.min_listener_seconds and counted.ranked >= cfg.min_period_listeners
        then 1 + (select count(*) from totals t where t.seconds > me.seconds)
    end as rank
    from me, cfg, counted
  )
  select jsonb_build_object(
    'seconds', me.seconds,
    'previous_seconds', case when p_previous_from is not null then
      (select coalesce(sum(d.seconds), 0) from listening_daily d
       where d.listener_id = uid and d.day >= p_previous_from and d.day < p_from) end,
    'rank', placed.rank,
    'ranked', case when placed.rank is not null then counted.ranked end,
    'open', stats_available() and counted.ranked >= (select c.min_period_listeners from cfg c),
    'ahead_seconds', case when placed.rank > 1 then
      (select min(t.seconds) from totals t where t.seconds > me.seconds) end,
    'behind_seconds', case when placed.rank is not null then
      (select max(t.seconds) from totals t, cfg
       where t.seconds < me.seconds and t.seconds >= cfg.min_listener_seconds) end
  )
  from me, counted, placed;
$$;

revoke all on function period_rank(uuid, date, date, date) from public, anon, authenticated;

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
  all_ranked bigint;
  today date := (now() at time zone 'Europe/Prague')::date;
  week_start date := date_trunc('week', (now() at time zone 'Europe/Prague'))::date;
  month_start date := date_trunc('month', (now() at time zone 'Europe/Prague'))::date;
  last_week jsonb;
  streak integer := 0;
  streak_end date;
  d date;
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select * into cfg from stats_config limit 1;
  select l.total_seconds into mine from listeners l where l.id = uid;
  mine := coalesce(mine, 0);
  is_available := stats_available();
  all_ranked := (select count(*) from listeners l where l.total_seconds >= cfg.min_listener_seconds);
  my_rank := case
    when is_available and mine >= cfg.min_listener_seconds
      then 1 + (select count(*) from listeners l where l.total_seconds > mine)
    else null
  end;

  -- Days in a row: from today, or from yesterday when today has nothing yet.
  select max(x.day) into streak_end
  from listening_daily x
  where x.listener_id = uid and x.seconds > 0 and x.day in (today, today - 1);
  if streak_end is not null then
    d := streak_end;
    while exists (select 1 from listening_daily x where x.listener_id = uid and x.day = d and x.seconds > 0) loop
      streak := streak + 1;
      d := d - 1;
    end loop;
  end if;

  last_week := period_rank(uid, week_start - 7, week_start - 1);

  return jsonb_build_object(
    'available', is_available,
    'total_seconds', mine,
    'community_seconds', case when is_available then
      (select coalesce(sum(l.total_seconds), 0) from listeners l)
      + coalesce((select a.seconds from community_archive a limit 1), 0)
      else 0 end,
    'ranked_listeners', case when is_available then all_ranked else 0 end,
    'rank', my_rank,
    'ahead_seconds', case when my_rank > 1 then
      (select min(l.total_seconds) from listeners l where l.total_seconds > mine) end,
    'behind_seconds', case when my_rank is not null then
      (select max(l.total_seconds) from listeners l
       where l.total_seconds < mine and l.total_seconds >= cfg.min_listener_seconds) end,
    'listening_days',
      (select count(distinct x.day) from listening_daily x where x.listener_id = uid and x.seconds > 0),
    'daily', coalesce(
      (select jsonb_agg(jsonb_build_object('day', x.day, 'show_id', x.show_id, 'seconds', x.seconds) order by x.day, x.show_id)
       from listening_daily x
       where x.listener_id = uid and x.day >= p_since),
      '[]'::jsonb
    ),
    'shows', coalesce(
      (select jsonb_agg(jsonb_build_object('show_id', s.show_id, 'seconds', s.seconds) order by s.seconds desc)
       from (
         select x.show_id, sum(x.seconds) as seconds
         from listening_daily x
         where x.listener_id = uid
         group by x.show_id
       ) s),
      '[]'::jsonb
    ),
    'periods', jsonb_build_object(
      'week', period_rank(uid, week_start, today, week_start - 7),
      'month', period_rank(uid, month_start, today, (month_start - interval '1 month')::date),
      'all', jsonb_build_object(
        'seconds', mine,
        'rank', case when all_ranked >= cfg.min_period_listeners then my_rank end,
        'open', is_available and all_ranked >= cfg.min_period_listeners,
        'ranked', case when all_ranked >= cfg.min_period_listeners and my_rank is not null then all_ranked end,
        'ahead_seconds', case when all_ranked >= cfg.min_period_listeners and my_rank > 1 then
          (select min(l.total_seconds) from listeners l where l.total_seconds > mine) end,
        'behind_seconds', case when all_ranked >= cfg.min_period_listeners and my_rank is not null then
          (select max(l.total_seconds) from listeners l
           where l.total_seconds < mine and l.total_seconds >= cfg.min_listener_seconds) end
      )
    ),
    'last_week', jsonb_build_object('seconds', last_week -> 'seconds', 'rank', last_week -> 'rank'),
    'streak_days', streak,
    'streak_through', streak_end
  );
end;
$$;

revoke all on function get_my_stats(date) from public, anon, authenticated;
grant execute on function get_my_stats(date) to authenticated;

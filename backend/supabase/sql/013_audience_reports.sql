-- Audience reports: how many people listen, how much, and how often —
-- read straight from the listening stats (005), so they cover every
-- listener with stats on, not only those who said yes to analytics.
--
-- Everything lives in its own `reports` schema, which the API does not
-- expose and the app roles cannot read: open them in the Supabase SQL
-- Editor, e.g. `select * from reports.monthly_listeners;`.
--
-- Definitions
-- * Active on a day: at least 60 s of listening that day (the same bar as
--   `stats_config.min_listener_seconds`, so a stray tap doesn't count).
-- * Days are the listener's own calendar days; weeks start on Monday.
-- * Monthly segments, per listener and calendar month:
--     occasional — active on 1 day,
--     regular    — 2–7 days,
--     loyal      — 8+ days, or 10+ hours in the month whatever the days.
-- * Listeners who deleted their stats in the app are gone from these
--   numbers too (their rows are deleted, not archived).

create schema if not exists reports;
revoke all on schema reports from public, anon, authenticated;

-- One row per listener and active day.
create or replace view reports.active_days
with (security_invoker = on) as
select listener_id, day, sum(seconds)::bigint as seconds
from public.listening_daily
group by listener_id, day
having sum(seconds) >= 60;

-- Daily: listeners, time, average per listener.
create or replace view reports.daily_listeners
with (security_invoker = on) as
select
  day,
  count(*) as listeners,
  round(sum(seconds) / 3600.0, 1) as total_hours,
  round(avg(seconds) / 60.0, 1) as avg_minutes_per_listener
from reports.active_days
group by day
order by day desc;

-- Weekly: unique listeners, how many days they come back, time.
create or replace view reports.weekly_listeners
with (security_invoker = on) as
with per_listener as (
  select date_trunc('week', day)::date as week, listener_id,
         count(*) as days, sum(seconds) as seconds
  from reports.active_days
  group by 1, 2
)
select
  week,
  count(*) as listeners,
  round(sum(seconds) / 3600.0, 1) as total_hours,
  round(avg(seconds) / 60.0, 1) as avg_minutes_per_listener,
  round(avg(days), 2) as avg_days_per_listener,
  round(sum(days) / 7.0, 1) as avg_daily_listeners
from per_listener
group by week
order by week desc;

-- Monthly: unique listeners, daily average, stickiness (daily / monthly).
create or replace view reports.monthly_listeners
with (security_invoker = on) as
with per_listener as (
  select date_trunc('month', day)::date as month, listener_id,
         count(*) as days, sum(seconds) as seconds
  from reports.active_days
  group by 1, 2
),
months as (
  select month,
         count(*) as listeners,
         sum(seconds) as seconds,
         avg(seconds) as avg_seconds,
         avg(days) as avg_days,
         sum(days) as listener_days
  from per_listener
  group by month
)
select
  month,
  listeners,
  round(seconds / 3600.0, 1) as total_hours,
  round(avg_seconds / 60.0, 1) as avg_minutes_per_listener,
  round(avg_days, 2) as avg_days_per_listener,
  -- Average over the days of the month so far (a running month counts
  -- only the days up to today).
  round(listener_days::numeric / greatest(1, least(
    (month + interval '1 month')::date, current_date + 1) - month), 1) as avg_daily_listeners,
  round(100.0 * listener_days / greatest(1, least(
    (month + interval '1 month')::date, current_date + 1) - month) / listeners, 1) as stickiness_pct
from months
order by month desc;

-- Monthly segments: occasional → regular → loyal.
create or replace view reports.monthly_segments
with (security_invoker = on) as
with per_listener as (
  select date_trunc('month', day)::date as month, listener_id,
         count(*) as days, sum(seconds) as seconds
  from reports.active_days
  group by 1, 2
),
segmented as (
  select month, days, seconds,
         case
           when days >= 8 or seconds >= 36000 then 'loyal'
           when days >= 2 then 'regular'
           else 'occasional'
         end as segment
  from per_listener
)
select
  month,
  segment,
  count(*) as listeners,
  round(100.0 * count(*) / sum(count(*)) over (partition by month), 1) as share_pct,
  round(sum(seconds) / 3600.0, 1) as total_hours,
  round(100.0 * sum(seconds) / sum(sum(seconds)) over (partition by month), 1) as hours_share_pct,
  round(avg(seconds) / 60.0, 1) as avg_minutes_per_listener,
  round(avg(days), 1) as avg_days
from segmented
group by month, segment
order by month desc,
  case segment when 'loyal' then 1 when 'regular' then 2 else 3 end;

-- Monthly listening per show.
create or replace view reports.show_listening
with (security_invoker = on) as
select
  date_trunc('month', day)::date as month,
  show_id,
  count(distinct listener_id) as listeners,
  round(sum(seconds) / 3600.0, 1) as total_hours,
  round(sum(seconds) / 60.0 / count(distinct listener_id), 1) as avg_minutes_per_listener
from public.listening_daily
where seconds > 0
group by 1, 2
order by month desc, total_hours desc;

-- All time, one row.
create or replace view reports.overview
with (security_invoker = on) as
with per_listener as (
  select listener_id, min(day) as first_day, max(day) as last_day,
         count(*) as days, sum(seconds) as seconds
  from reports.active_days
  group by listener_id
)
select
  count(*) as listeners,
  round(coalesce(sum(seconds), 0) / 3600.0, 1) as total_hours,
  round(avg(seconds) / 60.0, 1) as avg_minutes_per_listener,
  round(avg(days), 1) as avg_active_days,
  count(*) filter (where first_day > current_date - 30) as new_last_30_days,
  count(*) filter (where last_day > current_date - 30) as active_last_30_days,
  count(*) filter (where last_day > current_date - 7) as active_last_7_days
from per_listener;

revoke all on all tables in schema reports from public, anon, authenticated;

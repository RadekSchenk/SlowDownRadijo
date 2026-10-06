-- Per-listener listening stats ("Statistiky" tab): how long each anonymous
-- listener has the radio on, broken down by day and by show, plus a
-- community-wide total and a leaderboard rank.
--
-- Identity is a Supabase *anonymous* auth user created by the app on the
-- first real listen (no e-mail, no name). `listeners.id` is that user's id,
-- so when registration arrives later the same id is simply upgraded to a
-- permanent account and every stat stays attached to it.
--
-- Prerequisite: Dashboard → Authentication → Sign In / Providers →
-- enable "Allow anonymous sign-ins".
--
-- Run once in the SQL Editor (https://supabase.com/dashboard/project/_/sql/new).
-- Safe to re-run: everything is `if not exists` / `create or replace`.
--
-- Data minimisation: no timestamps of individual listening sessions, no IP,
-- no device model — only seconds per (local day, show). The app sends
-- batches; `listening_batches` makes a retried batch idempotent. (These tables
-- hold no IP address; Supabase's own auth/request logs may, see PRIVACY_POLICY.md.)
--
-- Nothing here is readable or writable directly by clients: row level
-- security is on without policies, and every access goes through the
-- security-definer functions at the bottom, each of which only ever touches
-- the caller's own rows (`auth.uid()`).

create table if not exists listeners (
  id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  first_play_at timestamptz,
  last_seen_at timestamptz,
  total_seconds bigint not null default 0 check (total_seconds >= 0),
  app_version text
);

-- Leaderboard rank = count of listeners with strictly more seconds.
create index if not exists listeners_total_seconds_idx on listeners (total_seconds desc);

create table if not exists listening_daily (
  listener_id uuid not null references listeners (id) on delete cascade,
  -- The listener's own calendar day (device time zone), as sent by the app.
  day date not null,
  -- `Show.id` from schedule.json; the app attributes time to the show that
  -- was airing at that moment, so the server never needs the schedule.
  show_id text not null,
  seconds integer not null check (seconds >= 0),
  primary key (listener_id, day, show_id)
);

-- Remembers which batches were already applied so a retry after a lost
-- response doesn't count the same minutes twice. Old rows are useless after
-- a few days (see the optional cleanup at the end of this file).
create table if not exists listening_batches (
  id uuid primary key,
  listener_id uuid not null references listeners (id) on delete cascade,
  received_at timestamptz not null default now()
);
create index if not exists listening_batches_listener_idx on listening_batches (listener_id);
create index if not exists listening_batches_received_idx on listening_batches (received_at);

-- Single-row switchboard. The app asks `stats_available()` and only shows
-- the Statistiky tab / home block once enough people have listened.
create table if not exists stats_config (
  id boolean primary key default true check (id),
  -- The stats UI appears once this many listeners ...
  min_listeners integer not null default 20,
  -- ... have each listened at least this long (keeps accidental taps out
  -- of both the threshold and the leaderboard denominator).
  min_listener_seconds integer not null default 60,
  -- Manual override for testing before the threshold is reached.
  force_enabled boolean not null default false
);
insert into stats_config default values on conflict do nothing;

alter table listeners enable row level security;
alter table listening_daily enable row level security;
alter table listening_batches enable row level security;
alter table stats_config enable row level security;

revoke all on listeners, listening_daily, listening_batches, stats_config from anon, authenticated;

-- ---------------------------------------------------------------------
-- Public: should the app show the stats UI at all?
-- ---------------------------------------------------------------------
create or replace function stats_available()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select c.force_enabled
      or (select count(*) from listeners l where l.total_seconds >= c.min_listener_seconds) >= c.min_listeners
  from stats_config c
  limit 1;
$$;

-- ---------------------------------------------------------------------
-- Record a batch of listening time for the calling (anonymous) user.
--   p_rows: [{"day": "2026-10-06", "show_id": "diggin-time-s-dj-magic", "seconds": 120}, ...]
-- Idempotent per p_batch_id. Defensive limits, since the client is not
-- trusted: at most 200 rows, 24 h per listener per day, days no older than
-- 60 days and no more than one day ahead (time zones).
-- ---------------------------------------------------------------------
create or replace function record_listening(p_batch_id uuid, p_rows jsonb, p_app_version text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  r record;
  day_total integer;
  allowed integer;
  applied bigint := 0;
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if p_rows is null or jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) > 200 then
    raise exception 'invalid rows' using errcode = '22023';
  end if;

  insert into listeners (id, app_version)
  values (uid, left(p_app_version, 32))
  on conflict (id) do nothing;

  insert into listening_batches (id, listener_id) values (p_batch_id, uid)
  on conflict (id) do nothing;
  if not found then
    return; -- this batch was already applied
  end if;

  for r in
    select (e ->> 'day')::date as day,
           left(e ->> 'show_id', 100) as show_id,
           (e ->> 'seconds')::integer as seconds
    from jsonb_array_elements(p_rows) as e
  loop
    continue when r.day is null or r.show_id is null or r.show_id = '' or r.seconds is null or r.seconds < 1;
    continue when r.day < current_date - 60 or r.day > current_date + 1;

    select coalesce(sum(d.seconds), 0) into day_total
    from listening_daily d
    where d.listener_id = uid and d.day = r.day;

    allowed := least(r.seconds, greatest(0, 86400 - day_total));
    continue when allowed <= 0;

    insert into listening_daily (listener_id, day, show_id, seconds)
    values (uid, r.day, r.show_id, allowed)
    on conflict (listener_id, day, show_id)
    do update set seconds = listening_daily.seconds + excluded.seconds;

    applied := applied + allowed;
  end loop;

  update listeners
  set total_seconds = total_seconds + applied,
      last_seen_at = now(),
      first_play_at = case when applied > 0 then coalesce(first_play_at, now()) else first_play_at end,
      app_version = coalesce(left(p_app_version, 32), app_version)
  where id = uid;
end;
$$;

-- ---------------------------------------------------------------------
-- Everything the Statistiky screen needs in one round trip.
--   total_seconds      — this listener, all time
--   community_seconds  — everybody, all time ("Celkem všichni Slow Down Riders")
--   rank / ranked_listeners — place among listeners with enough listening
--                        (rank is null until this listener qualifies)
--   daily              — this listener's rows since p_since, for the weekly
--                        chart and the per-show breakdown
-- ---------------------------------------------------------------------
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
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select * into cfg from stats_config limit 1;
  select l.total_seconds into mine from listeners l where l.id = uid;
  mine := coalesce(mine, 0);

  return jsonb_build_object(
    'available', stats_available(),
    'total_seconds', mine,
    'community_seconds', (select coalesce(sum(l.total_seconds), 0) from listeners l),
    'ranked_listeners', (select count(*) from listeners l where l.total_seconds >= cfg.min_listener_seconds),
    'rank', case
      when mine >= cfg.min_listener_seconds
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

-- ---------------------------------------------------------------------
-- "Smazat moje statistiky" — removes the caller's rows (cascades to the
-- daily rows and batches). The anonymous auth user itself stays; it simply
-- starts again from zero on the next listen.
-- ---------------------------------------------------------------------
create or replace function delete_my_listening_data()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  delete from listeners where id = auth.uid();
end;
$$;

-- Functions are executable by PUBLIC by default — and on Supabase `anon` and
-- `authenticated` additionally get an explicit EXECUTE on every new function
-- in `public` (default privileges), which `revoke ... from public` does not
-- remove. So lock them down for each role by name.
revoke all on function stats_available() from public, anon, authenticated;
revoke all on function record_listening(uuid, jsonb, text) from public, anon, authenticated;
revoke all on function get_my_stats(date) from public, anon, authenticated;
revoke all on function delete_my_listening_data() from public, anon, authenticated;

grant execute on function stats_available() to anon, authenticated;
grant execute on function record_listening(uuid, jsonb, text) to authenticated;
grant execute on function get_my_stats(date) to authenticated;
grant execute on function delete_my_listening_data() to authenticated;

-- ---------------------------------------------------------------------
-- Retention jobs (unused listeners after 24 months, old batch ids) live in
-- 006_community_archive.sql, which also keeps the community total from
-- shrinking when listeners are cleaned up. Run that file next.
-- ---------------------------------------------------------------------

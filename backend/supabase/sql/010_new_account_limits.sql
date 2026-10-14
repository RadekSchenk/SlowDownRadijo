-- Two loopholes in the protection against made-up listening time (008):
--
--   1. The 12 h backlog allowance applied in full to a brand-new account, so
--      every fresh anonymous sign-up could report 12 h at once and jump up
--      the leaderboard. Now a new account starts with 15 minutes (enough for
--      the first upload, which the app sends after a minute of listening)
--      and the allowance grows with the account's age up to 12 h.
--   2. The community threshold (`stats_available`) counted listeners as soon
--      as they had a minute, so twenty scripted sign-ups unlocked the
--      community total and the leaderboard immediately. Now a listener counts
--      towards the threshold only once their record is at least a day old.
--
-- Run after 009. Replaces `record_listening` and `stats_available`; safe to
-- re-run.

create or replace function stats_available()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select c.force_enabled
      or (select count(*) from listeners l
          where l.total_seconds >= c.min_listener_seconds
            and l.created_at <= now() - interval '1 day') >= c.min_listeners
  from stats_config c
  limit 1;
$$;

revoke all on function stats_available() from public, anon, authenticated;
grant execute on function stats_available() to anon, authenticated;

create or replace function record_listening(p_batch_id uuid, p_rows jsonb, p_app_version text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  backlog_allowance constant integer := 12 * 3600;
  initial_allowance constant integer := 15 * 60;
  max_batches_per_hour constant integer := 120;
  max_shows_per_day constant integer := 24;
  r record;
  created timestamptz;
  age_seconds bigint;
  already bigint;
  room bigint;
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

  if (select count(*) from listening_batches b
      where b.listener_id = uid and b.received_at > now() - interval '1 hour') >= max_batches_per_hour then
    raise exception 'too many batches' using errcode = 'PT429';
  end if;

  insert into listeners (id, app_version)
  values (uid, left(p_app_version, 32))
  on conflict (id) do nothing;

  -- Lock this listener's row so two simultaneous uploads can't both spend
  -- the same remaining allowance.
  select l.created_at, l.total_seconds into created, already
  from listeners l where l.id = uid for update;

  insert into listening_batches (id, listener_id) values (p_batch_id, uid)
  on conflict (id) do nothing;
  if not found then
    return; -- this batch was already applied
  end if;

  -- A brand-new listener gets `initial_allowance` (enough for the first
  -- upload, which carries listening from before the account existed); the
  -- full backlog allowance builds up with the account's age.
  age_seconds := floor(extract(epoch from (now() - created)))::bigint;
  room := greatest(0, age_seconds + least(backlog_allowance, initial_allowance + age_seconds) - already);

  for r in
    select (e ->> 'day')::date as day,
           left(e ->> 'show_id', 100) as show_id,
           (e ->> 'seconds')::integer as seconds
    from jsonb_array_elements(p_rows) as e
  loop
    exit when room <= 0;
    continue when r.day is null or r.show_id is null or r.seconds is null or r.seconds < 1;
    continue when r.show_id <> '_' and r.show_id !~ '^[a-z0-9][a-z0-9-]*$';
    continue when r.day < current_date - 60 or r.day > current_date + 1;

    -- A new show for this day, but the day already has plenty of them.
    continue when not exists (
        select 1 from listening_daily d
        where d.listener_id = uid and d.day = r.day and d.show_id = r.show_id)
      and (select count(*) from listening_daily d
           where d.listener_id = uid and d.day = r.day) >= max_shows_per_day;

    select coalesce(sum(d.seconds), 0) into day_total
    from listening_daily d
    where d.listener_id = uid and d.day = r.day;

    allowed := least(r.seconds, greatest(0, 86400 - day_total), room);
    continue when allowed <= 0;

    insert into listening_daily (listener_id, day, show_id, seconds)
    values (uid, r.day, r.show_id, allowed)
    on conflict (listener_id, day, show_id)
    do update set seconds = listening_daily.seconds + excluded.seconds;

    applied := applied + allowed;
    room := room - allowed;
  end loop;

  update listeners
  set total_seconds = total_seconds + applied,
      last_seen_at = now(),
      first_play_at = case when applied > 0 then coalesce(first_play_at, now()) else first_play_at end,
      app_version = coalesce(left(p_app_version, 32), app_version)
  where id = uid;
end;
$$;

revoke all on function record_listening(uuid, jsonb, text) from public, anon, authenticated;
grant execute on function record_listening(uuid, jsonb, text) to authenticated;

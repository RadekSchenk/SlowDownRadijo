-- Basic protection of the leaderboard and the community total against made-up
-- listening time. The app is trusted only as far as the numbers are plausible:
--
--   1. Time can't outrun the clock. A listener's total may never exceed the
--      real time since their account was created plus a 12 h allowance. The
--      allowance exists for honest backlog: listening that happened before
--      the first successful upload (an outage, a long offline stretch) is
--      still accepted, so nobody loses time because our server was down.
--      Streaming is real-time, so seconds can't legitimately pile up faster
--      than seconds pass.
--   2. At most 120 batches per listener per hour. The app sends a handful;
--      the limit stops a script from flooding the table. Over the limit the
--      call answers HTTP 429 and the app simply retries later.
--   3. `show_id` must look like a schedule id (lowercase letters, digits and
--      dashes, or "_" for "no show on air"), and a listener can have at most
--      24 different shows per day — a real day has about fifteen.
--   4. The existing limits stay: 200 rows per batch, 24 h per listener per
--      day, days within the last 60 days and no more than one day ahead.
--
-- What this does not stop: someone who really keeps the stream playing around
-- the clock (indistinguishable from a radio left on), or someone farming many
-- anonymous accounts (Supabase rate-limits sign-ups per IP; CAPTCHA or
-- Apple's App Attest would be the next step if that ever matters).
--
-- Run after 007. Replaces `record_listening`; safe to re-run.

create or replace function record_listening(p_batch_id uuid, p_rows jsonb, p_app_version text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  backlog_allowance constant integer := 12 * 3600;
  max_batches_per_hour constant integer := 120;
  max_shows_per_day constant integer := 24;
  r record;
  created timestamptz;
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

  room := greatest(0, floor(extract(epoch from (now() - created)))::bigint + backlog_allowance - already);

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

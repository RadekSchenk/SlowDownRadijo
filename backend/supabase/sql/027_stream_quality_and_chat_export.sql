-- Sound quality in the listening stats, and the chat's daily numbers for
-- PostHog (app 1.3). Everything here is counted for every listener with
-- stats on, without the analytics consent, and goes out only as totals.
--
--   * The apps add `stream` (mp3 / aac: what really played) and `quality`
--     (the setting: auto / high / low) to each listening row. The seconds
--     still count per day and show as before; on top, they're summed in
--     `listening_streams_daily` by day, stream and setting, with no listener
--     in it. Rows from older apps count as "unknown".
--   * `listeners.stream_quality`: the listener's latest setting, so the
--     export can say how many listeners use each one.
--   * posthog_export gains (read by PostHog's warehouse source "radio" as
--     `posthog_reader`, like the listening reports and registrations):
--       listening_quality_daily  – hours per day, stream and setting
--       listening_quality_users  – listeners of the last 30 days per setting
--       chat_daily               – the chat's daily summary (022)
--       chat_shows_30d           – where the chat is busiest (022)
--       chat_retention           – do new writers come back (022)
--
-- Run after 026. Replaces `record_listening` (as in production, plus the
-- two fields); safe to re-run.

alter table listeners add column if not exists stream_quality text;

create table if not exists listening_streams_daily (
  day date not null,
  stream text not null,
  quality text not null,
  seconds bigint not null default 0,
  primary key (day, stream, quality)
);
alter table listening_streams_daily enable row level security;
revoke all on listening_streams_daily from public, anon, authenticated;

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
  latest_quality text;
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

  select l.created_at, l.total_seconds into created, already
  from listeners l where l.id = uid for update;

  insert into listening_batches (id, listener_id) values (p_batch_id, uid)
  on conflict (id) do nothing;
  if not found then
    return;
  end if;

  age_seconds := floor(extract(epoch from (now() - created)))::bigint;
  room := greatest(0, age_seconds + least(backlog_allowance, initial_allowance + age_seconds) - already);

  for r in
    select (e ->> 'day')::date as day,
           left(e ->> 'show_id', 100) as show_id,
           (e ->> 'seconds')::integer as seconds,
           case when e ->> 'stream' in ('mp3', 'aac') then e ->> 'stream' else 'unknown' end as stream,
           case when e ->> 'quality' in ('auto', 'high', 'low') then e ->> 'quality' else 'unknown' end as quality
    from jsonb_array_elements(p_rows) as e
  loop
    exit when room <= 0;
    continue when r.day is null or r.show_id is null or r.seconds is null or r.seconds < 1;
    continue when r.show_id <> '_' and r.show_id !~ '^[a-z0-9][a-z0-9-]*$';
    continue when r.day < current_date - 60 or r.day > current_date + 1;

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

    -- The same seconds by stream and setting, with no listener attached.
    insert into listening_streams_daily (day, stream, quality, seconds)
    values (r.day, r.stream, r.quality, allowed)
    on conflict (day, stream, quality)
    do update set seconds = listening_streams_daily.seconds + excluded.seconds;

    if r.quality <> 'unknown' then latest_quality := r.quality; end if;
    applied := applied + allowed;
    room := room - allowed;
  end loop;

  update listeners
  set total_seconds = total_seconds + applied,
      last_seen_at = now(),
      first_play_at = case when applied > 0 then coalesce(first_play_at, now()) else first_play_at end,
      app_version = coalesce(left(p_app_version, 32), app_version),
      stream_quality = coalesce(latest_quality, stream_quality)
  where id = uid;
end;
$$;

revoke all on function record_listening(uuid, jsonb, text) from public, anon;
grant execute on function record_listening(uuid, jsonb, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Export for PostHog (as 018 and 025: owner-rights functions behind views)

create or replace function posthog_export.listening_quality_daily_rows()
  returns table (day date, stream text, quality text, hours numeric)
  language sql stable security definer set search_path = ''
  as $$
    select s.day, s.stream, s.quality, round(s.seconds / 3600.0, 2)
    from public.listening_streams_daily s
  $$;

create or replace function posthog_export.listening_quality_users_rows()
  returns table (quality text, listeners bigint)
  language sql stable security definer set search_path = ''
  as $$
    select coalesce(l.stream_quality, 'unknown'), count(*)
    from public.listeners l
    where l.last_seen_at > now() - interval '30 days'
    group by 1
  $$;

create or replace function posthog_export.chat_daily_rows()
  returns setof public.chat_stats_daily
  language sql stable security definer set search_path = ''
  as $$ select * from public.chat_stats_daily $$;

create or replace function posthog_export.chat_shows_30d_rows()
  returns setof public.chat_stats_shows_30d
  language sql stable security definer set search_path = ''
  as $$ select * from public.chat_stats_shows_30d $$;

create or replace function posthog_export.chat_retention_rows()
  returns setof public.chat_stats_retention
  language sql stable security definer set search_path = ''
  as $$ select * from public.chat_stats_retention $$;

revoke all on all functions in schema posthog_export from public, anon, authenticated;
grant execute on all functions in schema posthog_export to posthog_reader;

create or replace view posthog_export.listening_quality_daily as select * from posthog_export.listening_quality_daily_rows();
create or replace view posthog_export.listening_quality_users as select * from posthog_export.listening_quality_users_rows();
create or replace view posthog_export.chat_daily as select * from posthog_export.chat_daily_rows();
create or replace view posthog_export.chat_shows_30d as select * from posthog_export.chat_shows_30d_rows();
create or replace view posthog_export.chat_retention as select * from posthog_export.chat_retention_rows();

revoke all on all tables in schema posthog_export from public, anon, authenticated;
grant usage on schema posthog_export to posthog_reader;
grant select on all tables in schema posthog_export to posthog_reader;

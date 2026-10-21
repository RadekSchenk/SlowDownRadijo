-- Listener counts for the whole station (web, app and every other player)
-- from play.cz, which hosts the stream: its public API
-- (https://api.play.cz/json/getListeners/radio-slowdown) returns
--   now   — listeners per stream right now (AAC, MP3 and their fallbacks),
--   d24h  — the station total every 5 minutes for the last 24 hours,
--   daily — the day's highest and lowest total, for about two months.
-- Times in it are Prague time.
--
-- pg_cron calls collect_playcz() every 5 minutes. Requests through pg_net
-- are asynchronous, so each run first stores the answers to earlier
-- requests, then sends a new one. The 5-minute points overlap across runs
-- (upserts), so a missed run leaves no gap.
--
-- The tables hold station totals only — nothing about any listener.
-- PostHog reads them through `posthog_export` (015).
--
-- Safe to re-run.

create table if not exists playcz_listeners (
  at timestamptz primary key,
  listeners integer not null
);

create table if not exists playcz_streams (
  at timestamptz not null,
  stream text not null,
  listeners integer not null,
  primary key (at, stream)
);

create table if not exists playcz_daily (
  day date primary key,
  listeners_max integer not null,
  listeners_min integer not null
);

create table if not exists playcz_requests (
  id bigint primary key,
  requested_at timestamptz not null default now()
);

alter table playcz_listeners enable row level security;
alter table playcz_streams enable row level security;
alter table playcz_daily enable row level security;
alter table playcz_requests enable row level security;
revoke all on playcz_listeners, playcz_streams, playcz_daily, playcz_requests
  from public, anon, authenticated;

create or replace function collect_playcz()
returns void
language plpgsql
security definer
set search_path = public, net
as $$
declare
  pending record;
  body jsonb;
begin
  for pending in
    select r.id, r.requested_at, resp.content
    from playcz_requests r
    join net._http_response resp on resp.id = r.id
    where resp.status_code = 200
  loop
    begin
      body := pending.content::jsonb -> 'data';

      insert into playcz_listeners (at, listeners)
      select (p ->> 'date_time')::timestamp at time zone 'Europe/Prague',
             (p ->> 'listeners')::int
      from jsonb_array_elements(coalesce(nullif(body -> 'd24h', 'null'::jsonb), '[]')) p
      on conflict (at) do update set listeners = excluded.listeners;

      insert into playcz_streams (at, stream, listeners)
      select date_trunc('minute', pending.requested_at),
             -- "http://icecast5.play.cz/slowdown.aac" -> "slowdown.aac"
             regexp_replace(s ->> 'pubpoint', '^.*/', ''),
             (s ->> 'listeners')::int
      from jsonb_array_elements(coalesce(nullif(body -> 'now', 'null'::jsonb), '[]')) s
      on conflict (at, stream) do update set listeners = excluded.listeners;

      insert into playcz_daily (day, listeners_max, listeners_min)
      select (d ->> 'date')::date, (d ->> 'listeners_max')::int, (d ->> 'listeners_min')::int
      from jsonb_array_elements(coalesce(nullif(body -> 'daily', 'null'::jsonb), '[]')) d
      on conflict (day) do update
        set listeners_max = excluded.listeners_max,
            listeners_min = excluded.listeners_min;
    exception when others then
      -- A malformed answer is skipped; the next one covers the same 24 h.
      null;
    end;
    delete from playcz_requests where id = pending.id;
  end loop;

  -- Answers that never came (pg_net keeps responses for a few hours).
  delete from playcz_requests where requested_at < now() - interval '1 hour';

  insert into playcz_requests (id)
  values (net.http_get('https://api.play.cz/json/getListeners/radio-slowdown'));
end;
$$;

revoke all on function collect_playcz() from public, anon, authenticated;

-- PostHog: totals only.
create or replace view posthog_export.playcz_listeners as
  select at, listeners from public.playcz_listeners;
create or replace view posthog_export.playcz_streams as
  select at, stream, listeners from public.playcz_streams;
create or replace view posthog_export.playcz_daily as
  select day, listeners_max, listeners_min from public.playcz_daily;
revoke all on all tables in schema posthog_export from public, anon, authenticated;
grant select on all tables in schema posthog_export to posthog_reader;

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.schedule('collect-playcz', '*/5 * * * *', 'select public.collect_playcz()');
  end if;
end
$$;

-- First request right away; the next run (within 5 minutes) stores it.
select public.collect_playcz();

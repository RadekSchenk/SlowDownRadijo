-- Keeps the community total ("Celkem všichni Slow Down Riders") from ever
-- shrinking when inactive listeners are cleaned up.
--
--   * Automatic cleanup (a listener unused for 24 months): their seconds are
--     first added to `community_archive`, a single anonymous counter — no id,
--     no link to anyone, so it is aggregate data rather than personal data.
--     They leave the leaderboard (it only ranks current listeners), but the
--     community total keeps their hours.
--   * Manual deletion ("Smazat moje statistiky", `delete_my_listening_data`):
--     nothing is archived. The listener's seconds disappear from the total as
--     well — deleting your data means nothing of you stays behind.
--
-- Run after 005_listener_stats.sql, in the SQL Editor. Safe to re-run.
-- The final block (re)schedules the retention jobs if pg_cron is available;
-- it replaces the `prune-inactive-listeners` job from the notes in 005.

create table if not exists community_archive (
  id boolean primary key default true check (id),
  seconds bigint not null default 0 check (seconds >= 0)
);
insert into community_archive default values on conflict do nothing;

alter table community_archive enable row level security;
revoke all on community_archive from anon, authenticated;

-- Deletes listeners unused for `p_inactive_for` and archives their seconds.
-- Returns how many seconds were archived. Called by pg_cron, not by clients.
create or replace function prune_inactive_listeners(p_inactive_for interval default interval '24 months')
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  archived bigint;
begin
  with gone as (
    delete from listeners
    where coalesce(last_seen_at, created_at) < now() - p_inactive_for
    returning total_seconds
  )
  select coalesce(sum(total_seconds), 0) into archived from gone;

  update community_archive set seconds = seconds + archived where id;
  return archived;
end;
$$;

revoke all on function prune_inactive_listeners(interval) from public, anon, authenticated;

-- Same as in 005, except `community_seconds` now includes the archive.
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
    'community_seconds',
      (select coalesce(sum(l.total_seconds), 0) from listeners l)
      + coalesce((select a.seconds from community_archive a limit 1), 0),
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

revoke all on function get_my_stats(date) from public, anon, authenticated;
grant execute on function get_my_stats(date) to authenticated;

-- Retention jobs (cron.schedule with an existing name replaces that job).
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.schedule(
      'prune-listening-batches', '17 3 * * *',
      $job$ delete from listening_batches where received_at < now() - interval '7 days' $job$
    );
    perform cron.schedule(
      'prune-inactive-listeners', '23 3 * * 0',
      $job$ select prune_inactive_listeners() $job$
    );
  end if;
end;
$$;

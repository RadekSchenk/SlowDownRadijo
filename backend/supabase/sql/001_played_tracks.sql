-- Radio-wide play history + stats, independent of whether the app is open.
-- Populated by the collect-now-playing Edge Function (reads ICY metadata
-- directly from the stream — deliberately NOT the station's own website
-- API, which was found to be months stale).
--
-- Run this once in the Supabase Dashboard's SQL Editor
-- (https://supabase.com/dashboard/project/_/sql/new).

create table if not exists played_tracks (
  id uuid primary key default gen_random_uuid(),
  artist text not null,
  title text not null,
  played_at timestamptz not null default now(),
  show_name text
);

create index if not exists played_tracks_played_at_idx on played_tracks (played_at desc);
create index if not exists played_tracks_artist_title_idx on played_tracks (artist, title);

alter table played_tracks enable row level security;

drop policy if exists "Allow public read" on played_tracks;
create policy "Allow public read" on played_tracks
  for select using (true);

-- No insert/update/delete policy for anon/authenticated: only the collector
-- (using the service-role key, which bypasses RLS) writes to this table.

-- ---------------------------------------------------------------------
-- Stats functions — called by the get-stats Edge Function.
-- ---------------------------------------------------------------------

-- Unique artists per ISO week, and how many of them are appearing for the
-- very first time that week (their global debut).
create or replace function diversity_weekly(weeks_back int default 12)
returns table (week_start date, unique_artists bigint, first_time_artists bigint)
language sql stable
as $$
  with first_seen as (
    select artist, min(played_at) as first_played_at
    from played_tracks
    group by artist
  ),
  weeks as (
    select date_trunc('week', played_at)::date as week_start, artist
    from played_tracks
    where played_at >= now() - (weeks_back || ' weeks')::interval
  )
  select
    w.week_start,
    count(distinct w.artist) as unique_artists,
    count(distinct w.artist) filter (
      where date_trunc('week', fs.first_played_at)::date = w.week_start
    ) as first_time_artists
  from weeks w
  join first_seen fs on fs.artist = w.artist
  group by w.week_start
  order by w.week_start;
$$;

-- % of plays in the last `days_back` days that are repeats of a
-- (artist, title) pair played at some earlier point, vs. genuinely new.
create or replace function repetition_rate(days_back int default 30)
returns table (total_plays bigint, repeated_plays bigint, new_plays bigint, repetition_pct numeric)
language sql stable
as $$
  with windowed as (
    select pt.artist, pt.title, pt.played_at,
      exists (
        select 1 from played_tracks earlier
        where earlier.artist = pt.artist and earlier.title = pt.title
          and earlier.played_at < pt.played_at
      ) as is_repeat
    from played_tracks pt
    where pt.played_at >= now() - (days_back || ' days')::interval
  )
  select
    count(*) as total_plays,
    count(*) filter (where is_repeat) as repeated_plays,
    count(*) filter (where not is_repeat) as new_plays,
    round(100.0 * count(*) filter (where is_repeat) / nullif(count(*), 0), 1) as repetition_pct
  from windowed;
$$;

-- Tracks at the moment of their global debut play, most recent first.
create or replace function first_plays(limit_count int default 30)
returns table (artist text, title text, played_at timestamptz)
language sql stable
as $$
  select pt.artist, pt.title, pt.played_at
  from played_tracks pt
  where pt.played_at = (
    select min(played_at) from played_tracks e
    where e.artist = pt.artist and e.title = pt.title
  )
  order by pt.played_at desc
  limit limit_count;
$$;

grant execute on function diversity_weekly(int) to anon, authenticated;
grant execute on function repetition_rate(int) to anon, authenticated;
grant execute on function first_plays(int) to anon, authenticated;

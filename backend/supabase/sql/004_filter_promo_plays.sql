-- Every stats function so far reads straight from `played_tracks`, which
-- also contains station-generated noise: jingles/sponsor mentions logged
-- under the artist "SLOWDOWN" (PROMO, hymer.cz, brylarna.cz, show-start
-- announcements), and a handful of rows from shows that don't tag
-- individual tracks in ICY metadata at all, where artist and title both
-- just repeat the show's own name (e.g. "Morning Coffee s DJ Pufaz" /
-- "Morning Coffee s DJ Pufaz" — genuinely no track info, not just messy
-- data). Measured against the live table: ~6.3% of rows (122 of 1933).
--
-- A handful of borderline rows were deliberately left alone: cases where
-- the artist field is a placeholder matching the show name but the title
-- still carries real info (e.g. artist "Britský State of Mind" / title
-- "C. Monts", a guest name) — too small a slice (7 rows) and too
-- ambiguous to safely auto-filter.
--
-- Centralized as a view so every stats function filters consistently
-- instead of repeating the same WHERE clause five times. Run this once in
-- the Supabase Dashboard's SQL Editor, after 001-003.

create or replace view played_tracks_clean as
select *
from played_tracks
where upper(trim(artist)) <> 'SLOWDOWN'
  and lower(trim(artist)) <> lower(trim(title));

grant select on played_tracks_clean to anon, authenticated;

-- Re-point every existing stats function at the clean view. Bodies are
-- otherwise unchanged from 001_played_tracks.sql / 002_first_plays_weekly.sql
-- / 003_total_unique_tracks.sql.

create or replace function diversity_weekly(weeks_back int default 12)
returns table (week_start date, unique_artists bigint, first_time_artists bigint)
language sql stable
as $$
  with first_seen as (
    select artist, min(played_at) as first_played_at
    from played_tracks_clean
    group by artist
  ),
  weeks as (
    select date_trunc('week', played_at)::date as week_start, artist
    from played_tracks_clean
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

create or replace function repetition_rate(days_back int default 30)
returns table (total_plays bigint, repeated_plays bigint, new_plays bigint, repetition_pct numeric)
language sql stable
as $$
  with windowed as (
    select pt.artist, pt.title, pt.played_at,
      exists (
        select 1 from played_tracks_clean earlier
        where earlier.artist = pt.artist and earlier.title = pt.title
          and earlier.played_at < pt.played_at
      ) as is_repeat
    from played_tracks_clean pt
    where pt.played_at >= now() - (days_back || ' days')::interval
  )
  select
    count(*) as total_plays,
    count(*) filter (where is_repeat) as repeated_plays,
    count(*) filter (where not is_repeat) as new_plays,
    round(100.0 * count(*) filter (where is_repeat) / nullif(count(*), 0), 1) as repetition_pct
  from windowed;
$$;

create or replace function first_plays_week_count()
returns bigint
language sql stable
as $$
  select count(*)
  from played_tracks_clean pt
  where pt.played_at = (
    select min(played_at) from played_tracks_clean e
    where e.artist = pt.artist and e.title = pt.title
  )
  and pt.played_at >= date_trunc('week', now());
$$;

create or replace function first_plays_week_sample(limit_count int default 5)
returns table (artist text, title text, played_at timestamptz)
language sql stable
as $$
  select pt.artist, pt.title, pt.played_at
  from played_tracks_clean pt
  where pt.played_at = (
    select min(played_at) from played_tracks_clean e
    where e.artist = pt.artist and e.title = pt.title
  )
  and pt.played_at >= date_trunc('week', now())
  order by pt.played_at desc
  limit limit_count;
$$;

create or replace function total_unique_tracks_count()
returns bigint
language sql stable
as $$
  select count(*) from (select distinct artist, title from played_tracks_clean) t;
$$;

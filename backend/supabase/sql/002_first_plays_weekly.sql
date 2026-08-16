-- Replaces the flat, ever-growing `first_plays(limit_count)` feed with a
-- weekly digest: a headline count of debuts this week, plus a small
-- highlighted sample — see the "Statistiky" tab's redesign discussion.
-- Run this in the Supabase Dashboard's SQL Editor.

drop function if exists first_plays(int);

-- Total number of tracks making their global debut so far this week
-- (Monday-based, per Postgres's date_trunc('week', ...)).
create or replace function first_plays_week_count()
returns bigint
language sql stable
as $$
  select count(*)
  from played_tracks pt
  where pt.played_at = (
    select min(played_at) from played_tracks e
    where e.artist = pt.artist and e.title = pt.title
  )
  and pt.played_at >= date_trunc('week', now());
$$;

-- A small, most-recent-first sample of this week's debuts, for the "a few
-- highlights" part of the digest.
create or replace function first_plays_week_sample(limit_count int default 5)
returns table (artist text, title text, played_at timestamptz)
language sql stable
as $$
  select pt.artist, pt.title, pt.played_at
  from played_tracks pt
  where pt.played_at = (
    select min(played_at) from played_tracks e
    where e.artist = pt.artist and e.title = pt.title
  )
  and pt.played_at >= date_trunc('week', now())
  order by pt.played_at desc
  limit limit_count;
$$;

grant execute on function first_plays_week_count() to anon, authenticated;
grant execute on function first_plays_week_sample(int) to anon, authenticated;

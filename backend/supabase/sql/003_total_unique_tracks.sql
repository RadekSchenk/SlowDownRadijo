-- Gives the weekly "first time on air" count some scale — "12 nových
-- tento týden, celkem už 340 skladeb v éteru" reads very differently than
-- "12" on its own. Run in the Supabase Dashboard's SQL Editor.

create or replace function total_unique_tracks_count()
returns bigint
language sql stable
as $$
  select count(*) from (select distinct artist, title from played_tracks) t;
$$;

grant execute on function total_unique_tracks_count() to anon, authenticated;

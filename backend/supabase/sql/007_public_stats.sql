-- Public, session-less summary for the app: "is the stats UI unlocked?" plus
-- the two community numbers every listener sees — total listening time of
-- everybody ("Celkem všichni Slow Down Riders") and how many listeners the
-- leaderboard ranks. Lets someone who hasn't listened yet (so has no
-- anonymous session) still see the community card.
--
-- Until the listener threshold in `stats_config` is reached (or
-- `force_enabled` is on) it returns zeros, so a handful of early listeners'
-- totals are never exposed to the public.
--
-- Run after 006_community_archive.sql. Safe to re-run.

create or replace function public_stats()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  is_available boolean := stats_available();
begin
  return jsonb_build_object(
    'available', is_available,
    'community_seconds', case when is_available then
      (select coalesce(sum(l.total_seconds), 0) from listeners l)
      + coalesce((select a.seconds from community_archive a limit 1), 0)
      else 0 end,
    'ranked_listeners', case when is_available then
      (select count(*) from listeners l, stats_config c where l.total_seconds >= c.min_listener_seconds)
      else 0 end
  );
end;
$$;

revoke all on function public_stats() from public, anon, authenticated;
grant execute on function public_stats() to anon, authenticated;

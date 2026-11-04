-- Pin search_path on the older public read functions (Supabase advisor
-- "function_search_path_mutable"). Behaviour is unchanged: they only read
-- public.played_tracks.

alter function public.diversity_weekly(integer) set search_path = public;
alter function public.first_plays_week_count() set search_path = public;
alter function public.first_plays_week_sample(integer) set search_path = public;
alter function public.repetition_rate(integer) set search_path = public;
alter function public.total_unique_tracks_count() set search_path = public;

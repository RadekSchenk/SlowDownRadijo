-- 015 let posthog_reader read the `reports` totals through owner-rights
-- views, but the `reports` views are security_invoker, so their own
-- reads were still checked as posthog_reader ("permission denied for
-- view active_days") and PostHog's first sync failed.
--
-- Each export view now reads its report through a SECURITY DEFINER
-- function owned by postgres: inside it the `reports` views run as the
-- owner, while posthog_reader still sees nothing but these six results —
-- totals per day, week, month and show, no listener ids.
--
-- Safe to re-run.

create or replace function posthog_export.daily_listeners_rows()
  returns setof reports.daily_listeners
  language sql stable security definer set search_path = ''
  as $$ select * from reports.daily_listeners $$;

create or replace function posthog_export.weekly_listeners_rows()
  returns setof reports.weekly_listeners
  language sql stable security definer set search_path = ''
  as $$ select * from reports.weekly_listeners $$;

create or replace function posthog_export.monthly_listeners_rows()
  returns setof reports.monthly_listeners
  language sql stable security definer set search_path = ''
  as $$ select * from reports.monthly_listeners $$;

create or replace function posthog_export.monthly_segments_rows()
  returns setof reports.monthly_segments
  language sql stable security definer set search_path = ''
  as $$ select * from reports.monthly_segments $$;

create or replace function posthog_export.show_listening_rows()
  returns setof reports.show_listening
  language sql stable security definer set search_path = ''
  as $$ select * from reports.show_listening $$;

create or replace function posthog_export.overview_rows()
  returns setof reports.overview
  language sql stable security definer set search_path = ''
  as $$ select * from reports.overview $$;

revoke all on all functions in schema posthog_export from public, anon, authenticated;
grant execute on all functions in schema posthog_export to posthog_reader;

create or replace view posthog_export.daily_listeners as
  select * from posthog_export.daily_listeners_rows();
create or replace view posthog_export.weekly_listeners as
  select * from posthog_export.weekly_listeners_rows();
create or replace view posthog_export.monthly_listeners as
  select * from posthog_export.monthly_listeners_rows();
create or replace view posthog_export.monthly_segments as
  select * from posthog_export.monthly_segments_rows();
create or replace view posthog_export.show_listening as
  select * from posthog_export.show_listening_rows();
create or replace view posthog_export.overview as
  select * from posthog_export.overview_rows();

revoke all on all tables in schema posthog_export from public, anon, authenticated;
grant select on all tables in schema posthog_export to posthog_reader;

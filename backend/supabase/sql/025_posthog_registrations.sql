-- Registrations in PostHog (app 1.3): `account_stats_daily` (024) goes out
-- the same way as the listening reports (015, 018), through the
-- `posthog_export` schema that PostHog's data warehouse source "radio"
-- already reads as `posthog_reader`. Counts per day, platform and sign-in
-- method only; no accounts, e-mails or nicknames.
--
-- 024 granted the view in `public` directly; that's taken back here, so
-- posthog_reader again reads nothing outside `posthog_export`.
-- Run after 024. Safe to re-run.

create or replace function posthog_export.account_registrations_rows()
  returns setof public.account_stats_daily
  language sql stable security definer set search_path = ''
  as $$ select * from public.account_stats_daily $$;

revoke all on function posthog_export.account_registrations_rows() from public, anon, authenticated;
grant execute on function posthog_export.account_registrations_rows() to posthog_reader;

create or replace view posthog_export.account_registrations as
  select * from posthog_export.account_registrations_rows();

revoke all on posthog_export.account_registrations from public, anon, authenticated;
grant select on posthog_export.account_registrations to posthog_reader;

revoke select on public.account_stats_daily from posthog_reader;
revoke usage on schema public from posthog_reader;

-- Audience reports (013) for the PostHog data warehouse, so the PostHog
-- dashboard can show listening from every listener with stats on, not
-- only those who said yes to analytics.
--
-- PostHog connects as `posthog_reader`, which can read nothing but the
-- `posthog_export` views below: totals per day, week, month and show —
-- no listener ids, no per-listener rows. The views run with their
-- owner's rights (no security_invoker), so the role needs no access to
-- `reports` or `public`.
--
-- The role is created without a password. Set one in the SQL Editor
-- (never in a migration or a chat):
--   alter role posthog_reader with password '…';
-- then connect PostHog via the Session pooler as
-- `posthog_reader.<project-ref>`, schema `posthog_export`.
--
-- Safe to re-run.

create schema if not exists posthog_export;
revoke all on schema posthog_export from public, anon, authenticated;

create or replace view posthog_export.daily_listeners as
  select * from reports.daily_listeners;
create or replace view posthog_export.weekly_listeners as
  select * from reports.weekly_listeners;
create or replace view posthog_export.monthly_listeners as
  select * from reports.monthly_listeners;
create or replace view posthog_export.monthly_segments as
  select * from reports.monthly_segments;
create or replace view posthog_export.show_listening as
  select * from reports.show_listening;
create or replace view posthog_export.overview as
  select * from reports.overview;

revoke all on all tables in schema posthog_export from public, anon, authenticated;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'posthog_reader') then
    create role posthog_reader login;
  end if;
end
$$;

alter role posthog_reader set statement_timeout = '60s';
grant usage on schema posthog_export to posthog_reader;
grant select on all tables in schema posthog_export to posthog_reader;

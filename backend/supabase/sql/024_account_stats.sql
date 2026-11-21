-- Registrations for the station's statistics (app 1.3), complete and without
-- the analytics consent: only data the app keeps anyway for the account and
-- the listening stats, and only as counts per day, never per person.
--
--   * platform: from the listening stats' app version (Android's ends in
--     "android"); "unknown" for someone without listening stats.
--   * method: how the account was made (apple / google / email).
--   * Counts the accounts that exist today: a deleted account drops out.
--
-- `posthog_reader` may read this view and nothing else, for PostHog's data
-- warehouse. It has no password until one is set in the SQL Editor:
--   alter role posthog_reader with password '…';
-- Run after 023. Safe to re-run.

create or replace view account_stats_daily as
  select (p.registered_at at time zone 'Europe/Prague')::date as day,
         case when l.app_version ilike '%android%' then 'android'
              when l.app_version is not null then 'ios'
              else 'unknown' end as platform,
         coalesce(i.provider, 'unknown') as method,
         count(*)::int as registrations
  from profiles p
  left join listeners l on l.id = p.id
  left join lateral (
    select provider from auth.identities
    where user_id = p.id and provider <> 'anonymous'
    order by created_at limit 1
  ) i on true
  where p.registered_at is not null
  group by 1, 2, 3;

revoke all on account_stats_daily from anon, authenticated;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'posthog_reader') then
    create role posthog_reader with login nosuperuser nocreatedb nocreaterole noinherit;
  end if;
end $$;

grant usage on schema public to posthog_reader;
grant select on account_stats_daily to posthog_reader;

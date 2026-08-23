-- Cached follower/like counts for the station's social links (shown in the
-- hamburger menu — see SlowDownRadijo/Views/Hub/SocialLinksRow.swift).
-- Populated periodically by the update-social-stats Edge Function, not
-- fetched live from each platform on every app open — Instagram/Threads/
-- Facebook are scraped from public profile pages (no official public API
-- for follower counts without a Business account + token), and doing that
-- on every menu open would risk the server IP getting rate-limited/blocked.
--
-- Run this once in the Supabase Dashboard's SQL Editor
-- (https://supabase.com/dashboard/project/_/sql/new).

create table if not exists social_stats (
  platform text primary key,
  follower_count integer not null,
  updated_at timestamptz not null default now()
);

alter table social_stats enable row level security;

drop policy if exists "Allow public read" on social_stats;
create policy "Allow public read" on social_stats
  for select using (true);

-- No insert/update/delete policy for anon/authenticated: only the
-- update-social-stats collector (using the service-role key, which
-- bypasses RLS) writes to this table.

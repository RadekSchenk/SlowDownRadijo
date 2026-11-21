-- Chat v3 (app 1.3): writing without an account, Slowriders, superadmin,
-- archive and statistics. Design: Figma "Slow Down Rádijo", pages Chat and
-- Profil (section "Profil v3"). Rules: docs/chat-concept.md, part 2e.
--
--   * Writing no longer needs a permanent account. The phone's anonymous
--     user (the one behind the listening stats, created on demand) sets a
--     nickname with its first message. Changing it needs registration
--     (Apple, Google, e-mail), which upgrades that same user, so nickname,
--     messages and stats stay. The first change after registering is free of
--     the 24-hour wait.
--   * `profiles.registered_at`: when the user became permanent ("Jsi
--     součástí Slowriders od …"), noted by `chat_me()`.
--   * Counters for the Profil dashboard ("Tvůj Slowride"): chat messages and
--     voice messages, counted from now on (messages are deleted after 90
--     days, voice messages go by e-mail).
--   * Roles: moderator (linked to a name from the programme, may host several
--     shows), admin (moderates under a nickname, lifts blocks), superadmin
--     (also invites moderators and manages admins, from the app's Profil).
--   * Archive: before the 90-day clean-up, messages are copied to
--     `chat_archive` without the account or nickname, for the station's
--     analyses. Daily summaries in `chat_daily_stats` / `chat_show_daily`
--     and views `chat_stats_*` (service role only).
--
-- Run after 021. Safe to re-run.

-- ---------------------------------------------------------------------------
-- Columns

alter table profiles add column if not exists registered_at timestamptz;
alter table profiles add column if not exists is_superadmin boolean not null default false;
alter table profiles add column if not exists admin_since timestamptz;
alter table profiles add column if not exists chat_messages_count integer not null default 0;
alter table profiles add column if not exists voice_messages_count integer not null default 0;
alter table profiles add column if not exists first_message_at timestamptz;
alter table chat_hosts add column if not exists linked_at timestamptz;

-- Counters and first message for what already exists.
update profiles p
set chat_messages_count = c.n, first_message_at = coalesce(p.first_message_at, c.first)
from (select user_id, count(*) as n, min(created_at) as first
      from chat_messages where user_id is not null group by user_id) c
where c.user_id = p.id and p.chat_messages_count = 0;

update profiles p
set registered_at = u.created_at
from auth.users u
where u.id = p.id and not coalesce(u.is_anonymous, false) and p.registered_at is null;

update chat_hosts set linked_at = coalesce(linked_at, now()) where user_id is not null;

-- ---------------------------------------------------------------------------
-- Helpers (not callable by clients)

-- Any signed-in user, anonymous ones included.
create or replace function chat_require_user()
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    perform chat_error('not_authenticated');
  end if;
  return uid;
end;
$$;

create or replace function chat_is_anonymous()
returns boolean
language sql
stable
set search_path = public
as $$
  select coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false);
$$;

create or replace function chat_require_superadmin()
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid := chat_require_account();
begin
  if not exists (select 1 from profiles where id = uid and is_superadmin) then
    perform chat_error('not_superadmin');
  end if;
  return uid;
end;
$$;

revoke all on function chat_require_user() from public, anon, authenticated;
revoke all on function chat_is_anonymous() from public, anon, authenticated;
revoke all on function chat_require_superadmin() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- The user

-- Everything Profil and the composer need. Notes the registration date the
-- first time a permanent user asks (so not `stable` any more).
create or replace function chat_me()
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  anon boolean := chat_is_anonymous();
  p profiles;
  h chat_hosts;
  m chat_mutes;
  shows text;
begin
  if uid is null then
    perform chat_error('not_authenticated');
  end if;
  if not anon then
    insert into profiles (id, registered_at) values (uid, now())
    on conflict (id) do update set registered_at = coalesce(profiles.registered_at, now());
  end if;
  select * into p from profiles where id = uid;
  select * into h from chat_hosts where user_id = uid;
  select * into m from chat_mutes where user_id = uid and (until is null or until > now());
  return jsonb_build_object(
    'user_id', uid,
    'is_anonymous', anon,
    'registered_at', p.registered_at,
    'nickname', p.nickname,
    -- Anonymous: the nickname is locked (registration unlocks it). The first
    -- change after registering is free; then once per 24 hours.
    'nickname_locked', anon and p.nickname is not null,
    'nickname_next_change_at',
      case when not anon
            and p.nickname_changed_at is not null
            and p.nickname_changed_at > now() - interval '24 hours'
            and p.registered_at is not null
            and p.nickname_changed_at >= p.registered_at
      then p.nickname_changed_at + interval '24 hours' end,
    'role', case
      when h.host_id is not null then 'dj'
      when p.is_admin then 'admin'
      when p.supporter_until > now() then 'supporter'
      else 'listener' end,
    'host_id', h.host_id,
    'host_name', h.display_name,
    'is_moderator', h.host_id is not null or coalesce(p.is_admin, false),
    'is_admin', coalesce(p.is_admin, false),
    'is_superadmin', coalesce(p.is_superadmin, false),
    'chat_messages_count', coalesce(p.chat_messages_count, 0),
    'voice_messages_count', coalesce(p.voice_messages_count, 0),
    'muted_until', m.until,
    'blocked', m.user_id is not null and m.until is null
  );
end;
$$;

-- Sets or changes the nickname. Anyone signed in (also anonymously) sets the
-- first one; changing it needs a permanent account. The first change after
-- registering is free; after that once per 24 hours.
create or replace function set_nickname(p_nickname text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := chat_require_user();
  anon boolean := chat_is_anonymous();
  nick text := btrim(coalesce(p_nickname, ''));
  key text := chat_name_key(nick);
  p profiles;
begin
  if exists (select 1 from chat_hosts where user_id = uid) then
    perform chat_error('nickname_host');
  end if;
  if nick !~ '^[A-Za-z0-9._]{3,20}$' then
    perform chat_error('nickname_invalid');
  end if;
  if key ~ '^dj'
     or key in ('slowdown', 'slowdownradijo', 'slowdownradio', 'radijo', 'radio', 'moderator',
                'moderatorka', 'admin', 'administrator', 'spravce', 'podpora', 'support', 'system',
                'slowrider', 'slowriders', 'superadmin')
     or exists (select 1 from chat_hosts where chat_name_key(display_name) = key) then
    perform chat_error('nickname_reserved');
  end if;

  select * into p from profiles where id = uid for update;
  if p.nickname = nick then
    return chat_me();
  end if;
  if p.nickname is not null and anon then
    perform chat_error('account_required');
  end if;
  if p.nickname is not null
     and p.nickname_changed_at > now() - interval '24 hours'
     and p.registered_at is not null
     and p.nickname_changed_at >= p.registered_at then
    perform chat_error('nickname_cooldown', (p.nickname_changed_at + interval '24 hours')::text);
  end if;
  if exists (select 1 from profiles where lower(nickname) = lower(nick) and id <> uid) then
    perform chat_error('nickname_taken');
  end if;

  insert into profiles (id, nickname, nickname_changed_at)
  values (uid, nick, now())
  on conflict (id) do update set nickname = excluded.nickname, nickname_changed_at = excluded.nickname_changed_at;

  update chat_messages set author_name = nick where user_id = uid and author_name is distinct from nick;
  return chat_me();
exception when unique_violation then
  perform chat_error('nickname_taken');
end;
$$;

-- Links the caller's account to a moderator from the programme.
create or replace function claim_host_invite(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := chat_require_account();
  inv chat_host_invites;
begin
  select * into inv from chat_host_invites
  where code = lower(btrim(coalesce(p_code, ''))) for update;
  if not found or inv.used_at is not null or inv.expires_at <= now() then
    perform chat_error('invite_invalid');
  end if;
  if exists (select 1 from chat_hosts where user_id = uid and host_id <> inv.host_id) then
    perform chat_error('invite_other_host');
  end if;

  update chat_hosts set user_id = uid, linked_at = now() where host_id = inv.host_id;
  update chat_host_invites set used_by = uid, used_at = now() where code = inv.code;
  return chat_me();
end;
$$;

-- "Hlasové vzkazy" on the dashboard: the app reports a voice message it sent.
create or replace function count_voice_message()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := chat_require_user();
begin
  insert into profiles (id, voice_messages_count) values (uid, 1)
  on conflict (id) do update set voice_messages_count = profiles.voice_messages_count + 1;
end;
$$;

-- ---------------------------------------------------------------------------
-- Writing, now also without an account

create or replace function send_chat_message(p_body text, p_show_id text default null, p_show_title text default null)
returns chat_messages
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := chat_require_user();
  body text := btrim(coalesce(p_body, ''));
  a record;
  m chat_mutes;
  msg chat_messages;
begin
  if char_length(body) < 1 or char_length(body) > 500 then
    perform chat_error('message_invalid');
  end if;
  if p_show_id is not null and p_show_id !~ '^[a-z0-9-]{1,80}$' then
    p_show_id := null;
  end if;
  if p_show_title is not null then
    p_show_title := left(btrim(p_show_title), 120);
  end if;

  select * into m from chat_mutes where user_id = uid and (until is null or until > now());
  if found then
    if m.until is null then
      perform chat_error('blocked');
    end if;
    perform chat_error('muted', m.until::text);
  end if;

  select * into a from chat_author(uid);
  if a.name is null then
    perform chat_error('nickname_required');
  end if;

  if (select count(*) from chat_messages where user_id = uid and created_at > now() - interval '30 seconds') >= 5
     or (select count(*) from chat_messages where user_id = uid and created_at > now() - interval '1 hour') >= 60 then
    perform chat_error('rate_limited');
  end if;

  insert into chat_messages (user_id, author_name, author_role, body, show_id, show_title)
  values (uid, a.name, a.role, body, p_show_id, nullif(p_show_title, ''))
  returning * into msg;

  update profiles
  set chat_messages_count = chat_messages_count + 1,
      first_message_at = coalesce(first_message_at, now())
  where id = uid;
  return msg;
end;
$$;

-- Reporting and hiding work without an account too.
create or replace function report_chat_message(p_message_id bigint, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := chat_require_user();
begin
  if not exists (select 1 from chat_messages where id = p_message_id) then
    perform chat_error('message_not_found');
  end if;
  insert into chat_reports (message_id, reporter_id, reason)
  values (p_message_id, uid, nullif(left(btrim(coalesce(p_reason, '')), 500), ''))
  on conflict (message_id, reporter_id) do nothing;
end;
$$;

create or replace function hide_chat_user(p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := chat_require_user();
begin
  if p_user is null or p_user = uid then
    perform chat_error('user_invalid');
  end if;
  insert into chat_hidden_users (user_id, hidden_user_id) values (uid, p_user)
  on conflict do nothing;
end;
$$;

create or replace function unhide_chat_user(p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := chat_require_user();
begin
  delete from chat_hidden_users where user_id = uid and hidden_user_id = p_user;
end;
$$;

-- ---------------------------------------------------------------------------
-- Superadmin: moderators and admins, from the app's Profil

-- Everything the "Správa chatu" screens show.
create or replace function admin_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid := chat_require_superadmin();
begin
  return jsonb_build_object(
    'hosts', coalesce((
      select jsonb_agg(jsonb_build_object(
        'host_id', h.host_id,
        'display_name', h.display_name,
        'linked', h.user_id is not null,
        'linked_at', h.linked_at,
        'invite_expires_at', (select max(i.expires_at) from chat_host_invites i
                              where i.host_id = h.host_id and i.used_at is null and i.expires_at > now())
      ) order by h.display_name)
      from chat_hosts h), '[]'::jsonb),
    'admins', coalesce((
      select jsonb_agg(jsonb_build_object(
        'user_id', p.id,
        'nickname', p.nickname,
        'is_superadmin', p.is_superadmin,
        'admin_since', p.admin_since,
        'is_me', p.id = uid
      ) order by p.is_superadmin desc, p.admin_since)
      from profiles p where p.is_admin or p.is_superadmin), '[]'::jsonb)
  );
end;
$$;

-- A one-off link for a moderator from the programme (or a guest host).
-- Earlier unused links for the same moderator stop working.
create or replace function admin_create_host_invite(p_host_id text, p_display_name text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := chat_require_superadmin();
  hid text := lower(btrim(coalesce(p_host_id, '')));
  name text := btrim(coalesce(p_display_name, ''));
  inv chat_host_invites;
begin
  if hid !~ '^[a-z0-9-]{1,80}$' or char_length(name) not between 2 and 60 then
    perform chat_error('host_invalid');
  end if;
  insert into chat_hosts (host_id, display_name) values (hid, name)
  on conflict (host_id) do update set display_name = excluded.display_name;
  update chat_host_invites set expires_at = now()
  where host_id = hid and used_at is null and expires_at > now();
  insert into chat_host_invites (host_id) values (hid) returning * into inv;
  return jsonb_build_object('code', inv.code, 'expires_at', inv.expires_at, 'host_id', hid);
end;
$$;

-- The moderator writes under their nickname again, without the badge.
create or replace function admin_unlink_host(p_host_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := chat_require_superadmin();
begin
  update chat_hosts set user_id = null, linked_at = null where host_id = p_host_id;
  update chat_host_invites set expires_at = now()
  where host_id = p_host_id and used_at is null and expires_at > now();
end;
$$;

-- Nicknames for "Přidat správce"; only registered Slowriders can be chosen.
create or replace function admin_find_users(p_query text)
returns table (user_id uuid, nickname text, registered_at timestamptz, is_admin boolean)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid := chat_require_superadmin();
  q text := btrim(coalesce(p_query, ''));
begin
  if char_length(q) < 2 then
    return;
  end if;
  return query
    select p.id, p.nickname, p.registered_at, p.is_admin
    from profiles p
    where p.nickname ilike replace(replace(q, '%', ''), '_', '\_') || '%'
    order by p.registered_at is null, lower(p.nickname)
    limit 10;
end;
$$;

create or replace function admin_set_admin(p_user uuid, p_on boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := chat_require_superadmin();
  p profiles;
begin
  select * into p from profiles where id = p_user for update;
  if not found or p.registered_at is null or p_user = uid or p.is_superadmin then
    perform chat_error('user_invalid');
  end if;
  update profiles
  set is_admin = p_on, admin_since = case when p_on then coalesce(admin_since, now()) end
  where id = p_user;
end;
$$;

-- ---------------------------------------------------------------------------
-- Archive and statistics (service role only: the station's analyses)

create table if not exists chat_archive (
  id bigint primary key,
  -- No account and no nickname: the archive is not linked to anyone.
  author_role text not null,
  body text,
  show_id text,
  show_title text,
  created_at timestamptz not null,
  was_deleted boolean not null default false,
  archived_at timestamptz not null default now()
);
create index if not exists chat_archive_created_idx on chat_archive (created_at);
alter table chat_archive enable row level security;

create table if not exists chat_daily_stats (
  day date primary key,
  messages integer not null,
  emoji_messages integer not null,
  writers integer not null,
  new_writers integer not null,
  anonymous_writers integer not null,
  deleted integer not null,
  reports integer not null,
  mutes integer not null,
  collected_at timestamptz not null default now()
);
alter table chat_daily_stats enable row level security;

create table if not exists chat_show_daily (
  day date not null,
  show_id text not null,
  show_title text,
  messages integer not null,
  writers integer not null,
  primary key (day, show_id)
);
alter table chat_show_daily enable row level security;

-- A message that is only emoji (no letters or digits, a few characters).
create or replace function chat_is_emoji(p_body text)
returns boolean
language sql
immutable
set search_path = public
as $$
  select p_body is not null and char_length(btrim(p_body)) between 1 and 8 and p_body !~ '[[:alnum:]]';
$$;

-- One day's numbers (Prague calendar day); yesterday by default. Re-running
-- a day replaces it.
create or replace function chat_collect_daily(p_day date default ((now() at time zone 'Europe/Prague')::date - 1))
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  from_ts timestamptz := (p_day::timestamp at time zone 'Europe/Prague');
  to_ts timestamptz := ((p_day + 1)::timestamp at time zone 'Europe/Prague');
begin
  insert into chat_daily_stats (day, messages, emoji_messages, writers, new_writers, anonymous_writers, deleted, reports, mutes, collected_at)
  select p_day,
         count(*),
         count(*) filter (where chat_is_emoji(m.body)),
         count(distinct m.user_id),
         (select count(*) from profiles p where p.first_message_at >= from_ts and p.first_message_at < to_ts),
         count(distinct m.user_id) filter (where pr.registered_at is null),
         count(*) filter (where m.deleted_at is not null),
         (select count(*) from chat_reports r where r.created_at >= from_ts and r.created_at < to_ts),
         (select count(*) from chat_mutes x where x.created_at >= from_ts and x.created_at < to_ts),
         now()
  from chat_messages m
  left join profiles pr on pr.id = m.user_id
  where m.created_at >= from_ts and m.created_at < to_ts
  on conflict (day) do update set
    messages = excluded.messages, emoji_messages = excluded.emoji_messages, writers = excluded.writers,
    new_writers = excluded.new_writers, anonymous_writers = excluded.anonymous_writers,
    deleted = excluded.deleted, reports = excluded.reports, mutes = excluded.mutes, collected_at = now();

  delete from chat_show_daily where day = p_day;
  insert into chat_show_daily (day, show_id, show_title, messages, writers)
  select p_day, coalesce(m.show_id, '_'), max(m.show_title), count(*), count(distinct m.user_id)
  from chat_messages m
  where m.created_at >= from_ts and m.created_at < to_ts
  group by coalesce(m.show_id, '_');
end;
$$;

-- Clean-up, now archiving first.
create or replace function prune_chat()
returns void
language sql
security definer
set search_path = public
as $$
  insert into chat_archive (id, author_role, body, show_id, show_title, created_at, was_deleted)
  select id, author_role, body, show_id, show_title, created_at, deleted_at is not null
  from chat_messages where created_at < now() - interval '90 days'
  on conflict (id) do nothing;
  delete from chat_messages where created_at < now() - interval '90 days';
  delete from chat_deleted_bodies where deleted_at < now() - interval '1 day';
  delete from chat_mutes where until is not null and until < now() - interval '30 days';
  delete from chat_host_invites where expires_at < now() - interval '30 days';
$$;

-- Views for the analyses (docs/chat-concept.md, "Statistiky chatu").

create or replace view chat_stats_daily as
  select day, messages, emoji_messages, writers, new_writers, anonymous_writers,
         round(messages::numeric / nullif(writers, 0), 2) as avg_per_writer,
         deleted, reports, mutes
  from chat_daily_stats;

-- Shows over the last 30 days, with messages per 100 listeners of the show.
create or replace view chat_stats_shows_30d as
  with chat as (
    select show_id, max(show_title) as show_title, sum(messages) as messages, sum(writers) as writer_days
    from chat_show_daily where day >= current_date - 30 group by show_id
  ), listening as (
    select show_id, count(distinct listener_id) as listeners, sum(seconds) / 3600.0 as hours
    from listening_daily where day >= current_date - 30 group by show_id
  )
  select c.show_id, c.show_title, c.messages, c.writer_days, l.listeners,
         round(c.messages * 100.0 / nullif(l.listeners, 0), 1) as messages_per_100_listeners
  from chat c left join listening l using (show_id)
  order by c.messages desc;

-- When people write: day of week (1 = Monday) × hour, Prague time, last 30 days.
create or replace view chat_stats_heatmap_30d as
  select extract(isodow from created_at at time zone 'Europe/Prague')::int as weekday,
         extract(hour from created_at at time zone 'Europe/Prague')::int as hour,
         count(*) as messages
  from chat_messages
  where created_at >= now() - interval '30 days' and deleted_at is null
  group by 1, 2;

-- New writers per week and how many wrote again within 7 and 30 days.
create or replace view chat_stats_retention as
  with firsts as (
    select id, first_message_at from profiles where first_message_at is not null
  )
  select date_trunc('week', f.first_message_at at time zone 'Europe/Prague')::date as week,
         count(*) as new_writers,
         count(*) filter (where exists (select 1 from chat_messages m where m.user_id = f.id
           and m.created_at > f.first_message_at + interval '1 hour'
           and m.created_at <= f.first_message_at + interval '7 days')) as returned_7d,
         count(*) filter (where exists (select 1 from chat_messages m where m.user_id = f.id
           and m.created_at > f.first_message_at + interval '1 hour'
           and m.created_at <= f.first_message_at + interval '30 days')) as returned_30d,
         count(*) filter (where p.registered_at is not null) as registered
  from firsts f join profiles p on p.id = f.id
  group by 1 order by 1 desc;

-- Share of messages from the most active 10 % of writers, last 30 days.
create or replace view chat_stats_concentration_30d as
  with per_user as (
    select user_id, count(*) as n from chat_messages
    where created_at >= now() - interval '30 days' and user_id is not null group by user_id
  ), ranked as (
    select n, ntile(10) over (order by n desc) as decile from per_user
  )
  select round(100.0 * sum(n) filter (where decile = 1) / nullif(sum(n), 0), 1) as top10_share_pct,
         percentile_cont(0.5) within group (order by n) as median_per_writer,
         round(avg(n), 2) as avg_per_writer,
         count(*) as writers
  from ranked;

-- ---------------------------------------------------------------------------
-- Grants

revoke all on chat_archive, chat_daily_stats, chat_show_daily from anon, authenticated;
revoke all on chat_stats_daily, chat_stats_shows_30d, chat_stats_heatmap_30d,
              chat_stats_retention, chat_stats_concentration_30d from anon, authenticated;
revoke all on function chat_is_emoji(text) from public, anon, authenticated;
revoke all on function chat_collect_daily(date) from public, anon, authenticated;
revoke all on function prune_chat() from public, anon, authenticated;

do $$
declare
  f text;
begin
  foreach f in array array[
    'chat_me()', 'set_nickname(text)', 'claim_host_invite(text)', 'count_voice_message()',
    'send_chat_message(text, text, text)', 'report_chat_message(bigint, text)',
    'hide_chat_user(uuid)', 'unhide_chat_user(uuid)',
    'admin_overview()', 'admin_create_host_invite(text, text)', 'admin_unlink_host(text)',
    'admin_find_users(text)', 'admin_set_admin(uuid, boolean)'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;

-- Daily numbers at 03:10, before the clean-up at 03:20.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('chat-daily-stats', '10 3 * * *', 'select public.chat_collect_daily()');
  end if;
end $$;

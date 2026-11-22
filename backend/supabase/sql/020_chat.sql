-- Chat for listeners and DJs (app 1.3, iOS and Android).
--
-- Design: Figma "Slow Down Rádijo", pages Chat and Profil. Rules:
-- docs/chat-concept.md. Plan: docs/chat-implementation.md.
--
--   * One room for the whole radio. Every message carries the show it was
--     written in (`show_id`, `show_title`, sent by the app, which already knows
--     the programme — the server never needs the schedule, as with the
--     listening stats). The apps draw the "Dnes · 07:00 Morning Coffee"
--     dividers from it.
--   * Anyone can read. Writing needs a permanent account (Apple, Google or
--     e-mail) — anonymous stats users can't write until they sign in, which
--     upgrades that same user (`auth.users.is_anonymous` → false), so their
--     stats stay.
--   * A listener writes under a nickname (3–20 chars, a–z A–Z 0–9 . _, unique
--     regardless of case, changeable once per 24 h). A DJ writes under their
--     name from the programme (`chat_hosts.display_name`), linked to their
--     account by a one-off invite code.
--   * Moderators (DJs and admins) delete messages (undo within 10 min), pin
--     one message, mute a listener for 1 h / 24 h / 7 days, or block them.
--     Anyone can report a message or hide a listener for themselves.
--
-- Everything is written through the security-definer functions below; the
-- tables have row level security with no write policies. Messages are
-- readable by everyone (also over Realtime); the other tables are not
-- readable at all.
--
-- Errors are raised with a stable code in the message (`nickname_taken`,
-- `muted`, …) that the apps map to their texts; see `chat_error` at the top.
--
-- Run after 019. Safe to re-run.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Tables

create table if not exists profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  nickname text,
  nickname_changed_at timestamptz,
  is_admin boolean not null default false,
  -- Paid supporter account (later): set by the server from store
  -- notifications, never by the app.
  supporter_until timestamptz,
  created_at timestamptz not null default now()
);
create unique index if not exists profiles_nickname_lower_idx on profiles (lower(nickname));

-- DJs who can write in the chat under their programme name. `host_id` is the
-- host's id from the app's catalogue (e.g. `dj-pufaz`); rows are added by
-- hand in the Table Editor.
create table if not exists chat_hosts (
  host_id text primary key,
  display_name text not null,
  user_id uuid unique references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);
create unique index if not exists chat_hosts_display_name_lower_idx on chat_hosts (lower(display_name));

create table if not exists chat_host_invites (
  code text primary key default encode(gen_random_bytes(6), 'hex'),
  host_id text not null references chat_hosts (host_id) on delete cascade,
  expires_at timestamptz not null default now() + interval '7 days',
  used_by uuid references auth.users (id) on delete set null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists chat_messages (
  id bigint generated always as identity primary key,
  -- Null once the author deleted their account ("Smazaný účet" in the apps).
  user_id uuid references auth.users (id) on delete set null,
  -- Current name of the author, kept up to date when the nickname changes;
  -- null for a deleted account.
  author_name text,
  author_role text not null default 'listener'
    check (author_role in ('listener', 'supporter', 'dj', 'admin')),
  -- Null once deleted by a moderator.
  body text,
  show_id text,
  show_title text,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_by uuid references auth.users (id) on delete set null,
  pinned_at timestamptz,
  check (deleted_at is not null or char_length(body) between 1 and 500)
);
create index if not exists chat_messages_created_idx on chat_messages (created_at desc);
create index if not exists chat_messages_user_created_idx on chat_messages (user_id, created_at desc);
create index if not exists chat_messages_pinned_idx on chat_messages (pinned_at) where pinned_at is not null;

-- The text of a deleted message, for "Vrátit" (10 minutes), then purged.
create table if not exists chat_deleted_bodies (
  message_id bigint primary key references chat_messages (id) on delete cascade,
  body text not null,
  was_pinned_at timestamptz,
  deleted_at timestamptz not null default now()
);

-- Muted (`until` in the future) or blocked (`until` null) listeners.
create table if not exists chat_mutes (
  user_id uuid primary key references auth.users (id) on delete cascade,
  until timestamptz,
  muted_by uuid references auth.users (id) on delete set null,
  message_id bigint references chat_messages (id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists chat_reports (
  id bigint generated always as identity primary key,
  message_id bigint not null references chat_messages (id) on delete cascade,
  reporter_id uuid not null references auth.users (id) on delete cascade,
  reason text check (reason is null or char_length(reason) <= 500),
  created_at timestamptz not null default now(),
  unique (message_id, reporter_id)
);

-- "Skrýt zprávy od…": only the hider stops seeing them.
create table if not exists chat_hidden_users (
  user_id uuid not null references auth.users (id) on delete cascade,
  hidden_user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, hidden_user_id)
);

alter table profiles enable row level security;
alter table chat_hosts enable row level security;
alter table chat_host_invites enable row level security;
alter table chat_messages enable row level security;
alter table chat_deleted_bodies enable row level security;
alter table chat_mutes enable row level security;
alter table chat_reports enable row level security;
alter table chat_hidden_users enable row level security;

-- Messages: readable by everyone, written only through the functions below.
drop policy if exists chat_messages_read on chat_messages;
create policy chat_messages_read on chat_messages for select to anon, authenticated using (true);
revoke insert, update, delete, truncate on chat_messages from anon, authenticated;

-- Live updates for the apps (new, deleted, pinned, renamed messages).
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables
                     where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'chat_messages') then
    alter publication supabase_realtime add table chat_messages;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Helpers (not callable by clients)

create or replace function chat_error(p_code text, p_detail text default null)
returns void
language plpgsql
set search_path = public
as $$
begin
  raise exception '%', p_code using errcode = 'P0001', detail = coalesce(p_detail, '');
end;
$$;

-- A signed-in, permanent (non-anonymous) user, or an error.
create or replace function chat_require_account()
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
  if coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    perform chat_error('account_required');
  end if;
  return uid;
end;
$$;

create or replace function chat_is_moderator(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from chat_hosts h where h.user_id = p_user)
      or exists (select 1 from profiles p where p.id = p_user and p.is_admin);
$$;

-- Letters and digits only, lower case: "DJ Pufaz" and "dj.pufaz" compare equal.
create or replace function chat_name_key(p_name text)
returns text
language sql
immutable
set search_path = public
as $$
  select regexp_replace(lower(coalesce(p_name, '')), '[^a-z0-9]', '', 'g');
$$;

-- The author's name and badge for a new message (null name: no nickname yet).
create or replace function chat_author(p_user uuid, out name text, out role text)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  p profiles;
  h chat_hosts;
begin
  select * into h from chat_hosts where user_id = p_user;
  if found then
    name := h.display_name;
    role := 'dj';
    return;
  end if;
  select * into p from profiles where id = p_user;
  name := p.nickname;
  role := case
    when p.is_admin then 'admin'
    when p.supporter_until > now() then 'supporter'
    else 'listener'
  end;
end;
$$;

revoke all on function chat_error(text, text) from public, anon, authenticated;
revoke all on function chat_require_account() from public, anon, authenticated;
revoke all on function chat_is_moderator(uuid) from public, anon, authenticated;
revoke all on function chat_author(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- The signed-in user

-- Everything the apps need to draw Profil and the chat composer.
create or replace function chat_me()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  p profiles;
  h chat_hosts;
  m chat_mutes;
begin
  if uid is null then
    perform chat_error('not_authenticated');
  end if;
  select * into p from profiles where id = uid;
  select * into h from chat_hosts where user_id = uid;
  select * into m from chat_mutes where user_id = uid and (until is null or until > now());
  return jsonb_build_object(
    'user_id', uid,
    'is_anonymous', coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false),
    'nickname', p.nickname,
    'nickname_next_change_at',
      case when p.nickname_changed_at is not null
           and p.nickname_changed_at > now() - interval '24 hours'
      then p.nickname_changed_at + interval '24 hours' end,
    'role', case
      when h.host_id is not null then 'dj'
      when p.is_admin then 'admin'
      when p.supporter_until > now() then 'supporter'
      else 'listener' end,
    'host_id', h.host_id,
    'host_name', h.display_name,
    'is_moderator', h.host_id is not null or coalesce(p.is_admin, false),
    'muted_until', m.until,
    'blocked', m.user_id is not null and m.until is null
  );
end;
$$;

-- Sets or changes the nickname. The first one is free; after that once per
-- 24 hours. Past messages take the new name.
create or replace function set_nickname(p_nickname text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := chat_require_account();
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
                'moderatorka', 'admin', 'administrator', 'spravce', 'podpora', 'support', 'system')
     or exists (select 1 from chat_hosts where chat_name_key(display_name) = key) then
    perform chat_error('nickname_reserved');
  end if;

  select * into p from profiles where id = uid for update;
  if p.nickname = nick then
    return chat_me();
  end if;
  if p.nickname_changed_at > now() - interval '24 hours' and p.nickname is not null then
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

-- Is this nickname free (and allowed) — for the live check while typing.
create or replace function nickname_available(p_nickname text)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  nick text := btrim(coalesce(p_nickname, ''));
  key text := chat_name_key(nick);
begin
  if nick !~ '^[A-Za-z0-9._]{3,20}$' then return 'nickname_invalid'; end if;
  if key ~ '^dj'
     or key in ('slowdown', 'slowdownradijo', 'slowdownradio', 'radijo', 'radio', 'moderator',
                'moderatorka', 'admin', 'administrator', 'spravce', 'podpora', 'support', 'system')
     or exists (select 1 from chat_hosts where chat_name_key(display_name) = key) then
    return 'nickname_reserved';
  end if;
  if exists (select 1 from profiles where lower(nickname) = lower(nick)
             and id is distinct from auth.uid()) then
    return 'nickname_taken';
  end if;
  return 'ok';
end;
$$;

-- Links the caller's account to a DJ from the programme.
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

  update chat_hosts set user_id = uid where host_id = inv.host_id;
  update chat_host_invites set used_by = uid, used_at = now() where code = inv.code;
  -- Messages written before under a nickname keep it; new ones use the DJ name.
  return chat_me();
end;
$$;

-- Deletes the account: chat messages stay as "Smazaný účet", everything
-- else (profile, stats, hidden users, reports) goes with the auth user.
create or replace function delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    perform chat_error('not_authenticated');
  end if;
  update chat_messages set author_name = null, author_role = 'listener' where user_id = uid;
  update chat_hosts set user_id = null where user_id = uid;
  delete from listeners where id = uid;
  delete from profiles where id = uid;
  begin
    delete from auth.users where id = uid;
  exception when insufficient_privilege then
    raise warning 'auth user not deleted: %', sqlerrm;
  end;
end;
$$;

-- ---------------------------------------------------------------------------
-- Writing

create or replace function send_chat_message(p_body text, p_show_id text default null, p_show_title text default null)
returns chat_messages
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := chat_require_account();
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
  return msg;
end;
$$;

create or replace function report_chat_message(p_message_id bigint, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := chat_require_account();
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
  uid uuid := chat_require_account();
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
  uid uuid := chat_require_account();
begin
  delete from chat_hidden_users where user_id = uid and hidden_user_id = p_user;
end;
$$;

create or replace function my_hidden_chat_users()
returns table (user_id uuid, name text)
language sql
stable
security definer
set search_path = public
as $$
  select hu.hidden_user_id,
         coalesce(h.display_name, p.nickname)
  from chat_hidden_users hu
  left join profiles p on p.id = hu.hidden_user_id
  left join chat_hosts h on h.user_id = hu.hidden_user_id
  where hu.user_id = auth.uid()
  order by hu.created_at desc;
$$;

-- ---------------------------------------------------------------------------
-- Moderation (DJs and admins)

create or replace function chat_require_moderator()
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid := chat_require_account();
begin
  if not chat_is_moderator(uid) then
    perform chat_error('not_moderator');
  end if;
  return uid;
end;
$$;
revoke all on function chat_require_moderator() from public, anon, authenticated;

create or replace function delete_chat_message(p_message_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := chat_require_moderator();
  msg chat_messages;
begin
  select * into msg from chat_messages where id = p_message_id for update;
  if not found then
    perform chat_error('message_not_found');
  end if;
  if msg.deleted_at is not null then
    return;
  end if;
  insert into chat_deleted_bodies (message_id, body, was_pinned_at)
  values (msg.id, msg.body, msg.pinned_at)
  on conflict (message_id) do update set body = excluded.body, was_pinned_at = excluded.was_pinned_at, deleted_at = now();
  update chat_messages
  set body = null, deleted_at = now(), deleted_by = uid, pinned_at = null
  where id = msg.id;
end;
$$;

-- "Vrátit" after a deletion, within 10 minutes.
create or replace function restore_chat_message(p_message_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := chat_require_moderator();
  d chat_deleted_bodies;
begin
  select * into d from chat_deleted_bodies where message_id = p_message_id;
  if not found or d.deleted_at < now() - interval '10 minutes' then
    perform chat_error('restore_expired');
  end if;
  update chat_messages
  set body = d.body, deleted_at = null, deleted_by = null,
      pinned_at = case when d.was_pinned_at is not null
                        and not exists (select 1 from chat_messages where pinned_at is not null)
                       then d.was_pinned_at end
  where id = p_message_id;
  delete from chat_deleted_bodies where message_id = p_message_id;
end;
$$;

-- One pinned message at a time; pinning another replaces it.
create or replace function pin_chat_message(p_message_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := chat_require_moderator();
begin
  if not exists (select 1 from chat_messages where id = p_message_id and deleted_at is null) then
    perform chat_error('message_not_found');
  end if;
  update chat_messages set pinned_at = null where pinned_at is not null and id <> p_message_id;
  update chat_messages set pinned_at = now() where id = p_message_id;
end;
$$;

create or replace function unpin_chat_message()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := chat_require_moderator();
begin
  update chat_messages set pinned_at = null where pinned_at is not null;
end;
$$;

-- Mute for 60, 1440 or 10080 minutes. Moderators can't be muted.
create or replace function mute_chat_user(p_user uuid, p_minutes integer, p_message_id bigint default null)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := chat_require_moderator();
  until_at timestamptz;
begin
  if p_minutes not in (60, 1440, 10080) then
    perform chat_error('mute_invalid');
  end if;
  if p_user is null or p_user = uid or chat_is_moderator(p_user) then
    perform chat_error('user_invalid');
  end if;
  if exists (select 1 from chat_mutes where user_id = p_user and until is null) then
    perform chat_error('blocked');
  end if;
  until_at := now() + make_interval(mins => p_minutes);
  insert into chat_mutes (user_id, until, muted_by, message_id, created_at)
  values (p_user, until_at, uid, p_message_id, now())
  on conflict (user_id) do update
    set until = excluded.until, muted_by = excluded.muted_by,
        message_id = excluded.message_id, created_at = excluded.created_at;
  return until_at;
end;
$$;

-- Ends a mute early. A block can only be lifted by an admin.
create or replace function unmute_chat_user(p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := chat_require_moderator();
  m chat_mutes;
begin
  select * into m from chat_mutes where user_id = p_user;
  if not found then
    return;
  end if;
  if m.until is null and not exists (select 1 from profiles where id = uid and is_admin) then
    perform chat_error('not_admin');
  end if;
  delete from chat_mutes where user_id = p_user;
end;
$$;

create or replace function block_chat_user(p_user uuid, p_message_id bigint default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := chat_require_moderator();
begin
  if p_user is null or p_user = uid or chat_is_moderator(p_user) then
    perform chat_error('user_invalid');
  end if;
  insert into chat_mutes (user_id, until, muted_by, message_id, created_at)
  values (p_user, null, uid, p_message_id, now())
  on conflict (user_id) do update
    set until = null, muted_by = excluded.muted_by,
        message_id = excluded.message_id, created_at = excluded.created_at;
end;
$$;

-- For the moderator's message menu: "Ztlumený do … · ztlumil DJ Pufaz".
create or replace function chat_user_status(p_user uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid := chat_require_moderator();
  m chat_mutes;
  by_name text;
begin
  select * into m from chat_mutes where user_id = p_user and (until is null or until > now());
  if not found then
    return jsonb_build_object('muted_until', null, 'blocked', false, 'muted_by', null);
  end if;
  select coalesce(h.display_name, p.nickname) into by_name
  from (select m.muted_by as id) x
  left join chat_hosts h on h.user_id = x.id
  left join profiles p on p.id = x.id;
  return jsonb_build_object('muted_until', m.until, 'blocked', m.until is null, 'muted_by', by_name);
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants

do $$
declare
  f text;
begin
  foreach f in array array[
    'chat_me()', 'set_nickname(text)', 'nickname_available(text)', 'claim_host_invite(text)',
    'delete_my_account()', 'send_chat_message(text, text, text)', 'report_chat_message(bigint, text)',
    'hide_chat_user(uuid)', 'unhide_chat_user(uuid)', 'my_hidden_chat_users()',
    'delete_chat_message(bigint)', 'restore_chat_message(bigint)', 'pin_chat_message(bigint)',
    'unpin_chat_message()', 'mute_chat_user(uuid, integer, bigint)', 'unmute_chat_user(uuid)',
    'block_chat_user(uuid, bigint)', 'chat_user_status(uuid)'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Retention (privacy policy): messages for 90 days, the text of a deleted
-- message for a day (undo needs 10 minutes), expired invites for 30 days.

create or replace function prune_chat()
returns void
language sql
security definer
set search_path = public
as $$
  delete from chat_messages where created_at < now() - interval '90 days';
  delete from chat_deleted_bodies where deleted_at < now() - interval '1 day';
  delete from chat_mutes where until is not null and until < now() - interval '30 days';
  delete from chat_host_invites where expires_at < now() - interval '30 days';
$$;
revoke all on function prune_chat() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('prune-chat', '20 3 * * *', 'select public.prune_chat()');
  end if;
end $$;

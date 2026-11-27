-- Chat replies (app 1.4, Figma Chat ▸ "Chat 1.4 — Odpovědi na zprávy").
--
-- A message can answer one earlier message. The apps draw a one-line quote
-- ("karolina.pivnivila · Výsadba nové chmelnice…") above the reply, joined
-- to the replier's name by a short curved line; no threads.
--
-- The quote travels with the reply (reply_to_author / _role / _body /
-- _user_id), so the stream, Realtime and old app versions need nothing
-- extra. It stays live: renaming, deleting the account, a moderator's
-- deletion (and "Vrátit") and the 90-day clean-up all update the quotes
-- of the replies (chat_sync_reply_quotes). A quote with reply_to_id set and
-- no body means "Původní zpráva už tu není".
--
-- send_chat_message gets p_reply_to (default null): old apps keep calling
-- it with three named arguments.
--
-- Run after 029 (029_period_ranking, 029_admin_find_hosts). Safe to re-run.

alter table chat_messages
  add column if not exists reply_to_id bigint,
  add column if not exists reply_to_user_id uuid,
  add column if not exists reply_to_author text,
  add column if not exists reply_to_role text,
  add column if not exists reply_to_body text;

create index if not exists chat_messages_reply_to_idx on chat_messages (reply_to_id) where reply_to_id is not null;

-- How much of the original the quote keeps (the apps show one line).
create or replace function chat_reply_excerpt(p_body text)
returns text
language sql
immutable
as $$
  select case when p_body is null then null else left(regexp_replace(btrim(p_body), '\s+', ' ', 'g'), 140) end
$$;

-- ---------------------------------------------------------------------------
-- Sending, now with an optional reply

drop function if exists send_chat_message(text, text, text);

create or replace function send_chat_message(
  p_body text,
  p_show_id text default null,
  p_show_title text default null,
  p_reply_to bigint default null
)
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
  original chat_messages;
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

  if p_reply_to is not null then
    select * into original from chat_messages where id = p_reply_to;
    if not found or original.deleted_at is not null or original.body is null then
      perform chat_error('reply_unavailable');
    end if;
  end if;

  insert into chat_messages (user_id, author_name, author_role, body, show_id, show_title,
                             reply_to_id, reply_to_user_id, reply_to_author, reply_to_role, reply_to_body)
  values (uid, a.name, a.role, body, p_show_id, nullif(p_show_title, ''),
          original.id, original.user_id, original.author_name, original.author_role,
          chat_reply_excerpt(original.body))
  returning * into msg;

  update profiles
  set chat_messages_count = chat_messages_count + 1,
      first_message_at = coalesce(first_message_at, now())
  where id = uid;
  return msg;
end;
$$;

-- ---------------------------------------------------------------------------
-- Keeping quotes live

create or replace function chat_sync_reply_quotes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    update chat_messages
    set reply_to_body = null, reply_to_author = null, reply_to_role = null, reply_to_user_id = null
    where reply_to_id = old.id and reply_to_body is not null;
    return old;
  end if;

  update chat_messages
  set reply_to_body = case when new.deleted_at is null then chat_reply_excerpt(new.body) end,
      reply_to_author = new.author_name,
      reply_to_role = new.author_role
  where reply_to_id = new.id;
  return new;
end;
$$;

revoke all on function chat_sync_reply_quotes() from public, anon, authenticated;

drop trigger if exists chat_messages_reply_quotes on chat_messages;
create trigger chat_messages_reply_quotes
  after update of body, deleted_at, author_name, author_role on chat_messages
  for each row
  when (old.body is distinct from new.body
        or old.deleted_at is distinct from new.deleted_at
        or old.author_name is distinct from new.author_name
        or old.author_role is distinct from new.author_role)
  execute function chat_sync_reply_quotes();

drop trigger if exists chat_messages_reply_quotes_delete on chat_messages;
create trigger chat_messages_reply_quotes_delete
  before delete on chat_messages
  for each row execute function chat_sync_reply_quotes();

-- ---------------------------------------------------------------------------
-- Grants

do $$
begin
  revoke all on function send_chat_message(text, text, text, bigint) from public, anon, authenticated;
  grant execute on function send_chat_message(text, text, text, bigint) to authenticated;
  revoke all on function chat_reply_excerpt(text) from public, anon, authenticated;
end $$;

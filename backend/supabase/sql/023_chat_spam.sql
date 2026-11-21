-- Chat spam rules (app 1.3), on top of the limits in send_chat_message
-- (5 messages in 30 s, 60 in an hour, 1–500 characters):
--
--   * The same text from the same person within a minute is refused
--     (`duplicate_message`). A single emoji is exempt: sending 🔥 again is
--     how the chat says "me too" (the apps merge it into "🔥 ×4").
--   * Links need an account (`links_need_account`): a listener writing
--     without one can't post a web address. Spam bots almost always do.
--
-- A trigger on chat_messages, so send_chat_message stays as 022 left it.
-- Run after 022. Safe to re-run.

create or replace function chat_check_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.body is null then
    return new;
  end if;

  if not chat_is_emoji(new.body)
     and exists (
       select 1 from chat_messages
       where user_id = new.user_id
         and body = new.body
         and deleted_at is null
         and created_at > now() - interval '1 minute'
     ) then
    perform chat_error('duplicate_message');
  end if;

  if chat_is_anonymous()
     and new.body ~* '(https?://|www\.|\m[a-z0-9-]+\.(cz|sk|com|net|org|eu|io|me|ly|gg|tv|app|info|shop|store|xyz|ru|top|link|site|online|club)\M)' then
    perform chat_error('links_need_account');
  end if;

  return new;
end;
$$;

revoke all on function chat_check_message() from public, anon, authenticated;

drop trigger if exists chat_messages_check on chat_messages;
create trigger chat_messages_check
  before insert on chat_messages
  for each row execute function chat_check_message();

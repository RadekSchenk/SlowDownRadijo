-- Chat (app 1.3), phase 5: what a DJ invite link is for, before signing in.
--
-- The invite screen (Figma "P1 · DJ — pozvánka") shows "Propoj účet jako
-- DJ Pufaz" and "Pozvánka platí do 24. 11." while the DJ is still signed
-- out, so this is callable by anyone holding the code. The code itself is
-- the secret (12 hex characters, one use, 7 days); nothing else is revealed.
-- Returns null for an unknown, used or expired code.

create or replace function host_invite_info(p_code text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object('host_name', h.display_name, 'expires_at', i.expires_at)
  from chat_host_invites i
  join chat_hosts h on h.host_id = i.host_id
  where i.code = lower(btrim(coalesce(p_code, '')))
    and i.used_at is null
    and i.expires_at > now();
$$;

revoke all on function host_invite_info(text) from public, anon, authenticated;
grant execute on function host_invite_info(text) to anon, authenticated;

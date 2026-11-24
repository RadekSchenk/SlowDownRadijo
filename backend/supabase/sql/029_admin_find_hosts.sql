-- "Přidat správce" also finds moderators linked by an invite (1.3).
--
-- A linked moderator has no nickname: they write under the name from the
-- programme (`chat_hosts.display_name`, e.g. "DJ Pufaz"), and set_nickname
-- refuses them. admin_find_users only looked at `profiles.nickname`, so such
-- an account could never be found and made an admin.
--
--   * admin_find_users matches the nickname or the moderator's name, from
--     its start or the start of any word ("pu" finds "DJ Pufaz"), and
--     returns the moderator's name in `nickname` (the apps read it as is).
--   * admin_overview shows the moderator's name in the list of admins too.
--
-- Only the two functions change; same columns, same rights. Run after 028;
-- safe to re-run.

create or replace function admin_find_users(p_query text)
returns table (user_id uuid, nickname text, registered_at timestamptz, is_admin boolean)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid := chat_require_superadmin();
  q text := replace(replace(replace(btrim(coalesce(p_query, '')), '\', ''), '%', ''), '_', '\_');
begin
  if char_length(q) < 2 then
    return;
  end if;
  return query
    select p.id, coalesce(h.display_name, p.nickname), p.registered_at, p.is_admin
    from profiles p
    left join chat_hosts h on h.user_id = p.id
    where p.nickname ilike q || '%'
       or h.display_name ilike q || '%'
       or h.display_name ilike '% ' || q || '%'
    order by p.registered_at is null, lower(coalesce(h.display_name, p.nickname))
    limit 10;
end;
$$;

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
        'nickname', coalesce(h.display_name, p.nickname),
        'is_superadmin', p.is_superadmin,
        'admin_since', p.admin_since,
        'is_me', p.id = uid
      ) order by p.is_superadmin desc, p.admin_since)
      from profiles p
      left join chat_hosts h on h.user_id = p.id
      where p.is_admin or p.is_superadmin), '[]'::jsonb)
  );
end;
$$;

revoke all on function admin_find_users(text) from public, anon;
revoke all on function admin_overview() from public, anon;
grant execute on function admin_find_users(text) to authenticated;
grant execute on function admin_overview() to authenticated;

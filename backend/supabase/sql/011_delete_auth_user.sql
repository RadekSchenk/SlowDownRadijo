-- Deleting listening stats left the anonymous Supabase auth user behind:
-- its id, creation and sign-in times and its sessions stayed in `auth.*`
-- for ever, and the app went on uploading under the very same id. That
-- contradicts the privacy policy ("zmizí úplně", "odstraníme celý tvůj
-- záznam").
--
--   * "Smazat moje statistiky" now deletes the caller's auth user as well
--     (the `listeners` row and everything under it go with it by cascade).
--     The app then forgets its stored session, so the next listen starts
--     under a new id.
--   * The 24-month cleanup deletes the anonymous auth users of the listeners
--     it removes, plus anonymous auth users that never got a `listeners` row
--     (e.g. the first upload failed) once they are as old as the cutoff.
--     Registered (non-anonymous) accounts are never touched here.
--
-- Needs the function owner (`postgres` on Supabase) to be allowed to delete
-- from `auth.users`. If the platform ever refuses that, the stats rows are
-- still deleted and a warning is logged instead of failing the request —
-- check the Postgres logs for "auth user not deleted" after deploying.
--
-- Run after 010. Replaces `delete_my_listening_data` and
-- `prune_inactive_listeners`; safe to re-run.

create or replace function delete_my_listening_data()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  delete from listeners where id = uid;

  begin
    delete from auth.users u where u.id = uid and coalesce(u.is_anonymous, false);
  exception when insufficient_privilege then
    raise warning 'auth user not deleted: %', sqlerrm;
  end;
end;
$$;

revoke all on function delete_my_listening_data() from public, anon, authenticated;
grant execute on function delete_my_listening_data() to authenticated;

create or replace function prune_inactive_listeners(p_inactive_for interval default interval '24 months')
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  archived bigint;
  gone_ids uuid[];
begin
  with gone as (
    delete from listeners
    where coalesce(last_seen_at, created_at) < now() - p_inactive_for
    returning id, total_seconds
  )
  select coalesce(sum(total_seconds), 0), coalesce(array_agg(id), '{}')
  into archived, gone_ids
  from gone;

  update community_archive set seconds = seconds + archived where id;

  begin
    delete from auth.users u
    where coalesce(u.is_anonymous, false)
      and (
        u.id = any (gone_ids)
        or (u.created_at < now() - p_inactive_for
            and not exists (select 1 from listeners l where l.id = u.id))
      );
  exception when insufficient_privilege then
    raise warning 'auth user not deleted: %', sqlerrm;
  end;

  return archived;
end;
$$;

revoke all on function prune_inactive_listeners(interval) from public, anon, authenticated;

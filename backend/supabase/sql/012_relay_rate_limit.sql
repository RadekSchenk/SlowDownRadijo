-- Rate limit for the two public e-mail relays (`send-voice-message`,
-- `send-feedback`). They run with `--no-verify-jwt`, so without a limit a
-- script could flood the station's inbox and use up the Resend quota.
--
-- The functions call `relay_allow()` with the service-role key before
-- sending. It allows `p_per_key` messages per sender per `p_window` and
-- `p_total` per relay per day. The sender is identified only by a SHA-256
-- hash of their IP address, and every row is deleted after one day.
--
-- Run after 011, then redeploy both functions. Until this file is run the
-- functions log an error and send without a limit (fail open), so feedback
-- keeps working. Safe to re-run.

create table if not exists relay_hits (
  bucket text not null,
  key_hash text not null,
  at timestamptz not null default now()
);
create index if not exists relay_hits_key_idx on relay_hits (bucket, key_hash, at);
create index if not exists relay_hits_at_idx on relay_hits (at);

alter table relay_hits enable row level security;
revoke all on relay_hits from anon, authenticated;

create or replace function relay_allow(
  p_bucket text,
  p_key_hash text,
  p_per_key integer,
  p_total integer,
  p_window interval
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from relay_hits where at < now() - interval '1 day';

  if (select count(*) from relay_hits h
      where h.bucket = p_bucket and h.key_hash = p_key_hash and h.at > now() - p_window) >= p_per_key
     or (select count(*) from relay_hits h where h.bucket = p_bucket) >= p_total then
    return false;
  end if;

  insert into relay_hits (bucket, key_hash) values (p_bucket, p_key_hash);
  return true;
end;
$$;

revoke all on function relay_allow(text, text, integer, integer, interval) from public, anon, authenticated;
grant execute on function relay_allow(text, text, integer, integer, interval) to service_role;

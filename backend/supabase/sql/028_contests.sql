-- Contests (app 1.3): one contest at a time, shown to everyone on the home
-- screen; only registered Slowriders can enter (an answer and a phone
-- number). Admins and the superadmin start and end contests, see the
-- answers and draw the winners from the app's Profil.
--
-- Figma "Slow Down Rádijo", page "Soutěže" (H1–H3, D1–D9, P1–P2, S1–S6).
-- Privacy (PRIVACY_POLICY.md, "Soutěže"): phone numbers go 30 days after the
-- draw (at the latest 90 days after the end), answers 12 months after the
-- end, the winners' nickname and prize after 3 years — see prune_contests().
--
-- Errors are stable codes like the chat's (chat_error): account_required,
-- contest_closed, already_entered, answer_invalid, phone_invalid,
-- not_contest_manager, contest_running, contest_invalid (detail = field),
-- contest_not_ended, no_entries.
--
-- Run once in the SQL editor (after 020–027). Idempotent.

-- ---------------------------------------------------------------------------
-- Tables

create table if not exists contests (
  id bigint generated always as identity primary key,
  title text not null,
  body text not null,
  question text not null,
  answer_type text not null check (answer_type in ('choice', 'text')),
  -- 'choice': exactly three options, A–C; the correct one is 0–2.
  options text[],
  correct_option smallint check (correct_option between 0 and 2),
  prize text not null,
  winners_count int not null check (winners_count between 1 and 20),
  rules_url text not null,
  starts_at timestamptz not null default now(),
  ends_at timestamptz not null,
  -- Set when a manager ends it early.
  ended_at timestamptz,
  drawn_at timestamptz,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists contests_ends_idx on contests (ends_at desc);

create table if not exists contest_entries (
  contest_id bigint not null references contests (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  -- 'A' / 'B' / 'C', or the listener's own words.
  answer text not null,
  -- Null for free-text answers (every one of them can be drawn).
  is_correct boolean,
  -- Normalised, e.g. "+420777123456"; null once pruned.
  phone text,
  created_at timestamptz not null default now(),
  primary key (contest_id, user_id)
);

create table if not exists contest_dismissals (
  contest_id bigint not null references contests (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (contest_id, user_id)
);

-- Kept apart from the entries: the nickname and prize stay for 3 years
-- (proof of who got what) after the entry itself is gone.
create table if not exists contest_winners (
  id bigint generated always as identity primary key,
  contest_id bigint not null references contests (id) on delete cascade,
  user_id uuid references auth.users (id) on delete set null,
  nickname text,
  prize text not null,
  drawn_at timestamptz not null default now(),
  unique (contest_id, user_id)
);

alter table contests enable row level security;
alter table contest_entries enable row level security;
alter table contest_dismissals enable row level security;
alter table contest_winners enable row level security;
-- No policies: clients go through the functions below only.
revoke all on contests, contest_entries, contest_dismissals, contest_winners from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Helpers (not callable by clients)

create or replace function contest_require_manager()
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid := chat_require_account();
begin
  if not exists (select 1 from profiles where id = uid and (is_admin or is_superadmin)) then
    perform chat_error('not_contest_manager');
  end if;
  return uid;
end;
$$;

create or replace function contest_is_running(c contests)
returns boolean
language sql
stable
set search_path = public
as $$
  select c.ended_at is null and c.starts_at <= now() and c.ends_at > now();
$$;

create or replace function contest_end_time(c contests)
returns timestamptz
language sql
stable
set search_path = public
as $$
  select coalesce(c.ended_at, c.ends_at);
$$;

-- "+420 777 123 456", "777123456", "00420777123456" → "+420777123456";
-- other countries need the leading + or 00. Null when it isn't a number.
create or replace function contest_normalize_phone(p_phone text)
returns text
language plpgsql
immutable
set search_path = public
as $$
declare
  s text := regexp_replace(coalesce(p_phone, ''), '[\s\-\(\)\.\/]', '', 'g');
begin
  if s ~ '^00[0-9]+$' then
    s := '+' || substr(s, 3);
  end if;
  if s ~ '^[0-9]{9}$' then
    s := '+420' || s;
  end if;
  if s ~ '^\+420[0-9]{9}$' or (s ~ '^\+[1-9][0-9]{7,14}$' and s !~ '^\+420') then
    return s;
  end if;
  return null;
end;
$$;

-- The contest as the listener sees it.
create or replace function contest_public_json(c contests)
returns jsonb
language sql
stable
set search_path = public
as $$
  select jsonb_build_object(
    'id', c.id,
    'title', c.title,
    'body', c.body,
    'question', c.question,
    'answer_type', c.answer_type,
    'options', coalesce(to_jsonb(c.options), '[]'::jsonb),
    'prize', c.prize,
    'winners_count', c.winners_count,
    'rules_url', c.rules_url,
    'starts_at', c.starts_at,
    'ends_at', c.ends_at,
    'is_running', contest_is_running(c)
  );
$$;

revoke all on function contest_require_manager() from public, anon, authenticated;
revoke all on function contest_is_running(contests) from public, anon, authenticated;
revoke all on function contest_end_time(contests) from public, anon, authenticated;
revoke all on function contest_normalize_phone(text) from public, anon, authenticated;
revoke all on function contest_public_json(contests) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Listeners

-- The running contest (or null) and, for a signed-in phone, whether this
-- listener has entered or closed it. Works without a session too.
create or replace function contest_current()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  c contests;
  e contest_entries;
  dismissed boolean := false;
begin
  select * into c from contests x
  where x.ended_at is null and x.starts_at <= now() and x.ends_at > now()
  order by x.starts_at desc limit 1;
  if not found then
    return null;
  end if;
  if uid is not null then
    select * into e from contest_entries where contest_id = c.id and user_id = uid;
    dismissed := exists (select 1 from contest_dismissals where contest_id = c.id and user_id = uid);
  end if;
  return contest_public_json(c) || jsonb_build_object(
    'my_status', case when e.user_id is not null then 'entered' when dismissed then 'dismissed' end,
    'my_entry', case when e.user_id is not null then jsonb_build_object(
      'answer', e.answer, 'phone', e.phone, 'created_at', e.created_at) end
  );
end;
$$;

-- Sends the answer. One per account and contest; can't be changed.
create or replace function contest_enter(p_contest_id bigint, p_answer text, p_phone text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := chat_require_account();
  c contests;
  ans text := btrim(coalesce(p_answer, ''));
  phone text := contest_normalize_phone(p_phone);
  correct boolean;
  e contest_entries;
begin
  select * into c from contests where id = p_contest_id;
  if not found or not contest_is_running(c) then
    perform chat_error('contest_closed');
  end if;
  if exists (select 1 from contest_entries where contest_id = c.id and user_id = uid) then
    perform chat_error('already_entered');
  end if;
  if c.answer_type = 'choice' then
    ans := upper(ans);
    if ans not in ('A', 'B', 'C') then
      perform chat_error('answer_invalid');
    end if;
    correct := (ascii(ans) - ascii('A')) = c.correct_option;
  else
    if char_length(ans) not between 1 and 200 then
      perform chat_error('answer_invalid');
    end if;
  end if;
  if phone is null then
    perform chat_error('phone_invalid');
  end if;
  insert into contest_entries (contest_id, user_id, answer, is_correct, phone)
  values (c.id, uid, ans, correct, phone)
  on conflict do nothing
  returning * into e;
  if e.user_id is null then
    perform chat_error('already_entered');
  end if;
  return jsonb_build_object('answer', e.answer, 'phone', e.phone, 'created_at', e.created_at);
end;
$$;

-- "Zavřít a nesoutěžit": the home infobox stays away for this contest.
-- Anonymous stats users too.
create or replace function contest_dismiss(p_contest_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := chat_require_user();
begin
  if not exists (select 1 from contests where id = p_contest_id) then
    return;
  end if;
  insert into contest_dismissals (contest_id, user_id) values (p_contest_id, uid)
  on conflict do nothing;
end;
$$;

-- ---------------------------------------------------------------------------
-- Admins and the superadmin (Profil ▸ Správa ▸ Soutěže)

create or replace function contest_admin_summary(c contests)
returns jsonb
language sql
stable
set search_path = public
as $$
  select jsonb_build_object(
    'id', c.id,
    'title', c.title,
    'answer_type', c.answer_type,
    'prize', c.prize,
    'winners_count', c.winners_count,
    'starts_at', c.starts_at,
    'ends_at', c.ends_at,
    'ended_at', c.ended_at,
    'ended_early', c.ended_at is not null and c.ended_at < c.ends_at,
    'drawn_at', c.drawn_at,
    'is_running', contest_is_running(c),
    'entries', (select count(*) from contest_entries e where e.contest_id = c.id),
    'correct', (select count(*) from contest_entries e where e.contest_id = c.id and e.is_correct),
    'dismissed', (select count(*) from contest_dismissals d where d.contest_id = c.id),
    'winners', (select count(*) from contest_winners w where w.contest_id = c.id)
  );
$$;

revoke all on function contest_admin_summary(contests) from public, anon, authenticated;

-- S1 / S2: the running contest and the earlier ones.
create or replace function admin_contests()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid := contest_require_manager();
begin
  return jsonb_build_object(
    'current', (select contest_admin_summary(c) from contests c
                where contest_is_running(c) order by c.starts_at desc limit 1),
    'previous', coalesce((select jsonb_agg(contest_admin_summary(c) order by contest_end_time(c) desc)
                 from (select * from contests c where not contest_is_running(c)
                       order by contest_end_time(c) desc limit 50) c), '[]'::jsonb)
  );
end;
$$;

-- S3: starts a contest right away. Only one runs at a time.
create or replace function admin_create_contest(
  p_title text, p_body text, p_question text, p_answer_type text,
  p_options text[], p_correct_option int, p_prize text, p_winners_count int,
  p_rules_url text, p_ends_at timestamptz)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := contest_require_manager();
  title text := btrim(coalesce(p_title, ''));
  body text := btrim(coalesce(p_body, ''));
  question text := btrim(coalesce(p_question, ''));
  prize text := btrim(coalesce(p_prize, ''));
  rules text := btrim(coalesce(p_rules_url, ''));
  opts text[];
  c contests;
begin
  perform pg_advisory_xact_lock(hashtext('contests'));
  if exists (select 1 from contests x where contest_is_running(x)) then
    perform chat_error('contest_running');
  end if;
  if char_length(title) not between 3 and 60 then perform chat_error('contest_invalid', 'title'); end if;
  if char_length(body) not between 10 and 3000 then perform chat_error('contest_invalid', 'body'); end if;
  if char_length(question) not between 5 and 200 then perform chat_error('contest_invalid', 'question'); end if;
  if p_answer_type not in ('choice', 'text') then perform chat_error('contest_invalid', 'answer_type'); end if;
  if p_answer_type = 'choice' then
    select array_agg(btrim(o) order by n) into opts from unnest(p_options) with ordinality as t(o, n);
    if coalesce(array_length(opts, 1), 0) <> 3
       or exists (select 1 from unnest(opts) o where char_length(o) not between 1 and 80) then
      perform chat_error('contest_invalid', 'options');
    end if;
    if p_correct_option is null or p_correct_option not between 0 and 2 then
      perform chat_error('contest_invalid', 'correct_option');
    end if;
  end if;
  if char_length(prize) not between 2 and 40 then perform chat_error('contest_invalid', 'prize'); end if;
  if p_winners_count is null or p_winners_count not between 1 and 20 then perform chat_error('contest_invalid', 'winners_count'); end if;
  if rules !~* '^(https?://)?[a-z0-9.-]+\.[a-z]{2,}(/\S*)?$' then perform chat_error('contest_invalid', 'rules_url'); end if;
  if rules !~* '^https?://' then rules := 'https://' || rules; end if;
  if p_ends_at is null or p_ends_at <= now() + interval '10 minutes' then
    perform chat_error('contest_invalid', 'ends_at');
  end if;
  insert into contests (title, body, question, answer_type, options, correct_option, prize,
                        winners_count, rules_url, ends_at, created_by)
  values (title, body, question, p_answer_type,
          case when p_answer_type = 'choice' then opts end,
          case when p_answer_type = 'choice' then p_correct_option end,
          prize, p_winners_count, rules, p_ends_at, uid)
  returning * into c;
  return contest_admin_summary(c);
end;
$$;

-- S4: ends the running contest now. The answers stay and can be drawn.
create or replace function admin_end_contest(p_contest_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := contest_require_manager();
  c contests;
begin
  update contests set ended_at = now()
  where id = p_contest_id and ended_at is null and ends_at > now()
  returning * into c;
  if not found then
    select * into c from contests where id = p_contest_id;
  end if;
  if c.id is null then
    perform chat_error('contest_closed');
  end if;
  return contest_admin_summary(c);
end;
$$;

-- S5 / S6: the answers, how they split and the winners.
create or replace function admin_contest(p_contest_id bigint)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid := contest_require_manager();
  c contests;
begin
  select * into c from contests where id = p_contest_id;
  if not found then
    perform chat_error('contest_closed');
  end if;
  return contest_admin_summary(c) || jsonb_build_object(
    'body', c.body,
    'question', c.question,
    'options', coalesce(to_jsonb(c.options), '[]'::jsonb),
    'correct_option', c.correct_option,
    'rules_url', c.rules_url,
    'distribution', coalesce((
      select jsonb_agg(jsonb_build_object('answer', answer, 'count', n) order by answer)
      from (select e.answer, count(*) as n from contest_entries e
            where e.contest_id = c.id and c.answer_type = 'choice' group by e.answer) d), '[]'::jsonb),
    'entry_list', coalesce((
      select jsonb_agg(jsonb_build_object(
        'nickname', p.nickname, 'answer', e.answer, 'is_correct', e.is_correct,
        'phone', e.phone, 'created_at', e.created_at) order by e.created_at desc)
      from contest_entries e left join profiles p on p.id = e.user_id
      where e.contest_id = c.id), '[]'::jsonb),
    'winners_list', coalesce((
      select jsonb_agg(jsonb_build_object(
        'nickname', w.nickname, 'phone', e.phone, 'answer', e.answer, 'drawn_at', w.drawn_at)
        order by w.drawn_at, w.id)
      from contest_winners w
      left join contest_entries e on e.contest_id = w.contest_id and e.user_id = w.user_id
      where w.contest_id = c.id), '[]'::jsonb)
  );
end;
$$;

-- S5 "Vylosovat výherce" (the contest's count) and S6 "Vylosovat
-- náhradníka" (p_count = 1). Random among the correct answers (every
-- free-text answer counts) with a phone, skipping earlier winners.
create or replace function admin_draw_winners(p_contest_id bigint, p_count int default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := contest_require_manager();
  c contests;
  n int;
  drawn int;
begin
  perform pg_advisory_xact_lock(hashtext('contest_draw_' || p_contest_id));
  select * into c from contests where id = p_contest_id;
  if not found then
    perform chat_error('contest_closed');
  end if;
  if contest_is_running(c) then
    perform chat_error('contest_not_ended');
  end if;
  n := coalesce(p_count, greatest(c.winners_count - (select count(*) from contest_winners where contest_id = c.id), 0));
  if n < 1 or n > 20 then
    perform chat_error('contest_invalid', 'count');
  end if;
  insert into contest_winners (contest_id, user_id, nickname, prize)
  select c.id, e.user_id, p.nickname, c.prize
  from contest_entries e left join profiles p on p.id = e.user_id
  where e.contest_id = c.id and e.is_correct is not false and e.phone is not null
    and not exists (select 1 from contest_winners w where w.contest_id = c.id and w.user_id = e.user_id)
  order by random()
  limit n;
  get diagnostics drawn = row_count;
  if drawn = 0 then
    perform chat_error('no_entries');
  end if;
  update contests set drawn_at = coalesce(drawn_at, now()) where id = c.id;
  return admin_contest(c.id);
end;
$$;

-- ---------------------------------------------------------------------------
-- Clean-up (pg_cron, daily)

create or replace function prune_contests()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update contest_entries e set phone = null
  from contests c
  where c.id = e.contest_id and e.phone is not null
    and ((c.drawn_at is not null and c.drawn_at < now() - interval '30 days')
         or contest_end_time(c) < now() - interval '90 days');
  delete from contest_entries e using contests c
  where c.id = e.contest_id and contest_end_time(c) < now() - interval '12 months';
  delete from contest_dismissals d using contests c
  where c.id = d.contest_id and contest_end_time(c) < now() - interval '12 months';
  delete from contest_winners where drawn_at < now() - interval '3 years';
end;
$$;

revoke all on function prune_contests() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Grants

revoke all on function contest_current() from public;
grant execute on function contest_current() to anon, authenticated;

do $$
declare
  f text;
begin
  foreach f in array array[
    'contest_enter(bigint, text, text)', 'contest_dismiss(bigint)',
    'admin_contests()',
    'admin_create_contest(text, text, text, text, text[], int, text, int, text, timestamptz)',
    'admin_end_contest(bigint)', 'admin_contest(bigint)', 'admin_draw_winners(bigint, int)'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('prune-contests', '30 3 * * *', 'select public.prune_contests()');
  end if;
end $$;

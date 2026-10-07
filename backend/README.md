# Slow Down Rádijo — backend

Four things live in this Supabase project (the fourth, anonymous listener
stats, has its own section further down):

1. `send-voice-message` — receives a recorded voice message from the app and
   relays it as an email attachment via [Resend](https://resend.com).
2. `send-feedback` — receives an in-app feedback message (Menu ▸ Zpětná
   vazba) and relays it as a plain email via Resend, same pattern as
   `send-voice-message` above, sharing the same `RESEND_API_KEY` secret.
3. Radio-wide stats (`played_tracks` table + `collect-now-playing` +
   `get-stats`) — a scheduled function polls the live stream's ICY metadata
   independently of whether the app is open, logs every track change (plus
   which show was airing, resolved from a bundled copy of the schedule) to
   Postgres, and `get-stats` exposes diversity/repetition/first-play
   aggregates for the app's "Statistiky" tab.

   **`collect-now-playing/schedule.json` is a duplicate** of
   `SlowDownRadijo/Resources/schedule.json` — Edge Functions can only bundle
   files inside their own directory, so it can't be shared directly. If the
   app's schedule changes, re-copy the file and redeploy:
   ```
   cp ../SlowDownRadijo/Resources/schedule.json supabase/functions/collect-now-playing/schedule.json
   supabase functions deploy collect-now-playing --no-verify-jwt
   ```

## One-time setup

### 1. Supabase project

1. Create a free account at [supabase.com](https://supabase.com) and a new
   project (any name/region).
2. Install the CLI: `brew install supabase/tap/supabase`
3. From `backend/`, log in and link the project:
   ```
   supabase login
   supabase link --project-ref <your-project-ref>
   ```
   (`<your-project-ref>` is in the project's dashboard URL and in
   Settings → General.)

### 2. Resend account

1. Create a free account at [resend.com](https://resend.com) (3,000
   emails/month free — far more than this needs).
2. Create an API key (Dashboard → API Keys) — this is the secret, never put
   it in the iOS app or commit it anywhere.
3. **Domain verification**: the function sends `from`
   `vzkaz@radekschenk.cz`. For that to work, verify `radekschenk.cz` in
   Resend (Dashboard → Domains → Add Domain, then add the shown DNS
   records). Until that's done, sending will fail for any `from` address on
   an unverified domain — swap the `from` in
   `supabase/functions/send-voice-message/index.ts` to
   `onboarding@resend.dev` for quick testing (Resend only allows that
   sender to deliver to the email address your Resend account itself is
   registered with).

### 3. Set the secret and deploy

```
cd backend
supabase secrets set RESEND_API_KEY=re_xxxxxxxxxxxx
supabase functions deploy send-voice-message --no-verify-jwt
supabase functions deploy send-feedback --no-verify-jwt
```

`--no-verify-jwt` makes the endpoint public (no Supabase auth token
required) — deliberate, since the app has no login system and any listener
should be able to send a message.

Deploying prints the function's URL, something like:
```
https://<project-ref>.supabase.co/functions/v1/send-voice-message
```

Paste that into `VoiceMessageUploadService.endpoint` in the iOS project
(`SlowDownRadijo/Services/VoiceMessageUploadService.swift`).

## Testing it standalone

```
curl -F "audio=@/path/to/test.m4a" \
  https://<project-ref>.supabase.co/functions/v1/send-voice-message
```
Should respond `{"success":true}` and land an email at jsem@radekschenk.cz
within a few seconds.

## Stats: one-time setup

### 1. Create the table + SQL functions

Open the SQL Editor (Dashboard → SQL Editor → New query), paste the entire
contents of `supabase/sql/001_played_tracks.sql`, and run it. This creates
`played_tracks`, its read-only RLS policy, and the three stats functions
(`diversity_weekly`, `repetition_rate`, `first_plays`).

Then run `002_first_plays_weekly.sql`, `003_total_unique_tracks.sql`, and
`004_filter_promo_plays.sql` in the same way, in that order — each one
replaces/extends functions from the previous file. `004` adds a
`played_tracks_clean` view that filters out station jingles/sponsor
mentions and untagged-show placeholder rows, and re-points every stats
function at it — run it any time to pick up the new filter, even on an
already-populated table.

### 2. Deploy the two functions

```
cd backend
supabase functions deploy collect-now-playing --no-verify-jwt
supabase functions deploy get-stats --no-verify-jwt
```

The app doesn't currently have a UI that consumes `get-stats` — the
"Statistiky" tab was removed pending a redesign (see project notes), but
this collector and endpoint are deliberately left running so data keeps
accumulating for when that tab comes back.

### 3. Schedule the collector

Back in the SQL Editor, run (once):

```sql
create extension if not exists pg_cron;
create extension if not exists pg_net;

select vault.create_secret('https://<project-ref>.supabase.co', 'project_url');
select vault.create_secret('<anon-public-key>', 'publishable_key');

select
  cron.schedule(
    'collect-now-playing-every-minute',
    '* * * * *',
    $$
    select
      net.http_post(
          url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url') || '/functions/v1/collect-now-playing',
          headers := jsonb_build_object(
            'Content-type', 'application/json',
            'apikey', (select decrypted_secret from vault.decrypted_secrets where name = 'publishable_key')
          ),
          body := '{}'::jsonb
      ) as request_id;
    $$
  );
```

Replace `<project-ref>` and `<anon-public-key>` (Settings → API — the
"anon" `public` key, safe to use here, it's meant to be public). This runs
`collect-now-playing` every minute, forever, independent of the app or
anyone's phone being on.

To check it's actually running: `select * from played_tracks order by
played_at desc limit 5;` a few minutes after scheduling — should show
real tracks appearing on their own.

To stop/change it later: `select cron.unschedule('collect-now-playing-every-minute');`

## Listener stats ("Statistiky"): one-time setup

Per-listener listening time, the community total and the leaderboard. The
app creates an **anonymous Supabase auth user** the first time someone has
listened for a while (no name, no e-mail) and uploads small batches of
"seconds listened per day and per show". Later, registration upgrades that
same user to a permanent account, so history carries over.

1. **Enable anonymous sign-ins:** Dashboard → Authentication → Sign In /
   Providers → *Allow anonymous sign-ins*. (Supabase's default rate limit is
   30 anonymous sign-ins per hour per IP; the app simply retries later.)
2. **Run `supabase/sql/005_listener_stats.sql`** in the SQL Editor. It is
   safe to re-run. Nothing needs deploying — the app talks to the SQL
   functions through Supabase's built-in REST layer.
3. **Run `supabase/sql/006_community_archive.sql`** next. It adds the
   anonymous `community_archive` counter and schedules the retention jobs
   promised in the privacy policy (needs `pg_cron`, already enabled for the
   collector above): listeners unused for 24 months are deleted and their
   seconds are added to the archive, so "Celkem všichni Slow Down Riders"
   never shrinks; they do leave the leaderboard. A listener who deletes their
   own stats in the app (*Smazat moje statistiky*) is **not** archived — their
   seconds disappear from the total too. Old batch ids are pruned as well.
   The `delete` statements make the Supabase MCP connector ask for
   confirmation; running the file in the SQL Editor works without it.
4. **Run `supabase/sql/007_public_stats.sql`.** It adds `public_stats()`, the
   session-less call the app uses to learn whether the community features are unlocked
   and to show the community total to people who haven't listened yet (zeros
   until the threshold is reached).
5. **Run `supabase/sql/008_listening_hardening.sql`.** Basic protection of
   the leaderboard and community total: a listener's total can never exceed
   the real time since their account was created plus a 12 h allowance for
   honest backlog (e.g. an outage), at most 120 uploads per hour (HTTP 429
   beyond that — the app just retries), only schedule-like show ids, at most
   24 shows per day, on top of the earlier 24 h/day cap. It can't tell a
   radio left on around the clock from a person, and it doesn't stop mass
   creation of anonymous accounts — CAPTCHA or App Attest would be the next
   step.
6. **Run `supabase/sql/009_get_my_stats_privacy.sql`.** `get_my_stats` then
   returns the community total, the ranked-listener count and the rank only
   once the community features are unlocked (zeros / null before), exactly
   like `public_stats()` — otherwise anyone with an anonymous session could
   read a handful of early listeners' totals.
7. **Run `supabase/sql/010_new_account_limits.sql`.** Closes two gaps in
   008: a brand-new account starts with a 15-minute allowance (growing with
   the account's age up to the 12 h backlog), not the full 12 h at once,
   and a listener counts towards the community threshold only once their
   record is at least a day old, so a burst of scripted sign-ups can't
   unlock the community features.
8. **The community switch.** A listener's own stats are always visible in the
   app (zeros at first). `stats_config` has one row, `min_listeners`
   (default 20) and `min_listener_seconds` (default 60); the **leaderboard
   and the "Celkem všichni Slow Down Riders" total** unlock for everyone once
   that many listeners have listened at least that long. For testing before
   then:
   ```sql
   update stats_config set force_enabled = true;   -- unlock them now
   update stats_config set force_enabled = false;  -- back to the threshold
   ```
9. **Quick check** after the first minute of listening in the app:
   ```sql
   select * from listeners;                 -- one row, total_seconds ≈ 60+
   select * from listening_daily order by day desc;
   ```

### Release checklist (privacy / App Review)

- [ ] **`stats_config.force_enabled` must be `false`** before a release —
      it is only a testing switch that unlocks the leaderboard and community
      total for everyone regardless of the listener threshold:
      `update stats_config set force_enabled = false;`

- [ ] `PRIVACY_POLICY.md` is published at the URL the app opens (Menu ▸
      Nastavení ▸ Zásady ochrany osobních údajů) and at the privacy URL in
      App Store Connect — fill in the `[DOPLNIT …]` placeholders first
      (date, Supabase region).
- [ ] App Store Connect → App Privacy: add **Identifiers → User ID** and
      **Usage Data → Product Interaction**; both *linked to the user's
      identity (pseudonymous id)*, purposes *App Functionality* (+
      *Analytics* for Product Interaction), *not used for tracking*. Keep the
      existing entries (Other User Content, Audio Data, Diagnostics). This
      mirrors `SlowDownRadijo/PrivacyInfo.xcprivacy`.
- [ ] No ATT prompt is needed: nothing is shared with other companies or
      combined with their data for tracking or advertising.
- [ ] Review notes: "Listening stats are measured under an anonymous
      Supabase user (no sign-in). The Statistiky tab is always visible; the
      leaderboard and the community total are hidden by a server-side switch
      until 20 listeners exist, so the reviewer will see a placeholder there.
      The on/off toggle and *Smazat moje statistiky* are always in
      Menu ▸ Nastavení."
- [ ] When registration is added: accounts need **in-app account deletion**
      (guideline 5.1.1(v)), and offering Google/social sign-in requires also
      offering **Sign in with Apple** (guideline 4.8).

## Local development

```
supabase start
supabase functions serve send-voice-message --env-file ./.env.local
```
`.env.local` (gitignored) should contain `RESEND_API_KEY=re_xxxxxxxxxxxx` —
never commit real keys.

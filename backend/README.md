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
   which show was airing — slowdownradijo.cz's `current-show`, so special
   broadcasts on the web count, else a bundled copy of the schedule) to
   Postgres, and `get-stats` exposes diversity/repetition/first-play
   aggregates for the app's "Statistiky" tab.

   **`collect-now-playing/schedule.json` is a duplicate** (the fallback) of
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

Because the endpoints are public, both are rate-limited (10 messages per
sender per hour, 300 per relay per day) by `relay_allow()` from
`supabase/sql/012_relay_rate_limit.sql` — run it once in the SQL Editor
before (re)deploying. The sender is identified only by a SHA-256 hash of
their IP, kept for a day. Without that file the functions log an error and
send unlimited (fail open). The voice relay also accepts only MPEG-4 audio
and always names the attachment `vzkaz.m4a`.

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
Should respond `{"success":true}` and land an email at info@slowdownradijo.cz
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
8. **Run `supabase/sql/011_delete_auth_user.sql`.** *Smazat moje
   statistiky* then deletes the anonymous auth user too (the app forgets its
   session and starts over under a new id), and the 24-month cleanup removes
   the anonymous auth users of the listeners it deletes. Registered accounts
   are never touched. If Supabase ever refuses the `auth.users` delete, the
   stats are still removed and Postgres logs "auth user not deleted".
9. **The community switch.** A listener's own stats are always visible in the
   app (zeros at first). `stats_config` has one row, `min_listeners`
   (default 20) and `min_listener_seconds` (600 since 019: ten minutes, so
   Xcode runs, simulators and App Review devices don't count); the
   **leaderboard and the "Celkem všichni Slow Down Riders" total** unlock for
   everyone once that many listeners, each at least a day old, have listened
   at least that long. For testing before then:
   ```sql
   update stats_config set force_enabled = true;   -- unlock them now
   update stats_config set force_enabled = false;  -- back to the threshold
   ```
10. **Quick check** after the first minute of listening in the app:
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

## Chat and accounts (app 1.3): one-time setup

Listeners read the chat without an account; writing needs a permanent
account (Apple, Google or e-mail with a 6-digit code). Signing in upgrades the
listener's anonymous stats user, so their stats stay. Design and rules:
`docs/chat-concept.md`, plan: `docs/chat-implementation.md`.

1. **Run `supabase/sql/020_chat.sql`** in the SQL Editor (after 019; safe to
   re-run). It creates `profiles`, `chat_hosts`, `chat_host_invites`,
   `chat_messages` (added to the `supabase_realtime` publication),
   `chat_deleted_bodies`, `chat_mutes`, `chat_reports`, `chat_hidden_users`,
   the functions the apps call and a nightly `prune-chat` cron job (messages
   are kept 90 days). Messages are readable by everyone; every write goes
   through a function. The app sends the show a message was written in
   (`show_id`, `show_title`), as it does for the listening stats.
2. **Authentication → Sign In / Providers:**
   - *Email*: on, with "Confirm email"; in *Email Templates → Magic Link* put
     the code in the e-mail (`{{ .Token }}`) next to the link. OTP length 6,
     expiry 600 s. Do the same in *Confirm signup* and *Change Email
     Address*: a listener who already writes in the chat registers by adding
     an e-mail to their anonymous user, and that sends the *Change Email
     Address* e-mail.
   - *Apple*: on. Client IDs: the iOS bundle id (native sign-in) and the
     Services ID (Android, web flow), with the `.p8` key, Key ID and Team ID.
   - *Google*: on. Client IDs: the Web client (with its secret), plus the iOS
     and Android client ids in "Authorized Client IDs". Turn on **Skip nonce
     check**: GoogleSignIn-iOS 8 can't pass our own nonce (Android does).
     The apps take the client ids from `GOOGLE_IOS_CLIENT_ID` /
     `GOOGLE_IOS_URL_SCHEME` in `project.yml` (iOS) and the Gradle property
     `googleWebClientId` (Android, the *Web* client id).
   - *Allow manual linking*: on (an anonymous stats user becomes permanent).
3. **Authentication → SMTP:** custom SMTP via Resend (`smtp.resend.com`, port
   465, user `resend`, password = `RESEND_API_KEY`), sender
   `prihlaseni@slowdownradijo.cz` — the built-in sender is rate-limited to a
   few e-mails per hour.
4. **Authentication → URL Configuration:** add `slowdownradijo://auth` to the
   redirect URLs (the e-mail link and Apple's web flow return there).
5. **DJs:** add each DJ who should write in the chat once in the Table Editor:
   ```sql
   insert into chat_hosts (host_id, display_name) values ('dj-pufaz', 'DJ Pufaz');
   insert into chat_host_invites (host_id) values ('dj-pufaz') returning code;
   ```
   Send the DJ `https://slowdownradijo.cz/dj/<code>` (valid 7 days, once).
   Their name is then reserved and they get the DJ badge and moderation.
   Unlink: `update chat_hosts set user_id = null where host_id = 'dj-pufaz';`
6. **Admins** (moderate under their own nickname, can lift a block):
   `update profiles set is_admin = true where id = '<auth user id>';`
7. **Reports** land in `chat_reports`; check them in the Table Editor.
8. **Run `supabase/sql/021_chat_invite_info.sql`** (after 020). It adds
   `host_invite_info(code)`, which the invite screen calls before the DJ signs
   in ("Propoj účet jako DJ Pufaz", "platí do 24. 11."). Without it the apps
   show a generic title and the claim still works.
10. **Run `supabase/sql/022_chat_v3.sql`** (after 021): writing without an
    account (the anonymous user sets a nickname with its first message;
    changing it needs registration), `registered_at`, dashboard counters,
    superadmin functions (`admin_*`), the anonymised archive `chat_archive`
    and daily statistics (`chat_daily_stats`, `chat_show_daily`, views
    `chat_stats_*`, cron `chat-daily-stats` at 03:10). The statistics are
    readable only with the service role (SQL Editor).
11. **Superadmin:** once Radek has registered in the app,
    `update profiles set is_superadmin = true, is_admin = true, admin_since = now() where nickname = '<his nickname>';`
    (by nickname: with Sign in with Apple the account's e-mail may be a
    hidden `…@privaterelay.appleid.com` address). Done on 18. 11. 2026.
    From then on moderators and admins are managed in the app
    (Profil ▸ Správa chatu); the SQL in step 5 is the fallback.
12. **Run `supabase/sql/023_chat_spam.sql`** (after 022): the same text from
    the same person within a minute is refused (a single emoji is exempt),
    and links need an account. On top of 5 messages per 30 s and 60 per hour. On production
    since 18. 11. 2026.
13. **Run `supabase/sql/024_account_stats.sql`** (after 023), on production
    since 18. 11. 2026: view `account_stats_daily`, registrations per day ×
    platform × sign-in method, counts only (SQL Editor).
14. **Run `supabase/sql/025_posthog_registrations.sql`** (after 024): the
    same numbers as `posthog_export.account_registrations` for PostHog's
    existing data warehouse source "radio" (step 7 / 015). Then turn on that
    table in PostHog (Data warehouse ▸ radio ▸ Schemas).
15. **Run `supabase/sql/026_my_stats_neighbours.sql`** (after 025):
    `get_my_stats` also returns the listening time of the places right above
    and below the caller (shown as neighbours, not a race) and the days with
    listening, for the new Statistiky (1.3). On production since 19. 11. 2026.
16. **Run `supabase/sql/027_stream_quality_and_chat_export.sql`** (after
    026): listening rows carry the stream (mp3 / aac) and the quality setting,
    summed in `listening_streams_daily` with no listener in it, and
    `listeners.stream_quality` keeps the latest setting. PostHog gets
    `posthog_export.listening_quality_daily`, `listening_quality_users`,
    `chat_daily`, `chat_shows_30d` and `chat_retention` (turned on in the
    "radio" source, every 6 hours). On production since 21. 11. 2026.
9. **Invite links on slowdownradijo.cz.** Until these two files are on the
   web, the `https://slowdownradijo.cz/dj/<code>` link opens the website, not
   the app; `slowdownradijo://dj/<code>` works right away in both apps.
   Both files, filled in, are in `backend/web/.well-known/`: upload them as
   they are.
   - `/.well-known/apple-app-site-association` (no extension, served as
     `application/json`, no redirect), plus *Associated Domains* switched on
     for the App ID `cz.slowdownradijo.app`:
     ```json
     {"applinks": {"details": [{"appIDs": ["9W8BX34TJH.cz.slowdownradijo.app"], "components": [{"/": "/dj/*"}]}]}}
     ```
   - `/.well-known/assetlinks.json`, with the SHA-256 fingerprints of the
     upload key and of Google Play's app signing key (Play Console → Test and
     release → App integrity):
     ```json
     [{"relation": ["delegate_permission/common.handle_all_urls"],
       "target": {"namespace": "android_app", "package_name": "cz.slowdownradijo.app",
                  "sha256_cert_fingerprints": ["<upload key SHA-256>", "<app signing key SHA-256>"]}}]
     ```
   - The web page at `/dj/<code>` itself can just say "Otevři odkaz v
     telefonu s aplikací Slow Down Rádijo" for anyone without the app.

Tested locally on Postgres 16 with stubs for `auth.uid()` / `auth.jwt()`:
nickname rules, 24 h limit, anonymous users rejected, mute / block / unmute
rights, delete and undo, one pin, rate limit (5 per 30 s, 60 per hour),
hide / report, account deletion leaving messages as "Smazaný účet".

## Local development

```
supabase start
supabase functions serve send-voice-message --env-file ./.env.local
```
`.env.local` (gitignored) should contain `RESEND_API_KEY=re_xxxxxxxxxxxx` —
never commit real keys.

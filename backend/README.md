# Slow Down Rádijo — backend

Four things live in this Supabase project:

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
4. Social follower counts (`social_stats` table + `update-social-stats`) —
   a scheduled function scrapes Instagram/Threads/Facebook's public profile
   pages (their `og:description` meta tag) plus YouTube's official Data
   API v3, caching the counts for the Menu's social row (see
   `SlowDownRadijo/Views/Hub/SocialLinksRow.swift`). None of the three
   scraped platforms have a free unauthenticated public API for follower
   counts — this is inherently more fragile than the other three functions
   (any of them could change their HTML/anti-bot rules at any time) — see
   `update-social-stats/index.ts`'s top comment for the exact technique
   each platform needed (Instagram/Threads: a normal mobile Safari
   User-Agent; Facebook: specifically a Googlebot User-Agent, since a
   normal browser UA gets redirected to a JS-only shell with no data).

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

## Social stats: one-time setup

### 1. Create the table

Open the SQL Editor (Dashboard → SQL Editor → New query), paste the entire
contents of `supabase/sql/005_social_stats.sql`, and run it. This creates
`social_stats` (one row per platform: `youtube`, `instagram`, `facebook`,
`threads`) and its read-only RLS policy.

### 2. (Optional) YouTube API key

Instagram/Threads/Facebook are scraped (no key needed), but YouTube's
subscriber count uses the official Data API v3, which needs a free key:

1. [console.cloud.google.com](https://console.cloud.google.com) → create/
   select a project → APIs & Services → Library → enable **"YouTube Data
   API v3"**.
2. APIs & Services → Credentials → Create Credentials → API key.
3. `supabase secrets set YOUTUBE_API_KEY=AIza...`

Without this secret set, `update-social-stats` just skips YouTube (not a
hard failure) and still updates the other three platforms.

### 3. Deploy the function

```
cd backend
supabase functions deploy update-social-stats --no-verify-jwt
```

### 4. Schedule it

Same pattern as the now-playing collector, but a much longer interval —
these counts don't need to be fresh to the minute, and scraping too often
risks the platforms rate-limiting/blocking the server's IP. Back in the
SQL Editor (the `vault` secrets from the now-playing cron setup above are
reused, no need to create them twice):

```sql
select
  cron.schedule(
    'update-social-stats-every-6h',
    '0 */6 * * *',
    $$
    select
      net.http_post(
          url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url') || '/functions/v1/update-social-stats',
          headers := jsonb_build_object(
            'Content-type', 'application/json',
            'apikey', (select decrypted_secret from vault.decrypted_secrets where name = 'publishable_key')
          ),
          body := '{}'::jsonb
      ) as request_id;
    $$
  );
```

To check it's working: `select * from social_stats order by platform;`
after the next scheduled run (or trigger one immediately with `curl -X
POST https://<project-ref>.supabase.co/functions/v1/update-social-stats -H
"apikey: <anon-public-key>"`).

To stop/change it later: `select cron.unschedule('update-social-stats-every-6h');`

## Local development

```
supabase start
supabase functions serve send-voice-message --env-file ./.env.local
```
`.env.local` (gitignored) should contain `RESEND_API_KEY=re_xxxxxxxxxxxx` —
never commit real keys.

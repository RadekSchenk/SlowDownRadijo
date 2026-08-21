# Slow Down Rádijo — backend

Two things live in this Supabase project:

1. `send-voice-message` — receives a recorded voice message from the app and
   relays it as an email attachment via [Resend](https://resend.com).
2. Radio-wide stats (`played_tracks` table + `collect-now-playing` +
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

Paste the printed `get-stats` URL into the iOS project (wherever
`StatisticsService`'s endpoint constant is — see the app's Services folder).

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

## Local development

```
supabase start
supabase functions serve send-voice-message --env-file ./.env.local
```
`.env.local` (gitignored) should contain `RESEND_API_KEY=re_xxxxxxxxxxxx` —
never commit real keys.

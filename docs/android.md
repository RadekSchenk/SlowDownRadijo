# Android app

Slow Down Rádijo for Android: the same app as on iOS, kept in step with
it. Decided 10 Nov 2026.

## Approach

- **Native Kotlin + Jetpack Compose** in `android/` in this repository.
  Compose mirrors SwiftUI closely enough to port screen by screen;
  Media3 (ExoPlayer + MediaSessionService) does the live stream, its ICY
  metadata, background playback, the notification and lock screen
  controls, headphones and Android Auto.
- **One backend:** the same Supabase functions and tables, the same
  PostHog project and event names (platform tells them apart), the same
  slowdownradijo.cz APIs for the programme and news.
- **One source for shared data:** `SlowDownRadijo/Resources/schedule.json`
  (the show catalogue), the show and host photos, the Manrope fonts and
  the colours. Strings come from `SlowDownRadijo/Services/L10n.swift`,
  converted to `strings.xml` (cs, en) by a script rather than kept by hand.
- **Figma is the design source** for both apps.
- **Phones only** for 1.0, as on iOS.
- **Testing:** unit and screenshot tests (Robolectric / Roborazzi) and a
  screen recording from an emulator in CI; no Android phone at hand yet.

## Keeping the two apps the same

- A feature or design change is made in both apps in the same piece of
  work, and `docs/parity.md` (below) gets its row updated.
- CI builds and tests both apps on every push.
- Store screenshots come from the same `tools/appstore/frame.py` (the
  clouds background), with an Android phone frame.

## Plan

| Phase | What |
|---|---|
| 0. Groundwork | Gradle project, CI, theme (colours, Manrope, heading levels), strings from L10n, debug builds as artifacts |
| 1. Radio | Live stream with Media3, notification / lock screen, song metadata, programme from the web, the home header with clouds and equalizer, sleep timer, output picker (Bluetooth / Cast instead of AirPlay) |
| 2. The rest | Programme with photos and reminders, listening stats, voice message, menu, news, settings, feedback, analytics consent, language switch |
| 3. Polish | Home screen widget (Glance), accessibility, screen sizes, emulator recordings |
| 4. Google Play | Internal testing track, store listing, Data safety form, content rating, screenshots, review |

## Status

Phase 0 is done (10 Nov 2026):

- `android/`: Gradle 9.8, AGP 9.5 (built-in Kotlin 2.4), Compose BOM
  2026.09, Media3 1.11; minSdk 26, compile/targetSdk 37 (Android 17).
  Package `cz.slowdownradijo.app` (debug builds `.debug`).
- Shared data without copies: `buildSrc/SharedResources.kt` turns the
  iOS imagesets into drawables (`ShowArtBassTime` →
  `R.drawable.show_art_bass_time`, mapped by name in the generated
  `SharedImages`), the Manrope TTFs into `R.font.manrope_*`, and
  `schedule.json` into an asset.
- Strings: `tools/android/l10n_to_strings.py` writes `values/strings.xml`
  (cs) and `values-en/strings.xml` from `L10n.swift`, keeping the key
  names. The few entries with logic (plurals, durations, dates) are in
  `l10n/L10nLogic.kt`; `android/l10n-overrides.json` holds Android text
  where iOS is named. CI fails when strings.xml is stale.
- The language is the app's own (`l10n/AppLanguage.kt`), switched without
  a restart, as on iOS.
- Theme: `ui/theme/Theme.kt` mirrors `Theme.swift` (colours, Heading
  page/hero/section/item, Copy body/reading/label/link/button, tab bar).
- Launcher icon from the iOS AppIcon: `tools/android/icons.py`.
- CI: `.github/workflows/android.yml` (string check, build, unit and
  screenshot tests, debug APK and screenshots as artifacts). Robolectric
  runs on API 36 until it supports 37.

### Building

    python3 tools/android/l10n_to_strings.py     # after changing L10n.swift
    cd android
    ./gradlew :app:assembleDebug                 # app/build/outputs/apk/debug
    ./gradlew :app:testDebugUnitTest             # unit + screenshot tests
    ./gradlew :app:testDebugUnitTest -Proborazzi.test.record=true   # new screenshots

## Google Play account

Slow Down Radio s.r.o. opens an **organisation** developer account
(play.google.com/console/signup): 25 USD once, the company's D-U-N-S
number (the one Apple has), a verified website and contact. Verification
can take several days. Organisation accounts skip the 14-day / 12-tester
closed test that new personal accounts must run before production.

## Parity

| Feature | iOS | Android |
|---|---|---|
| Live stream, background, lock screen | 1.0 | — |
| Song on air (ICY + server log, TrackTrust) | 1.0 | — |
| Programme from the web (specials) | 1.1 | — |
| Home header: compact player, clouds, equalizer | 1.1 | — |
| Sleep timer | 1.0 | — |
| Output picker (AirPlay / Bluetooth / Cast) | 1.0 | — |
| Programme with photos, reminder bell | 1.1 | — |
| Show reminders (notifications) | 1.0 | — |
| Listening stats (Supabase) | 1.0 | — |
| Voice message | 1.0 | — |
| Menu, news, settings, feedback | 1.0 | — |
| Analytics consent, PostHog | 1.0 | — |
| Language switch (cs / en) | 1.0 | strings + language store; toggle in phase 2 |
| Heading scale, typography | 1.1 | 0 (theme) |
| Home screen widget | 1.0 | — |
| Review prompt (system) | 1.0 | — |

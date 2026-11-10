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

Phase 1 (10 Nov 2026), in `android/app/src/main/kotlin/cz/slowdownradijo/app/`:

- `player/RadioEngine.kt` (as `RadioPlayerService.swift`): ExoPlayer, a
  fresh connection on every play, reconnect with 2…30 s back-off, a 20 s
  connect deadline, reconnect when the network returns, audio focus and
  unplugged headphones pause, the sleep timer. `PlaybackService.kt` is the
  MediaSessionService (notification, lock screen, Bluetooth, Android Auto);
  the notification shows what `NowPlayingModel` publishes, never the raw
  stream title.
- `player/IcyMetadataPoller.kt` (as `ICYMetadataService.swift`), every 20 s.
- `home/NowPlayingModel.kt` (as `NowPlayingViewModel.swift`) with
  `data/TrackTrust.kt` and the `played_tracks` check
  (`data/RemoteHistoryService.kt`).
- `data/WebScheduleService.kt` and the cached week in `ScheduleStore.kt`;
  tests run against the web's real responses (`src/test/resources/web`).
- `home/HomeScreen.kt`, `NowPlayingCover.kt` (cover + side equalizer),
  `HeaderClouds.kt`, `PlayerControls.kt`, `SleepTimer.kt` (sheet + moon).
- Not yet: the swipe through earlier songs on the song line, the output
  picker, analytics events (phase 2 with PostHog).

Phase 2 (10 Nov 2026):

- Frame: bottom bar (Rádio, Statistiky, Vzkaz) with the iOS tab icons,
  converted from the shared SVGs to vector drawables at build time; the
  menu over everything; autoplay on launch.
- `home/HomeProgramSection.kt` (seven-day picker, past shows folded
  away, bell); `reminders/` ("Právě začíná" with "Poslouchat", one alarm
  for the next followed start, re-planned on programme, language and
  reboot; Android 13+ asks for notifications at the first bell).
- `stats/`: the anonymous Supabase account, `ListeningTracker` with the
  iOS timings and batch ids, the Statistiky page and the home block.
  The app version sent ends in "android".
- `message/`: MediaRecorder AAC in MPEG-4 (.m4a, which the server checks
  for), 18-segment waveform, preview, upload.
- `menu/` (language switch, WhatsApp, social links), Settings, show
  reminders list; `news/` (list, post, new-post notification at launch);
  `feedback/` (device: "Android <version>", manufacturer and model).
- `analytics/`: consent from the third launch, the iOS event names and
  properties, sent to PostHog's capture API directly. Every PostHog
  Android SDK release was under two weeks old on 10 Nov 2026, and the
  direct API sends only what the iOS app sends (no device details, no
  person profiles). Events carry `platform: android`.
- Not yet: the output picker, the system review prompt, swiping through
  earlier songs, the widget (phase 3).

Phase 3 (10 Nov 2026):

- Widget: `widget/` (Glance), see the parity table.
- Accessibility: `AccessibilityTest` runs Google's Accessibility Test
  Framework over every screen (touch targets ≥ 48 dp, labels, duplicate
  descriptions) and fails on a finding. Fixed on the way: the recorded
  message's play button had no label (on iOS too: new L10n keys
  `playRecording` / `pauseRecording`, used by both apps), the switches
  now say what they switch, the reminder bell's touch target is 48 dp.
- **Contrast (design, both apps):** `liveRed` (#DB304E) as small text on
  the dark backgrounds is 4.1:1 on `background`, 3.5:1 on
  `statsCardRaised`, below WCAG's 4.5:1 for small text ("Vypnutí za…",
  "#7 z 128", "Nastavení" in the blocked-notifications note). The ON-AIR
  red (#D91F1F) is lower still. Reported by the test, not failed: the
  colours come from Figma and are the same on iOS.
- Text size: like iOS (Dynamic Type capped at xxxLarge, the tab bar at
  xLarge), the app follows the phone's font size up to 135 % and the
  bottom bar up to 112 %; fixed heights became minimum heights.
  `ScreenSizesScreenshotTest` covers a 360 × 640 dp phone and 200 % text.

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
| Live stream, background, lock screen | 1.0 | 1 (Media3; reconnect, audio focus, headphones) |
| Song on air (ICY + server log, TrackTrust) | 1.0 | 1 |
| Programme from the web (specials) | 1.1 | 1 (cached week) |
| Home header: compact player, clouds, equalizer | 1.1 | 1 (song line without the swipe back through earlier songs) |
| Sleep timer | 1.0 | 1 |
| Output picker (AirPlay / Bluetooth / Cast) | 1.0 | — |
| Programme with photos, reminder bell | 1.1 | 2 |
| Show reminders (notifications) | 1.0 | 2 (one alarm at a time, exact when allowed, else within a minute) |
| Listening stats (Supabase) | 1.0 | 2 |
| Voice message | 1.0 | 2 |
| Menu, news, settings, feedback | 1.0 | 2 |
| Analytics consent, PostHog | 1.0 | 2 (PostHog's capture API, no SDK) |
| Language switch (cs / en) | 1.0 | 2 |
| Heading scale, typography | 1.1 | 0 (theme); text size capped as on iOS |
| Home screen widget | 1.0 | 3 (Glance; system font, widgets cannot use Manrope) |
| Review prompt (system) | 1.0 | 3 (Play In-App Review; the iOS rules: a week, 3 days of 10+ min in 60, 120 days apart, at most 3) |

# Slow Down Rádijo

Two apps for the same radio, kept the same:

- **iOS**: `SlowDownRadijo/` (SwiftUI), tests in `SlowDownRadijoTests/` and `SlowDownRadijoUITests/`.
- **Android**: `android/` (Kotlin, Jetpack Compose, Media3). Plan, status and the
  parity table: `docs/android.md`.
- **Backend** shared by both: `backend/` (Supabase: stats, voice messages, feedback).

Talk to Radek in Czech.

## Every change is for both apps

A change to what listeners see or what the app does goes into **both apps in the
same branch and pull request**, not one now and the other later:

- Build it in iOS and Android, then update the row in the parity table in
  `docs/android.md` (the version it came in, and anything that differs).
- If one platform can't do it the same way (e.g. AirPlay on iOS, the system
  output switcher on Android), say how it differs in that row.
- Keep the version numbers the same: `MARKETING_VERSION` in `project.yml` and
  `versionName` in `android/app/build.gradle.kts`.

Only something that exists on one platform alone (CarPlay vs Android Auto
details, App Store vs Google Play metadata, a platform bug) is done on one side.

## Shared by construction

- **Texts**: written once in `SlowDownRadijo/Services/L10n.swift`. After changing it run
  `python3 tools/android/l10n_to_strings.py` to regenerate Android's `strings.xml`
  (CI fails if they are out of date). Entries with logic live in
  `android/.../l10n/L10nLogic.kt` and need a hand edit there.
- **Images, fonts, programme**: Android's build reads `Assets.xcassets`, the Manrope
  fonts and `schedule.json` straight from the iOS app; nothing is copied.
- **Analytics**: the same PostHog project, event names and properties
  (`Analytics.swift` and `android/.../analytics/Analytics.kt`). A new event goes into
  both. Platforms are told apart by `$os` (`iOS` / `Android`).
- **Listening stats**: the same Supabase project and functions; Android's
  `app_version` ends in `android`.

## Checks

- Android: `cd android && ./gradlew :app:testDebugUnitTest` (unit, screenshot and
  accessibility tests). New or changed screens:
  `./gradlew :app:testDebugUnitTest -Proborazzi.test.record=true` and look at the
  images in `android/app/src/test/screenshots/`.
- iOS: the GitHub Actions UI tests (`.github/workflows/ui-tests.yml`).

# App Store listing

What goes into App Store Connect for Slow Down Rádijo. Keep it in step
with the app: a feature named here must be in the build that's
submitted. Limits: subtitle 30 characters, promotional text 170,
keywords 100 (comma-separated, no spaces after commas), description
4000.

Screenshots: `[appstore]` in a commit message runs the
appstore-screenshots job (`.github/workflows/ui-tests.yml`), 6.9" iPhone,
Czech and English; best while a show with a host is on air. Upload the
files in the artifact's `framed-6.3` folder (1206 x 2622): App Store
Connect's iPhone slot is the 6.1"/6.3" Dynamic Island size.

## App information

| Field | Value |
|---|---|
| Name | Slow Down Rádijo |
| Primary category | Music |
| Secondary category | Entertainment |
| Privacy Policy URL | https://slowdownradijo.cz/ochrana-osobnich-udaju/ |
| Support URL | https://slowdownradijo.cz |
| Copyright | 2026 Slow Down Radio s.r.o. |
| Age rating | 4+ (every question "None"/"No") |

## Czech (primary)

**Subtitle**

Hip hop, soul, jazz a funk

**Promotional text**

Poslouchej Slow Down Rádijo – ruční kurátorský výběr hudby namísto automatických algoritmů. Program, časovač vypnutí, vzkaz do rádia a tvoje vlastní statistiky poslechu.

**Keywords**

radio,rádio,hiphop,rap,soul,funk,jazz,afrobeat,beats,groove,stream,živě,praha,černá hudba

**Description**

Slow Down Rádijo v kapse. Živé vysílání rádia, které hraje hip hop, soul, funk, jazz, afrobeat i elektroniku – a hlavně věci, které jinde neuslyšíš. Ruční kurátorský výběr hudby namísto automatických algoritmů.

CO APPKA UMÍ
• Živé vysílání na jedno klepnutí – i na pozadí, ze zamčené obrazovky, přes AirPlay a Bluetooth
• Co se právě vysílá: pořad, moderátor a skladba, kterou jedním klepnutím najdeš na Spotify
• Skladby, které hrály před chvílí – stačí přejet prstem do strany
• Program na celý týden s popisy pořadů a připomínkou, když začíná tvůj oblíbený
• Časovač vypnutí, když s rádiem usínáš
• Tvoje statistiky poslechu: kolik času jsi s rádiem strávil, tvoje nejposlouchanější pořady a tvoje místo mezi posluchači
• Hlasový vzkaz do rádia – nahraj pozdrav nebo přání a pošli ho moderátorům
• Novinky z rádia a widget na plochu s tím, co se právě vysílá
• Česky i anglicky

BEZ ÚČTU A BEZ REKLAM
Appku používáš bez registrace a bez reklam. Statistiky poslechu jsou anonymní a můžeš je kdykoli vypnout i smazat. Měření používání appky se zapne jen s tvým souhlasem.

Zpomal se Slow Down Rádijem.
Tohle algoritmus neumí.
No music. No life.

## English

**Subtitle**

Hip hop, soul, jazz and funk

**Promotional text**

Listen to Slow Down Rádijo – music hand-picked by people, not algorithms. A weekly schedule, a sleep timer, voice messages to the station and your own listening stats.

**Keywords**

radio,hiphop,rap,soul,funk,jazz,afrobeat,beats,groove,stream,live,online,prague,czech,black music

**Description**

Slow Down Rádijo in your pocket. The live stream of a radio station playing hip hop, soul, funk, jazz, Afrobeat and electronica – and above all, music you won't hear anywhere else. Hand-picked by people, not by algorithms.

WHAT IT DOES
• The live stream in one tap – in the background, from the lock screen, over AirPlay and Bluetooth
• What's on air: the show, the host and the song, which you can find on Spotify in one tap
• The songs that played a moment ago – just swipe sideways
• The whole week's schedule with show descriptions and a reminder when your favourite starts
• A sleep timer for falling asleep to the radio
• Your listening stats: how much time you've spent with the station, your most-listened shows and where you rank among listeners
• Voice messages to the station – record a shout-out or a request and send it to the hosts
• News from the station and a Home Screen widget showing what's on air
• In Czech and English

NO ACCOUNT, NO ADS
No sign-up and no ads. Listening stats are anonymous, and you can turn them off and delete them at any time. Usage measurement only starts with your consent.

Slow down with Slow Down Rádijo.
No algorithm can do this.
No music. No life.

## What's New

Per version, in App Store Connect → the version → "What's New in This
Version" (cs and en). Version 1.0 had none.

**1.1 — Czech**

```
• Program teď sedí s webem: speciální vysílání a změny v programu uvidíš hned, jak je rádio zveřejní.
• Nová hlavička: kompaktní přehrávač s pořadem, moderátorem a skladbou, za kterým při poslechu pomalu plují barevné mraky.
• Pořady v programu mají fotky a připomínku najdeš hned u času začátku.
• Jednotnější písmo v celé aplikaci a víc místa pro logo na iPhonech s Dynamic Islandem.
• Drobné opravy a vylepšení.
```

**1.1 — English**

```
• The schedule now matches the website: special broadcasts and programme changes show up as soon as the station publishes them.
• A new header: a compact player with the show, host and song, with coloured clouds drifting slowly behind it while you listen.
• Shows in the schedule have photos, and the reminder sits right next to the start time.
• More consistent type across the app, and more room for the logo on iPhones with the Dynamic Island.
• Small fixes and improvements.
```

**1.2 — Czech**

```
• Slow Down Rádijo v autě: s CarPlay pustíš živé vysílání přímo z displeje auta a uvidíš pořad i skladbu, která právě hraje.
• Drobné opravy a vylepšení.
```

**1.2 — English**

```
• Slow Down Rádijo in the car: with CarPlay, start the live stream right from the car's screen and see the show and the song on air.
• Small fixes and improvements.
```

**1.2 — add to the App Review notes** (section 3, How to use it):

```
- CarPlay (CarPlay Audio entitlement granted to the team): connect an iPhone to a CarPlay car or head unit, or to Xcode's CarPlay Simulator. The app shows one item, "Živé vysílání" / "Live" (the station's live stream, with the show on air and the song when known); tapping it starts the stream and opens the system Now Playing screen.
```

## Releasing a new version

1. Raise `MARKETING_VERSION` in `project.yml` (app and widget, the same
   value) and commit.
2. On the Mac, Xcode closed: `git pull`, then `tools/release/upload.sh`.
   The build number is set from the time, nothing to edit.
3. App Store Connect → the app → iOS App → **+** next to the versions →
   the new version number. Fill in What's New (above), replace the
   screenshots if the app looks different, pick the build under "Build"
   once TestFlight has processed it.
4. Add for Review → Submit. A version can only be submitted once the
   previous one is out of review (approved, rejected or withdrawn).

## App Privacy (the privacy label)

Matches `SlowDownRadijo/PrivacyInfo.xcprivacy` and the privacy policy.
"Do you or your third-party partners collect data from this app?" → Yes.
Tracking → No for every type.

| Data type | What it is | Purposes | Linked to the user |
|---|---|---|---|
| Identifiers → User ID | The random anonymous ID behind the listening stats (Supabase) | App Functionality | Yes |
| Identifiers → Device ID | PostHog's random analytics ID, only with consent | Analytics | No |
| Usage Data → Product Interaction | Listening seconds per day and show; with consent, which features are used | App Functionality, Analytics | Yes |
| User Content → Audio Data | Voice messages the listener records and sends | App Functionality | No |
| User Content → Other User Content | The text of feedback messages | App Functionality | No |
| Diagnostics → Other Diagnostic Data | App and iOS version and device model sent with feedback | App Functionality | No |

Not collected: contact info, location, health, financial info, contacts,
browsing or search history, purchases, photos, crash data, sensitive
info.

## App Review information

Sign-in required: No.

Notes (as resubmitted for 1.0 after App Review asked for more
information under guideline 2.1; a screen recording from an iPhone on the
latest iOS goes in Attachment, as .mov/.mp4 or zipped):

```
1. SCREEN RECORDING
A screen recording made on an iPhone running the latest iOS is attached (App Review Information > Attachment). It starts at app launch and shows the typical flow: the live stream starting, the show, host and song on air, earlier songs, the sleep timer, the AirPlay picker, the weekly schedule with a show reminder, listening stats, recording and sending a voice message, and the menu (news, settings, feedback, language).
The app has no account registration or login, no user-generated content visible to other users (voice messages and feedback go privately to the station by e-mail), and no paid content or In-App Purchases.

2. PURPOSE AND AUDIENCE
Slow Down Rádijo is the official app of Slow Down Radio s.r.o., an internet radio station in Prague playing hip hop, soul, funk, jazz, Afrobeat and electronica hand-picked by its DJs. It is for the station's listeners who want to listen on iPhone without a browser: one tap to play live, in the background and from the lock screen, with what is on air (show, host, song), the weekly schedule with show reminders, a sleep timer, personal listening stats, and a way to send a voice message to the studio.

3. HOW TO USE IT
No login, setup or sample files are needed. Open the app; the live stream starts (or tap Play).
- Rádio tab: show, host and song on air. Tap the song to search it on Spotify; swipe it sideways for earlier songs. Moon icon: sleep timer. Round icon next to Play: AirPlay/Bluetooth output. Scroll down for the schedule; the bell sets a reminder before a show (asks for notification permission).
- Statistiky tab: the listener's own listening time.
- Vzkaz tab: record a voice message (asks for microphone permission), play it back, send it to the station.
- Menu (top left): station news, settings (language, listening stats on/off and delete, anonymous analytics consent), feedback form.
The app is in Czech and English (Menu > language). The song line appears only when the stream confirms the song; during talk and some mixtape shows there is none.

4. EXTERNAL SERVICES
- Live audio stream: Icecast servers of play.cz, the station's streaming provider.
- Supabase (EU/UK region): anonymous listening stats, the log of songs played, and the functions that deliver voice messages and feedback.
- Resend: e-mail delivery of voice messages and feedback to the station.
- slowdownradijo.cz (WordPress REST API): station news and the weekly programme.
- Apple iTunes Search API: artwork for the song on air.
- PostHog (EU): anonymous usage analytics, only after the user opts in.
- Spotify: opened through a search link when the user taps a song; no Spotify SDK or login.
No authentication provider, payment processor or AI service is used.

5. REGIONAL DIFFERENCES
None. The app works the same in all regions: it plays the station's single live stream, and the interface is in Czech and English.

6. THIRD-PARTY MATERIAL
The app plays only the station's own live broadcast, the same stream offered at slowdownradijo.cz. Slow Down Radio s.r.o. holds licences for the internet broadcasting of music from OSA (authors) and INTERGRAM (performers and producers). Show photos and logos belong to the station.
```

Keep it in step with the app: a new external service, account,
user-generated content or paid feature means updating these notes.

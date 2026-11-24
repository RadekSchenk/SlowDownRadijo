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

The 1.3 set (Morning Coffee with the contest card, chat, profile of `cevapcicidisko`, stats, programme, message, the contest page; taken with
`-storeDemo YES -contestDemo YES`, so any time of day) is in `appstore/screenshots/6.3/{cs,en}`
(upload these) and `appstore/screenshots/6.9/{cs,en}`.

From 1.4 the app is also an iPad app (`TARGETED_DEVICE_FAMILY` 1,2), so
App Store Connect also wants a 13" iPad set (2064 x 2752, or 2752 x 2064
in landscape). The screenshot job doesn't take them yet: for now from the
iPad Pro 13-inch simulator by hand, with the same launch arguments.

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

Poslouchej rádio, kde hudbu vybírají lidi, ne algoritmy. Nově s chatem posluchačů, profilem Slowridera a soutěžemi o ceny.

**Keywords**

radio,rádio,hiphop,rap,soul,funk,jazz,afrobeat,beats,groove,stream,živě,praha,chat,soutěž

**Description**

Slow Down Rádijo v kapse. Živé vysílání rádia, které hraje hip hop, soul, funk, jazz, afrobeat i elektroniku – a hlavně věci, které jinde neuslyšíš. Ruční kurátorský výběr hudby namísto automatických algoritmů.

CO APPKA UMÍ
• Živé vysílání na jedno klepnutí – i na pozadí, ze zamčené obrazovky, přes AirPlay a Bluetooth a v autě s CarPlay
• Chat posluchačů: piš si s ostatními i s moderátory během vysílání – stačí přezdívka, bez registrace
• Co se právě vysílá: pořad, moderátor a skladba, kterou jedním klepnutím najdeš na Spotify
• Skladby, které hrály před chvílí – stačí přejet prstem do strany
• Program na celý týden s popisy pořadů a připomínkou, když začíná tvůj oblíbený
• Tvoje statistiky poslechu: dnešek, týden, celkový čas, oblíbené pořady a místo mezi posluchači
• Profil Slowridera: s volitelným účtem si změníš přezdívku a statistiky ti zůstanou i na novém telefonu
• Soutěže o ceny od rádia – odpověz na otázku přímo v appce (pro Slowridery s účtem)
• Hlasový vzkaz do rádia – nahraj pozdrav nebo přání a pošli ho moderátorům
• Kvalita zvuku podle připojení: na Wi-Fi naplno, na datech úsporně
• Časovač vypnutí, novinky z rádia a widget na plochu
• Česky i anglicky

BEZ REKLAM, ÚČET JEN KDYŽ CHCEŠ
Appku používáš bez reklam a bez registrace – i do chatu můžeš psát jen s přezdívkou. Účet Slowridera je dobrovolný. Statistiky poslechu jsou anonymní a můžeš je kdykoli vypnout i smazat. Měření používání appky se zapne jen s tvým souhlasem.

Zpomal se Slow Down Rádijem.
Tohle algoritmus neumí.
No music. No life.

## English

**Subtitle**

Hip hop, soul, jazz and funk

**Promotional text**

Listen to radio where people pick the music, not algorithms. Now with a listeners' chat, Slowrider profiles and contests with prizes.

**Keywords**

radio,hiphop,rap,soul,funk,jazz,afrobeat,beats,groove,stream,live,online,prague,czech,chat,contest

**Description**

Slow Down Rádijo in your pocket. The live stream of a radio station playing hip hop, soul, funk, jazz, Afrobeat and electronica – and above all, music you won't hear anywhere else. Hand-picked by people, not by algorithms.

WHAT IT DOES
• The live stream in one tap – in the background, from the lock screen, over AirPlay and Bluetooth, and in the car with CarPlay
• Listeners' chat: talk with other listeners and the hosts during the show – just pick a nickname, no sign-up
• What's on air: the show, the host and the song, which you can find on Spotify in one tap
• The songs that played a moment ago – just swipe sideways
• The whole week's schedule with show descriptions and a reminder when your favourite starts
• Your listening stats: today, this week, all time, your favourite shows and where you are among listeners
• Slowrider profile: with an optional account you can change your nickname and keep your stats on a new phone
• Contests with prizes from the station – answer the question right in the app (for Slowriders with an account)
• Voice messages to the station – record a shout-out or a request and send it to the hosts
• Sound quality to match your connection: full quality on Wi-Fi, data-saving on mobile
• A sleep timer, news from the station and a Home Screen widget
• In Czech and English

NO ADS, AN ACCOUNT ONLY IF YOU WANT ONE
No ads and no sign-up – you can even write in the chat with just a nickname. A Slowrider account is optional. Listening stats are anonymous, and you can turn them off and delete them at any time. Usage measurement only starts with your consent.

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

**1.3 — Czech**

```
• Chat posluchačů: piš si s ostatními i s moderátory během vysílání. Stačí přezdívka.
• Profil Slowridera: přezdívka, tvoje čísla a oblíbené pořady. S účtem (Apple, Google, e-mail) si změníš přezdívku a statistiky ti zůstanou.
• Nové statistiky: dnešek a týden na první pohled, místo mezi posluchači.
• Lepší zvuk: na Wi-Fi ve vysoké kvalitě, na datech úsporně.
• V autě začne rádio hrát hned po otevření.
• Soutěže: když rádio vyhlásí soutěž, uvidíš ji na úvodní obrazovce. Odpověz, nech nám telefon a hraj o ceny. Soutěžit můžou Slowriders s účtem.
```

**1.3 — English**

```
• Listeners' chat: talk with other listeners and the hosts during the show. Just pick a nickname.
• Slowrider profile: your nickname, your numbers and favourite shows. With an account (Apple, Google, e-mail) you can change your nickname and keep your stats.
• New stats: today and this week at a glance, and where you are among listeners.
• Better sound: high quality on Wi-Fi, data-saving on mobile.
• In the car, the radio starts playing as soon as you open the app.
• Contests: when the station runs a contest, you'll see it on the home screen. Answer, leave your phone number and play for prizes. Open to Slowriders with an account.
```

**1.4 — Czech**

```
• Zimní vzhled: od první adventní neděle do Tří králů v appce sněží a slunce v logu se mění ve vánoční ozdobu. Kdo nechce, vypne ho v Nastavení.
• Zimní ikona na sezónu.
• Budík s rádiem: ráno tě vzbudí živé vysílání. Nastavíš ho pod časovačem vypnutí (iOS 26 a novější).
• Statistiky: týdenní a měsíční žebříček, takže šanci má každý — i kdo poslouchá teprve chvíli. Nově i dny v řadě.
```

**1.4 — English**

```
• Winter look: from the first Sunday of Advent to Epiphany it snows in the app and the sun in the logo turns into a Christmas bauble. You can turn it off in Settings.
• A winter icon for the season.
• Radio alarm: wake up to the live broadcast. Set it under the sleep timer (iOS 26 and later).
• Stats: weekly and monthly leaderboards, so everyone has a chance — even if you've only just started listening. Plus your days in a row.
```

Release 1.4 manually on 29 Nov 2026, and the version that brings the normal
icon back on 7 Jan 2027 (`docs/winter.md`).

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
| Contact Info → Email Address | The account's e-mail (1.3: optional account, only to write in the chat) | App Functionality | Yes |
| Contact Info → Phone Number | 1.3: the phone number a Slowrider leaves when entering a contest, to contact the winner; deleted 30 days after the draw | App Functionality | Yes |
| Identifiers → User ID | The random anonymous ID behind the listening stats, which becomes the account when the listener signs in; the chat nickname | App Functionality | Yes |
| Identifiers → Device ID | PostHog's random analytics ID, only with consent | Analytics | No |
| Usage Data → Product Interaction | Listening seconds per day and show; with consent, which features are used | App Functionality, Analytics | Yes |
| User Content → Audio Data | Voice messages the listener records and sends | App Functionality | No |
| User Content → Other User Content | Chat messages (public in the app, with the nickname); the text of feedback messages | App Functionality | Yes |
| Diagnostics → Other Diagnostic Data | App and iOS version and device model sent with feedback | App Functionality | No |

Not collected: name, location, health, financial info, contacts,
browsing or search history, purchases, photos, crash data, sensitive
info.

## App Review information

Sign-in required: No — the chat works without an account too (a nickname with
the first message); only changing the nickname and the Slowrider profile need
one (1.3). Sign in with Apple works for App Review; to be safe, add a demo
account in App Store Connect (an e-mail address the station can read, so the
code can be passed on).

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

**Notes for 1.3** (the whole field, about 3,100 of the 4,000 characters; replaces the 1.0 notes above):

```
1. SCREEN RECORDING
A screen recording from an iPhone on the latest iOS is attached. It shows the live stream starting, the show, host and song on air, earlier songs, the sleep timer, the output picker, the weekly schedule with a reminder, the listeners' chat, the contest card and page, the Profil tab, listening stats, a voice message and the menu.

2. PURPOSE AND AUDIENCE
Slow Down Rádijo is the official app of Slow Down Radio s.r.o., an internet radio station in Prague playing hip hop, soul, funk, jazz, Afrobeat and electronica hand-picked by its DJs. For listeners: one tap to play live, in the background and from the lock screen and CarPlay, with what is on air, the weekly schedule, a sleep timer, personal listening stats, voice messages to the studio and a listeners' chat.

3. HOW TO USE IT
Open the app; the live stream starts (or tap Play).
- Rádio: show, host and song on air (tap the song for Spotify, swipe for earlier songs); moon icon: sleep timer; the Chat section opens the chat; the schedule with reminders below.
- Statistiky: the listener's own listening time and anonymous leaderboard.
- Vzkaz: record a voice message (microphone permission) and send it to the station.
- Profil: optional account (see 7).
- Menu (top left): news, settings (language, sound quality, stats on/off and delete, analytics consent), feedback.
Czech and English. The song line appears only when the stream confirms the song.

4. EXTERNAL SERVICES
- Live audio: Icecast servers of play.cz, the station's streaming provider.
- Supabase (UK region): listening stats, songs played, the optional account and sign-in (Supabase Auth with Sign in with Apple, Google and e-mail codes), the chat, and delivery of voice messages and feedback.
- Resend: e-mail for voice messages, feedback and sign-in codes.
- slowdownradijo.cz (WordPress REST API): news and the weekly programme.
- Apple iTunes Search API: artwork for the song on air.
- PostHog (EU): anonymous usage analytics, only after the user opts in.
- Spotify: a search link when the user taps a song; no SDK or login.
No payment processor or AI service.

5. REGIONAL DIFFERENCES
None: one live stream, interface in Czech and English.

6. THIRD-PARTY MATERIAL
The app plays only the station's own live broadcast, the same stream as at slowdownradijo.cz. Slow Down Radio s.r.o. holds licences for internet broadcasting from OSA and INTERGRAM. Show photos and logos belong to the station.

7. ACCOUNT AND LISTENERS' CHAT (NEW IN 1.3)
Anyone can read and write in the chat: the first message asks for a nickname, no account needed. An optional account (Sign in with Apple, Google or an e-mail code) lets the listener change the nickname and keeps the profile and stats on a new phone. Delete it in the app: Profil > Smazat účet.
Safeguards (guideline 1.2): chat rules in Profil > Pravidla chatu; press and hold a message to report it or hide its author; the station's hosts and admins moderate (delete, mute for 1 h / 24 h / 7 days, block); anti-spam limits (5 messages per 30 s, no repeats within a minute, links only from accounts); reports are reviewed by the station; contact info@slowdownradijo.cz.

8. CONTESTS (NEW IN 1.3, GUIDELINE 5.3)
When the station runs a contest, a yellow card appears on the Rádio tab (it can be closed for good). The contest page shows the text, the prize, the end date, a link to the official rules (slowdownradijo.cz/pravidla-soutezi/) and the question. Entering needs a free account; the listener answers and leaves a phone number, used only to contact the winner. Entry is free, no purchase. The sponsor is Slow Down Radio s.r.o.; the page says that Apple and Google are not sponsors. Winners are drawn at random in the app by the station's admins. If no contest is running during review, the card is not shown.
```

Keep it in step with the app: a new external service, account,
user-generated content or paid feature means updating these notes.

# Vydání v App Storu – checklist

*Stav k 14. 10. 2026. ✅ hotovo · ⬜ zbývá · ⚠️ rozhodnutí / riziko*

## 1. Blokující (bez toho appku poslat nejde)

- ⬜ **Placený Apple Developer Program** (99 USD/rok). Nejlépe jako organizace
  Slow Down Radio s.r.o. (potřebuje D-U-N-S číslo, vyřízení trvá i 1–2 týdny),
  jinak na osobu. Na App Storu se pak jako prodejce zobrazí to jméno.
- ⬜ **Zásady ochrany osobních údajů na webu.** Appka odkazuje na
  `https://slowdownradijo.cz/ochrana-osobnich-udaju/` a ta stránka teď vrací 404.
  Obsah je hotový v `PRIVACY_POLICY.md`; doplnit datum a vystavit na tuto adresu
  (bez komentáře s Google Analytics na konci). Stejnou URL zadat do App Store
  Connect.
- ⬜ **Supportní URL** pro App Store Connect, např. `https://slowdownradijo.cz/kontakt/`
  nebo stránka s e-mailem.
- ⬜ **Snímky obrazovky** iPhone 6,9" (1320 × 2868), stačí jedna sada, 3–10 kusů.
  Návrh: Rádio (hraje), Pořady, Statistiky, Vzkaz, Podpora.

## 2. Rizika při schvalování

- ✅ **Záložka Podpora (pravidlo 3.1.1)** – *rozhodnuto 14. 10. 2026: nechat,
  jak je, a vysvětlit recenzentovi* (viz poznámka níže). Ukazuje ceny členství,
  výhody a odkazy na Herohero/Patreon/Forendors. Kdyby Apple přesto odmítl,
  záložku zjednodušit na jedno tlačítko „Podpořte nás na webu“ bez cen a výhod.
- ✅ **Práva k vysílání** – vysvětleno v poznámce pro recenzenta: oficiální
  appka rádia, vlastní stream, licence OSA/Intergram.
- ✅ Mikrofon se žádá jen při nahrávání vzkazu; popis česky i anglicky.
- ✅ Notifikace se nežádají při spuštění, jen v kontextu (zvoneček u pořadu,
  Novinky).
- ✅ Analytika jen se souhlasem, bez reklamního ID (ATT dialog není potřeba).
- ✅ Bez účtu, takže povinnost „smazat účet“ se netýká; statistiky jde smazat v Nastavení.

## 3. App Store Connect – údaje

| Pole | Návrh |
|---|---|
| Název | Slow Down Rádijo |
| Podtitul (30 znaků) | Nezávislé rádio z Prahy |
| Kategorie | Hudba (vedlejší: Zábava) |
| Věkové hodnocení | 4+ (žádný nevhodný obsah; pokud se ve vysílání objevují vulgarismy v písních, zvolit „Občasné/mírné vulgarismy“ → 12+) |
| Cena | Zdarma |
| Copyright | 2026 Slow Down Radio s.r.o. |
| Šifrování | v Info.plist už je „nepoužívá“, App Store Connect se nebude ptát |
| Jazyky | čeština, angličtina |

**Popis (CZ)**

> Slow Down Rádijo v kapse. Poslouchej živé vysílání, sleduj, který pořad
> a moderátor zrovna hraje, a nech si poslat upozornění, když začíná tvůj
> oblíbený pořad.
>
> • Živý stream jedním klepnutím, i na zamčené obrazovce a ve sluchátkách
> • Program na celý týden a co hraje právě teď
> • Upozornění na začátek pořadů
> • Časovač vypnutí
> • Statistiky tvého poslechu
> • Hlasový vzkaz do vysílání
> • Novinky z rádia

**Description (EN)**

> Slow Down Rádijo in your pocket. Listen live, see which show and host are on
> air, and get a heads-up when your favourite show starts.
>
> • Live stream in one tap, on the lock screen and with headphones
> • The week's schedule and what's playing now
> • Show start reminders
> • Sleep timer
> • Your listening stats
> • Voice messages to the studio
> • Station news

**Klíčová slova**: rádio,radio,stream,Praha,hudba,živě,nezávislé,soul,jazz,hip hop

**Poznámka pro recenzenta (anglicky)** – vložit do App Review Information ▸ Notes

> This is the official app of Slow Down Rádijo, an independent radio station
> based in Prague, published by the station's operator, Slow Down Radio s.r.o.
>
> Streaming rights: the app plays only the station's own live stream, the same
> stream the station broadcasts on its website (slowdownradijo.cz). The station
> holds the music licences for online broadcasting from the Czech collecting
> societies OSA (authors) and Intergram (performers and producers).
>
> Support tab: listeners can choose to support the station through its existing
> pages on Herohero, Patreon or Forendors, which open in a browser view. These
> are voluntary memberships supporting the radio station itself. They do not
> unlock any content or features in the app: the app is fully free and every
> feature is available to everyone. The perks (recordings, behind-the-scenes
> posts, contests, a merch discount) are delivered outside the app by those
> platforms. No purchases or payments take place in the app.
>
> No account or login is needed. The microphone is used only when the listener
> records a voice message for the station (Message tab); the recording is sent
> to the station by e-mail. Notifications are local reminders when a followed
> show starts, and news from the station. Anonymous usage analytics (PostHog,
> EU) run only after the listener opts in; no advertising identifier is used.
>
> The interface is in Czech and English; switch with the CZ/EN button at the
> top of the screen.

## 4. Štítky soukromí (App Privacy)

Odpovídají `PrivacyInfo.xcprivacy` a `docs/analytics-events.md`, oddíl 5.

| Data | Účel | Propojeno s identitou | Sledování |
|---|---|---|---|
| Identifiers ▸ User ID (anonymní ID statistik) | App Functionality | Ano | Ne |
| Identifiers ▸ Device ID (náhodné ID PostHogu) | Analytics | Ne | Ne |
| Usage Data ▸ Product Interaction | App Functionality, Analytics | Ano (statistiky) | Ne |
| User Content ▸ Audio Data (vzkaz) | App Functionality | Ne | Ne |
| User Content ▸ Other User Content (zpětná vazba) | App Functionality | Ne | Ne |
| Diagnostics ▸ Other Diagnostic Data | App Functionality | Ne | Ne |

## 5. Postup nahrání

1. `git pull`, `xcodegen generate`, v Xcode vybrat **Any iOS Device (arm64)**.
2. Product ▸ **Archive** → Organizer ▸ **Distribute App** ▸ App Store Connect ▸ Upload.
3. V App Store Connect: nová appka (bundle ID `cz.slowdownradijo.app`), vyplnit
   oddíl 3 a 4, vybrat nahraný build.
4. Nejdřív **TestFlight** (interní testeři, bez schvalování) – projít na pár
   telefonech, pak **Odeslat ke kontrole**.
5. Každé další nahrání: zvýšit `CURRENT_PROJECT_VERSION` v `project.yml`
   (u appky i widgetu).

## 6. Před vydáním ještě

- ⬜ Ověřit na telefonu poslední opravy: otevření z upozornění, widget,
  karta souhlasu, přepínač analytiky, jazyk.
- ⬜ Projít appku v angličtině (anglicky nastavený telefon nově startuje v EN).
- ⬜ `schedule.json` odpovídá aktuálnímu programu.
- ⬜ Rozhodnout, zda smazat testovací data statistik (teď 2 posluchači, oba vaše
  zařízení). Není nutné.
- ⬜ PostHog: zkontrolovat, že je zapnuté „Discard client IP data“.

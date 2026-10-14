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

- ⚠️ **Záložka Podpora (pravidlo 3.1.1).** Ukazuje ceny členství
  (8 €, 170 Kč, 160 Kč), výhody a odkazy na Herohero/Patreon/Forendors. Apple
  může takové odkazy na placená členství mimo In-App Purchase odmítnout.
  Možnosti:
  1. nechat a v poznámce pro recenzenta vysvětlit, že jde o podporu rádia a výhody
     se v appce nečerpají (může projít, nemusí);
  2. **bezpečnější:** bez cen a výhod, jen text „Rádio můžeš podpořit na webu“
     a jedno tlačítko na `slowdownradijo.cz/podpora`, otevřené v Safari;
  3. první verzi poslat bez záložky Podpora a přidat ji později.
- ⚠️ **Práva k vysílání.** Recenzent se může zeptat, jestli máte právo stream
  šířit. Do poznámek uvést, že appka je oficiální appka rádia a hraje jeho
  vlastní stream (OSA/Intergram licence má rádio pro web).
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

**Poznámka pro recenzenta (anglicky)**

> Official app of Slow Down Rádijo, an independent radio station in Prague.
> No account is needed. The app plays the station's own live stream. The
> microphone is used only when the listener records a voice message for the
> station (Message tab), which is sent to the station by e-mail. Notifications
> are local reminders when a followed show starts. Anonymous usage analytics
> (PostHog, EU) run only after opt-in. The UI language can be switched with the
> CZ/EN button in the header.

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

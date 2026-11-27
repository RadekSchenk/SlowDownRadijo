# Vydání 1.4 na iOS – checklist

*Připraveno 27. 11. 2026. Google Play zatím čeká na schválení 1.3, Android 1.4 řešíme zvlášť.*
*✅ hotovo · ⬜ zbývá · ⚠️ pozor*

Texty k vložení: `docs/app-store.md` (popis, propagační text, klíčová slova,
„Co je nového“ 1.4, poznámka pro recenzenta 1.4). Snímky:
`appstore/screenshots/`.

## 0. Termín

- ⚠️ Plán byl poslat 1.4 ke kontrole do ~26. 11. a vydat ručně **29. 11.
  ráno** (první adventní neděle, `docs/winter.md`). Kontrola u Applu trvá
  obvykle 1–2 dny. **Poslat co nejdřív**, nejpozději 28. 11. dopoledne. Když
  schválení nestihne 29. 11., nic se nestane: sněžení se zapne samo, jakmile
  posluchač verzi má, jen zimní ikona přijde později.

## 1. Kód do main (GitHub)

1.4 je rozdělená do PR, které na sebe navazují. Slučovat zdola nahoru, po
každém sloučení GitHub přesměruje další PR na `main`:

1. ⬜ [#10](https://github.com/RadekSchenk/SlowDownRadijo/pull/10) zimní vzhled, žebříčky, budík → `main`
2. ⬜ [#12](https://github.com/RadekSchenk/SlowDownRadijo/pull/12) tablety
3. ⬜ [#13](https://github.com/RadekSchenk/SlowDownRadijo/pull/13) analytika 1.4
4. ⬜ [#14](https://github.com/RadekSchenk/SlowDownRadijo/pull/14) odpovědi v chatu (+ oprava scrollování, + Keychain)
5. ⬜ [#11](https://github.com/RadekSchenk/SlowDownRadijo/pull/11) hledání moderátorů ve správě (samostatné, do `main`)

Verze je už nastavená: `MARKETING_VERSION` 1.4 v `project.yml`,
`versionName` 1.4 na Androidu.

## 2. Supabase – migrace na produkci (před odesláním ke kontrole)

Recenzent i posluchači 1.4 je potřebují. Verzi 1.3 nevadí, můžou jít hned.

- ⬜ `backend/supabase/sql/029_period_ranking.sql` – týdenní a měsíční žebříček
- ⬜ `backend/supabase/sql/030_chat_replies.sql` – odpovědi v chatu (až po 029)
- ✅ `029_admin_find_hosts.sql` – už na produkci

Spustit v Supabase → SQL Editor (celý soubor), nebo mi řekni a pustím je.
Kontrola: v TestFlightu ukazují Statistiky místo v týdnu/měsíci a odpověď
v chatu se odešle.

## 3. Build

- ✅ TestFlight 2611272027 (celá 1.4 + oprava scrollování) – na otestování.
- ⬜ Na skutečném iPhonu projít:
  - scrollování chatu nahoru a dolů, odpověď swipem i podržením, skok na citaci,
    „↳ tobě“ na úvodní obrazovce,
  - **budík s rádiem** (v simulátoru nejde ověřit): nastavit za pár minut,
    nechat appku běžet se zamčeným telefonem, pak totéž s appkou zavřenou
    (zazvoní systémový budík → „Pustit rádio“),
  - žebříček týden/měsíc, zimní vzhled (od 29. 11.; vypíná se v Nastavení),
  - iPad: otáčení, chat, statistiky.
- ⬜ Po sloučení do `main` nahrát finální build (Xcode zavřený):
  `git switch main && git pull && tools/release/upload.sh`.
  Nebo poslat ke kontrole přímo 2611272027, obsahuje totéž.

## 4. App Store Connect → iOS App → **+** → verze **1.4**

- ⬜ **Snímky iPhone** (slot 6,3"/6,1"): `appstore/screenshots/6.3/cs` a `/en`
  (7 kusů, pořadí podle čísla v názvu; připravené ✅). Velikost 6,9" je
  v `6.9/`, kdyby ji App Store Connect chtěl.
- ⬜ **Snímky iPad 13"** – nově povinné, appka je od 1.4 i pro iPad:
  `appstore/screenshots/ipad-13/cs` a `/en` (2064 × 2752, 7 kusů; připravené ✅).
- ⬜ **Propagační text** (cs, en) – nový, `docs/app-store.md`.
- ⬜ **Popis** (cs, en) – doplněný budík, odpovědi, žebříčky a iPad.
- ⬜ **Klíčová slova** – přibylo „budík“ / „alarm“ (EN bez „online“, kvůli limitu 100).
- ⬜ **Co je nového ve verzi 1.4** (cs, en) – `docs/app-store.md`, oddíl What's New.
- ⬜ **Build**: vybrat 2611272027 (nebo finální z `main`).
- ⬜ **App Review Information → Notes**: celý blok „Notes for 1.4“
  (~3 300 znaků). Příloha s nahrávkou obrazovky může zůstat z 1.3.
- ⬜ **Version Release**: „Manually release this version“.
- ⬜ App Privacy: beze změny (odpovědi jsou obsah chatu, budík je jen v telefonu).
- ⬜ Add for Review → Submit.

⚠️ Riziko u kontroly: budík drží appku přes noc naživu tichým zvukem
(pravidlo 2.5.4). Poznámka pro recenzenta to vysvětluje. Kdyby to Apple
vrátil, stačí nevolat `RadioAlarmNightWatch.start()` a zůstane jen systémový
budík (`docs/radio-alarm.md`).

## 5. Vydání

- ⬜ **29. 11. ráno**: App Store Connect → 1.4 → Release This Version.
- ⬜ PostHog: na dashboardu přehledy „Budík s rádiem“ a „Statistiky: který
  žebříček“ a nové `chat_reply_started` / `is_reply` u `chat_message_sent`.

## 6. Potom

- ⬜ **1.4.1 s normální ikonou** (`docs/winter.md`): v `project.yml` zpět
  `AppIcon`. Poslat ke kontrole začátkem prosince (Apple má 23.–27. 12. omezený
  provoz), vydat ručně **7. 1. 2027**.
- ⬜ Android 1.4, až Google schválí 1.3: nové screenshoty pro Google Play
  (`StoreScreenshotTest`), texty z `docs/google-play.md`.

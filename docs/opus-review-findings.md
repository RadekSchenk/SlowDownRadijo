# Nezávislá revize: nálezy (fáze 1, žádné změny kódu)

*Větev `review/opus-audit` z `claude/adoring-tesla-bj752w` (commit `8f6d32f`).
Postup podle `docs/opus-review-brief.md`.*

**Jak se ověřovalo**
- Swift jsem jen četl, nic nepřekládal. U každého nálezu z appky je
  uvedeno, jestli jde o zjevnou chybu při čtení kódu, nebo jestli ji nejde
  ověřit bez překladu či zařízení. Nic z appky není otestované.
- SQL 005–008 jsem spustil na **lokálním** Postgresu 16. Schéma `auth`,
  funkci `auth.uid()` a role `anon`/`authenticated` jsem napodobil podle
  Supabase. Výstupy uvádím u jednotlivých nálezů.
- Na ostrém projektu Supabase jsem zavolal jen `get_advisors` (pouze
  čtení). Nic jsem nezapsal ani nezměnil, žádný SQL dotaz ani migrace.
- Tajemství: v repu ani v historii gitu jsem nenašel jiný klíč než
  záměrně veřejný `sb_publishable_…`. Hledal jsem `sb_secret`, `service_role`
  JWT, `re_…` a `sk_…`. V README jsou jen zástupné hodnoty `re_xxxx`.

## Stav oprav (fáze 2)

Všech 16 nálezů je opraveno, každý v samostatném commitu na této větvi.
Nález 1 má navíc jeden navazující commit. Nic z toho není přeložené ani
nasazené.

- **Appka (1, 2, 4, 5, 9–16):** Swift jsem nepřekládal, je potřeba
  ho přeložit v Xcode a vyzkoušet na zařízení: zaseknutí streamu, hovor
  během přehrávání, časovač spánku při výpadku sítě, VoiceOver.
- **SQL (3, 6, 7, 8):** nové soubory `009`–`012`, otestované na lokálním
  Postgresu. Na ostrý projekt je musí v SQL Editoru spustit správce, a to
  v pořadí podle `backend/README.md`. U `011` po nasazení zkontrolovat, že
  v logu není „auth user not deleted“.
- **Edge Functions (8):** typově zkontrolované přes `tsc`. Je potřeba je
  znovu nasadit (`send-voice-message`, `send-feedback`). Kontrola formátu
  vzkazu předpokládá, že nahrávka z appky začíná boxem `ftyp` (standard
  u .m4a z `AVAudioRecorder`). Před vydáním odeslat jeden zkušební vzkaz.

## Přehled

| Závažnost | Počet | Nálezy |
|---|---|---|
| vysoká | 3 | 1, 2, 3 |
| střední | 5 | 4, 5, 6, 7, 8 |
| nízká | 8 | 9–16 |
| nepotvrzené | 7 | sekce na konci |

Zkrácená mapa: dvě nejvážnější chyby jsou v přehrávači. Stav `PlaybackState`
přestane odpovídat skutečnosti po zaseknutí streamu (1) a po přerušení
hovorem (2). Na tomtéž stavu stojí i měření poslechu, takže se chyba
přenáší do statistik. Na backendu `get_my_stats` prozrazuje komunitní
čísla ještě před dosažením prahu (3).

---

### 1. Po zaseknutí streamu zůstane přehrávač napořád ve stavu „připojuji“, tlačítko nejde použít
- Závažnost: vysoká
- Oblast: C (a B, měření)
- Místo: `SlowDownRadijo/Services/RadioPlayerService.swift:156-162`, `:141-154`, `:62-63`; `SlowDownRadijo/Views/Home/PlayButton.swift:39`
- Co je špatně: notifikace `AVPlayerItemPlaybackStalled` přepne stav na
  `.connecting`. Zpět na `.playing` ho ale vrací jen KVO na `item.status` a
  ten se při obnovení po zaseknutí nemění, protože zůstává `.readyToPlay`.
- Postup, jak k chybě dojde: posluchač poslouchá na mobilních datech a
  projede tunelem. Přijde `PlaybackStalled` a stav je `.connecting`. AVPlayer
  (`automaticallyWaitsToMinimizeStalling = true`) po návratu signálu sám
  pokračuje, hudba hraje, ale stav zůstane `.connecting`. Následky:
  - Hlavní tlačítko ukazuje spinner a je `.disabled(state == .connecting)`,
    takže v appce nejde pauza.
  - `togglePlayPause()` v `.connecting` nedělá nic (`case .connecting: break`).
    Nefunguje tedy ani play/pause na sluchátkách, protože jde přes
    `togglePlayPauseCommand`.
  - `ListeningTracker` přestane počítat čas (`update(isPlaying: state == .playing)`).
  - `ShimmerText` „Připojuji…“ běží v `TimelineView(.animation)` donekonečna.
  - Když se stream neobnoví vůbec, nespustí se žádný reconnect, protože žádný
    časový limit pro `.connecting` neexistuje.
- Důkaz: v souboru je jediné místo, které nastavuje `state = .playing`
  (ř. 146), a to uvnitř `case .readyToPlay` pozorování `\.status`. Nikde se
  nepozoruje `timeControlStatus` ani `rate`
  (`grep timeControlStatus` → 0 výsledků). Na zařízení jsem to neověřoval.
- Návrh opravy: místo (nebo vedle) `PlaybackStalled` pozorovat
  `player.timeControlStatus`: `.playing` → `.playing`,
  `.waitingToPlayAtSpecifiedRate` → `.connecting`, a pro `.connecting` přidat
  časový limit, po kterém se spustí `scheduleReconnect()`.
- Cena opravy: malá až střední

### 2. Přerušení (hovor, Siri, budík, jiná appka) se neobsluhuje, stav zůstane „hraje“
- Závažnost: vysoká
- Oblast: C, B
- Místo: `SlowDownRadijo/Services/RadioPlayerService.swift` (celý soubor; chybí `AVAudioSession.interruptionNotification`)
- Co je špatně: když systém přehrávání přeruší, AVPlayer se zastaví, ale
  `state` zůstane `.playing`.
- Postup, jak k chybě dojde: rádio hraje a přijde hovor. Systém audio
  zastaví, `state == .playing` se nezmění. Po hovoru živý stream sám
  nepokračuje. Následky:
  - Appka (i zamykací obrazovka) dál ukazuje „hraje“.
  - Tlačítko ukazuje pauzu. První klepnutí zavolá `pause()`, rádio se tedy
    pustí až na druhé klepnutí.
  - `ListeningTracker` počítá „poslech“, dokud je proces naživu. Když je
    appka v popředí, třeba posluchač po hovoru appku otevře, přičítá se
    10 s na každý tik do té doby, než posluchač něco zmáčkne. Do statistik
    a žebříčku tak teče čas ticha.
  - Stejně se to chová, když posluchač pustí video nebo hlasovou zprávu
    v jiné appce.
- Důkaz: `grep -rn "interruption" SlowDownRadijo/` → 0 výsledků. Nelze ověřit
  bez zařízení, ale chování AVPlayeru při přerušení je dobře známé a kód
  na něj nijak nereaguje.
- Návrh opravy: pozorovat `AVAudioSession.interruptionNotification`. Na
  `.began` nastavit `state = .paused`. Na `.ended` s `.shouldResume` zavolat
  `play()`, který otevře nový item, protože u živého streamu je to
  spolehlivější. Případně stačí nález 1 přes `timeControlStatus`, kde se
  přerušení projeví jako `.paused`.
- Cena opravy: malá

### 3. `get_my_stats` prozradí komunitní součet a počet posluchačů i před dosažením prahu
- Závažnost: vysoká (soukromí, slib v 007 a v zásadách)
- Oblast: A
- Místo: `backend/supabase/sql/006_community_archive.sql:326-337` (aktuální verze `get_my_stats`); slib v `007_public_stats.sql:8-10`
- Co je špatně: `public_stats()` vrací do odemčení nuly, „aby se součty
  několika prvních posluchačů nikdy nezveřejnily“. `get_my_stats()` ale
  vrací `community_seconds` a `ranked_listeners` bez ohledu na `available`.
  Volat ho smí každý `authenticated` a anonymní účet si s veřejným
  publishable klíčem založí kdokoli (`POST /auth/v1/signup`).
- Postup, jak k chybě dojde: v appce poslouchá jediný člověk (nebo pár
  lidí). Kdokoli si založí anonymní účet a zavolá
  `/rest/v1/rpc/get_my_stats`. Při jednom dalším posluchači je
  `community_seconds` přímo jeho celkový čas. Opakovaným voláním se dá
  sledovat, kdy a kolik poslouchá (rozdíly mezi voláními).
- Důkaz (lokální Postgres, dva posluchači s 5 000 s a 43 200 s, prah
  nedosažen, volá třetí, úplně nový uživatel):
  ```
  public_stats (anon) | {"available": false, "ranked_listeners": 0, "community_seconds": 0}
  get_my_stats (new user) | {"rank": null, "daily": [], "available": false,
                             "total_seconds": 0, "ranked_listeners": 2, "community_seconds": 48200}
  ```
  Appka tato čísla do odemčení skryje (`StatsView.swift:60`, `:92`), na
  serveru ale volně dostupná jsou.
- Návrh opravy: v `get_my_stats` vracet `community_seconds`,
  `ranked_listeners` a `rank` jen když `stats_available()`, jinak 0 a `null`,
  stejně jako `public_stats`. Jedna nová SQL migrace (`009_…`). Appka
  potřebuje jen to, co už dnes dělá.
- Cena opravy: malá

### 4. Automatické znovupřipojení přežije pauzu i časovač spánku
- Závažnost: střední
- Oblast: C
- Místo: `SlowDownRadijo/Services/RadioPlayerService.swift:72-76` (`pause()`), `:181-188` (`scheduleReconnect`), `:102-106` (časovač spánku); `SlowDownRadijo/Services/PreviewPlayerService.swift:107`
- Co je špatně: `pause()` nezruší `reconnectTimer`. Když je naplánované
  znovupřipojení, rádio se po pauze samo znovu rozehraje.
- Postup, jak k chybě dojde:
  - (a) V posteli se zapnutým časovačem spánku vypadne Wi-Fi a stav je
    `.error`, reconnect je naplánovaný za 2–30 s. Časovač vyprší a zavolá
    `pause()`, potom `reconnectTimer` spustí `startPlayback()` a rádio hraje
    dál celou noc.
  - (b) Při výpadku posluchač stiskne pauzu na zamykací obrazovce
    (`pauseCommand` → `pause()`) a rádio se samo pustí.
  - (c) Při výpadku si posluchač pustí ukázku skladby a rádio začne hrát
    přes ni.
  - Navíc v `.error` stavu `togglePlayPause()` volá `play()`, takže pauza
    přes sluchátka v tomto stavu nejde vůbec.
- Důkaz: `pause()` obsahuje jen `player?.pause(); state = .paused; …`.
  `reconnectTimer?.invalidate()` je pouze v `scheduleReconnect()` a `deinit`.
- Návrh opravy: v `pause()` (a na začátku `play()`) přidat
  `reconnectTimer?.invalidate(); reconnectTimer = nil`. V `.error` stavu by
  `togglePlayPause` měl spíš zastavit znovupřipojování.
- Cena opravy: malá

### 5. Rozvrh se vyhodnocuje v časovém pásmu telefonu, ne v pražském
- Závažnost: střední
- Oblast: B, C
- Místo: `SlowDownRadijo/Services/ScheduleStore.swift:36-47`, `:101-106` (výchozí `calendar: .current`); používá `NowPlayingViewModel.swift:60-62` (atribuce poslechu), `:106-109` (časovač „Konec pořadu“) a widget `NowPlayingProvider.swift`
- Co je špatně: backend (`collect-now-playing/index.ts:50-56`) výslovně
  počítá v `Europe/Prague`, appka i widget v časovém pásmu zařízení.
- Postup, jak k chybě dojde: posluchač v Londýně (nebo Čech na dovolené)
  poslouchá ve 21:00 svého času, v Praze je 22:00. Appka ukáže a do
  `listening_daily.show_id` zapíše pořad z 21:00. Čas se tak připíše
  špatnému pořadu, „Pořad končí za…“, časovač „Konec pořadu“ i widget jsou
  posunuté o hodinu. V USA jsou posunuté o 6–9 hodin.
- Důkaz: v appce není nikde `TimeZone(identifier: "Europe/Prague")`
  (`grep` najde jen backend). Totéž přiznává
  `docs/catalog-data-model.md` §5. Jde o zjevnou chybu při čtení kódu.
- Návrh opravy: ve `ScheduleStore` použít jako výchozí `Calendar` gregoriánský
  s `timeZone = Europe/Prague` (jedno místo, použije ho appka i widget). Den
  pro „Dnes“ ve statistikách nechat podle telefonu, jak je zamýšleno.
- Cena opravy: malá

### 6. Smazání (ruční i po 24 měsících) nechává anonymního uživatele a ID se dál používá
- Závažnost: střední
- Oblast: A, D
- Místo: `backend/supabase/sql/005_listener_stats.sql:222-234` (`delete_my_listening_data`), `006_community_archive.sql:282-301` (`prune_inactive_listeners`); `SlowDownRadijo/Services/Stats/ListeningTracker.swift:137-143`; `PRIVACY_POLICY.md:24-25`
- Co je špatně: obě cesty mažou jen řádek v `listeners` a to, co na něm
  kaskádou visí. Řádek v `auth.users` zůstává navždy, stejně jako jeho
  relace a refresh token, které Supabase drží v `auth.sessions` a
  `auth.refresh_tokens`. Appka si relaci nechá v Keychainu, takže po
  „smazání“ další poslech zapisuje pod **stejným** ID.
- Postup, jak k chybě dojde: posluchač dá „Smazat moje statistiky“ a pak
  znovu poslouchá. `record_listening` založí `listeners` se stejným `uid`.
  Zásady přitom slibují, že data „zmizí úplně“ a že po 24 měsících
  „odstraníme celý tvůj záznam“. Anonymní ID, čas jeho vzniku a čas
  posledního přihlášení ale zůstávají. Podle verze GoTrue drží
  `auth.sessions` i IP adresu a user-agent, což na ostrém projektu
  neověřeno, viz nepotvrzené.
- Důkaz (lokálně): po `delete_my_listening_data()` je
  `select count(*) from auth.users` stále 3 z 3. V kódu `deleteAllData()`
  nemaže `KeychainStore` (volá jen `deleteMyData()`).
- Návrh opravy: ruční smazání nechat mazat i auth uživatele. Buď
  `delete from auth.users where id = auth.uid()` v security-definer funkci
  (kaskáda smaže `listeners`), nebo Edge Function s `auth.admin.deleteUser`.
  V appce potom smazat Keychain položku `supabase.session`.
  `prune_inactive_listeners` rozšířit o mazání `auth.users` anonymních
  (`is_anonymous`) uživatelů bez řádku v `listeners` a s neaktivitou nad 24
  měsíců. Případně jen upravit text zásad.
- Cena opravy: malá až střední

### 7. Nový účet dostane hned 12 h, práh komunity i žebříček jdou snadno obejít
- Závažnost: střední
- Oblast: A
- Místo: `backend/supabase/sql/008_listening_hardening.sql:73`, `:111`
- Co je špatně: `room = (now() - created_at) + 12 h - total`. Řádek v
  `listeners` vzniká až při prvním `record_listening`, takže úplně nový
  účet smí hned nahlásit 43 200 s.
- Postup, jak k chybě dojde: skript si udělá 20 anonymních sign-upů (limit
  Supabase je 30 za hodinu na jednu IP) a každý pošle jednu dávku s 60 s.
  `stats_available()` je pak `true` pro všechny a skrytí komunitních čísel
  (nález 3, `public_stats`) přestane platit. Každý další účet hned skočí o
  12 h v žebříčku. Opakováním účtů se dá zaplnit čelo žebříčku. README
  přiznává „farmení“ účtů, ale okamžitý 12h kredit zatím nikde
  zmíněný není.
- Důkaz (lokálně, nový uživatel posílá 6 dní po 86 400 s):
  ```
  22222222-… | total_seconds 43200 | created_at <před pár ms>
  ```
  Souběh čtyř dávek téhož nového uživatele se správně zastaví na 43 200
  (zámek `for update` funguje).
- Návrh opravy: 12h rezervu brát od `auth.users.created_at` (zakládá se až
  po minutě poslechu, takže skoro stejné), nebo ji odemykat postupně, např.
  `least(12 h, age)` nebo až po prvních 24 h existence účtu. Do
  `stats_available()` počítat jen účty starší X dní.
- Cena opravy: malá

### 8. Veřejné e-mailové relé (vzkaz, zpětná vazba) bez omezení, s libovolnou přílohou z vlastní domény
- Závažnost: střední (mimo hlavní rozsah A–E, ale backend)
- Oblast: A
- Místo: `backend/supabase/functions/send-voice-message/index.ts:67` (`filename: audio.name`), celý handler; `send-feedback/index.ts:74` (pole `device` nemá omezení délky)
- Co je špatně: obě funkce jsou nasazené s `--no-verify-jwt`, nemají žádný
  limit počtu volání a vzkaz posílá libovolný soubor do 5 MB pod jménem,
  které zvolí volající, z ověřené domény `vzkaz@radekschenk.cz`.
- Postup, jak k chybě dojde: `curl -F "audio=@faktura.pdf.exe;filename=faktura.exe" …/send-voice-message`
  ve smyčce. Do schránky rádia přijde důvěryhodně vypadající e-mail
  s přílohou útočníka. Měsíční kvóta Resend (3 000) jde vyčerpat
  za pár minut a skutečné vzkazy pak neodejdou. U zpětné vazby se
  `message` omezuje na 4 000 znaků, ale `device.*` je bez limitu.
- Důkaz: citované řádky. Žádná kontrola typu souboru, jména ani počtu.
- Návrh opravy: pevné jméno přílohy (`vzkaz.m4a`), kontrola magic bytes
  (`ftyp` u m4a) a délky polí `device`. Jednoduchý limit (tabulka nebo
  KV podle IP, třeba 10 za hodinu), případně vyžadovat anonymní JWT jako
  u statistik.
- Cena opravy: malá až střední

### 9. Spuštění appky přeruší hudbu z jiných aplikací, i když je autoplay vypnutý
- Závažnost: nízká
- Oblast: C
- Místo: `SlowDownRadijo/Services/RadioPlayerService.swift:42-46`, `:205-213`
- Co je špatně: `init()` hned volá `setCategory(.playback)` +
  `setActive(true)`. Neslučitelná session aktivovaná při startu zastaví
  Spotify, podcast a podobně.
- Postup, jak k chybě dojde: v Nastavení je vypnuté automatické přehrávání,
  posluchači hraje podcast, otevře appku jen kvůli programu a podcast
  ztichne.
- Důkaz: citované řádky. Nelze ověřit bez zařízení, ale chování
  `setActive(true)` u `.playback` bez `.mixWithOthers` je dané.
- Návrh opravy: v `init` jen `setCategory`, `setActive(true)` volat až ve
  `startPlayback()`.
- Cena opravy: malá

### 10. `RootTabView.init` při každém novém vyvolání vyrábí služby, které se zahodí
- Závažnost: nízká
- Oblast: C
- Místo: `SlowDownRadijo/Views/RootTabView.swift:53-57`
- Co je špatně: `ScheduleStore()`, `RadioPlayerService()`,
  `ICYMetadataService()` a `PlayHistoryStore()` se vytvářejí mimo autoclosure
  `StateObject(wrappedValue:)`, tedy při každém novém volání `init`. Komentář
  na ř. 39-43 sám uvádí, že SwiftUI `init` volá znovu. Každá kopie
  `RadioPlayerService` znovu aktivuje audio session (nález 9) a přidá další
  cíle do `MPRemoteCommandCenter`, které se nikdy neodeberou. Každá kopie
  `ICYMetadataService` zůstane v paměti, protože `URLSession` drží svůj
  delegate silně a session se nikdy neinvaliduje.
- Postup, jak k chybě dojde: překreslení `AppRootView` po skončení splashe.
- Důkaz: citované řádky. Kolikrát se to v praxi stane, nelze ověřit bez
  běhu.
- Návrh opravy: konstrukci přesunout do autoclosure. Například držet jeden
  `AppServices` objekt jako `@StateObject` a z něj brát závislosti, nebo
  služby vytvořit v `App` a předat je dovnitř.
- Cena opravy: malá až střední

### 11. Po přeinstalaci se měření znovu zapne, i když ho posluchač vypnul, a to pod stejným ID
- Závažnost: nízká (soukromí)
- Oblast: D, B
- Místo: `SlowDownRadijo/Services/Stats/StatsConfig.swift:272-274`; `KeychainStore.swift:221` a dál
- Co je špatně: volba „Statistiky poslechu“ je v `UserDefaults`, kde je po
  přeinstalaci výchozí hodnota `true`. Anonymní relace ale přežije
  v Keychainu.
- Postup, jak k chybě dojde: posluchač měření vypne, appku smaže a znovu
  nainstaluje. Po první minutě poslechu se nahrává pod jeho původním ID,
  aniž by to znovu povolil.
- Důkaz: citované řádky.
- Návrh opravy: volbu „vypnuto“ ukládat také do Keychainu (nebo při
  vypnutí smazat Keychain relaci, takže by se po případném zapnutí vytvořilo
  nové ID).
- Cena opravy: malá

### 12. Rozeslaná dávka může data po „Smazat“ nebo „Vypnout“ znovu vzkřísit
- Závažnost: nízká
- Oblast: B
- Místo: `SlowDownRadijo/Services/Stats/ListeningTracker.swift:122-143` vs. `:249-271`
- Co je špatně: `deleteAllData()` a `enabledPreferenceChanged()` vyprázdní
  frontu, ale požadavek, který už běží (`isFlushing`), dál odchází.
- Postup, jak k chybě dojde: rádio hraje, právě se odesílá dávka (každých
  5 min) a posluchač dá „Smazat“. Pokud `record_listening` doběhne na
  serveru až po `delete_my_listening_data`, vytvoří znovu `listeners` i
  `listening_daily` s touto dávkou. U vypnutí odejde jedna dávka i po
  slibu „po vypnutí se nic neodesílá“ (`PRIVACY_POLICY.md:26`).
- Důkaz: v `deleteAllData` není žádné čekání na `isFlushing`. Nelze ověřit
  bez běhu, okno je krátké.
- Návrh opravy: v `deleteAllData` počkat na dokončení běžícího flush (nebo
  `delete` poslat až po něm). Při vypnutí výsledek běžícího flush ignorovat
  a nic už neodesílat.
- Cena opravy: malá

### 13. „Smazat moje statistiky“ na telefonu, který nikdy nic neodeslal, založí anonymní účet
- Závažnost: nízká
- Oblast: B
- Místo: `SlowDownRadijo/Services/Stats/StatsAPIClient.swift:93-95` → `:163-165` → `:107-141`
- Co je špatně: `deleteMyData()` jde přes `authenticatedRPC` →
  `currentSession()` → `renewSession()`, a když relace není, zavolá
  `auth/v1/signup`. To odporuje zásadě „No accounts from looking“
  (`ListeningStatsStore.swift:16`).
- Postup, jak k chybě dojde: nová instalace, posluchač nic neposlouchal a
  klepne na „Smazat moje statistiky“. Vznikne nový `auth.users` záznam.
- Důkaz: citované řádky. `fetchMyStats` tento případ hlídá (`guard session != nil`),
  `deleteMyData` ne.
- Návrh opravy: v `deleteMyData` stejný guard jako ve `fetchMyStats`: bez
  relace jen vrátit úspěch.
- Cena opravy: malá

### 14. Statistiky mohou krátce ukazovat dvojnásobek nebo propad
- Závažnost: nízká (jen zobrazení)
- Oblast: B
- Místo: `SlowDownRadijo/Services/Stats/ListeningStatsStore.swift:151-160`, `:207-211`
- Co je špatně: k serverovému snímku se přičítá `inflight` dávka. Když ji
  server už započítal, ale odpověď se ztratila (nebo se snímek načte mezi
  commitem a potvrzením), je dávka v zobrazení dvakrát. To trvá až do
  dalšího pokusu o odeslání, tedy 30 s až 5 min, déle, když nic nehraje.
  Opačně mezi `finishFlush` a doběhnutím `refresh` číslo na chvíli klesne.
- Postup, jak k chybě dojde: ztracená odpověď na `record_listening` a pak
  návrat do popředí (`refreshAll`).
- Důkaz: citované řádky. Na data na serveru to vliv nemá.
- Návrh opravy: nechat to tak, případně snímek načítat až po vyřešení
  `inflight`.
- Cena opravy: malá

### 15. Animace ignorují Reduce Motion (ON-AIR tečka, malý ekvalizér)
- Závažnost: nízká
- Oblast: E
- Místo: `SlowDownRadijo/Views/Home/OnAirBadge.swift:25-29`; `SlowDownRadijo/Views/Home/NowPlayingEqualizer.swift:24-43`
- Co je špatně: `repeatForever` animace běží i se zapnutým „Omezit pohyb“.
  `Motion.swift` a `NowPlayingWaveform` ho přitom respektují.
- Postup, jak k chybě dojde: Nastavení iOS ▸ Přístupnost ▸ Pohyb ▸ Omezit
  pohyb, pak otevřít domovskou obrazovku.
- Důkaz: v obou souborech chybí `accessibilityReduceMotion`. Vzhled
  (rozměry, barvy, rychlost) by se neměnil, jen by animace s touto
  volbou stála.
- Návrh opravy: `@Environment(\.accessibilityReduceMotion)` a při `true`
  animaci nespouštět.
- Cena opravy: malá

### 16. Tlačítko Přehrát/Pauza nemá popisek pro VoiceOver v jazyce appky
- Závažnost: nízká
- Oblast: E
- Místo: `SlowDownRadijo/Views/Home/PlayButton.swift:15-39`
- Co je špatně: tlačítko obsahuje jen SF Symbol nebo `ProgressView`.
  VoiceOver přečte automatický popisek symbolu v jazyce systému (ne v CZ/EN
  appky) a ve stavu `.connecting` jen „probíhá“ u neaktivního prvku.
- Postup, jak k chybě dojde: systém v angličtině, appka přepnutá do
  češtiny (nebo naopak) a zapnutý VoiceOver.
- Důkaz: v souboru chybí `accessibilityLabel`. Přesné znění nelze ověřit
  bez zařízení.
- Návrh opravy: `.accessibilityLabel(state == .playing ? L10n.pause : L10n.play)`
  (případně nové klíče v `L10n`).
- Cena opravy: malá

---

## Návrhy katalogu a analytiky: co chybí nebo si protiřečí

**`docs/catalog-data-model.md`**
- Píše o „třech kopiích“ rozvrhu včetně widgetu. Widget ale podle
  `project.yml` kompiluje **tentýž** `Resources/schedule.json`, kopie jsou
  tedy dvě. Časy obou kopií jsou dnes shodné (ověřeno skriptem), liší se
  jen popisky a moderátoři.
- `legacyIds` je zmíněné, ale chybí rozhodnutí, **kdo** převede staré
  `listening_daily.show_id`. Možnosti jsou migrace na serveru, nebo mapování
  v klientovi. Jinak `ListeningStatsStore.showLookup` stará ID nenajde a
  ukáže „neznámý pořad“.
- Chybí pravidla pro pořady přes půlnoc (rozdělit slot?) a pro dny změny
  letního času v pražské zóně.
- `scheduleOverrides` připouští `showId = null` („bez vysílání“), statistiky
  ale pro „nic“ používají `"_"`. Chybí definice, jak spolu souvisí.
- `minAppVersion`: chybí, co má starší klient udělat (zastavit se,
  upozornit, použít zálohu v balíčku?).
- „Data jsou veřejná jen ke čtení“ chybí jako konkrétní RLS politika a
  granty (u statistik se ukázalo, že na Supabase je potřeba výslovně
  odebrat výchozí `EXECUTE` i `ALL`).

**`docs/analytics-events.md`**
- §8 tvrdí, že uložení identifikátoru na zařízení si žádá souhlas.
  Existující statistiky ale ukládají trvalé ID do Keychainu, jsou ve
  výchozím stavu zapnuté a opírají se o oprávněný zájem (`PRIVACY_POLICY.md:18-23`).
  Dokumenty se v tom rozcházejí a měl by to posoudit někdo s právním
  vzděláním.
- `install_id` se má „při přeinstalaci změnit“, chybí ale, že se proto
  nesmí uložit do Keychainu jako ID statistik.
- `playback_started.trigger = widget` není možné, protože widget podle
  vlastního kódu přehrávání spustit neumí (`NowPlayingProvider.swift:3-6`).
- `end_reason = interruption`, `stalls` a `connect_ms` stojí na stavech
  přehrávače, které dnes nejsou správně (nálezy 1 a 2). Bez oprav budou tato
  čísla zkreslená.
- `end_reason = app_exit`: chybí, jak se událost odešle, když appku systém
  ukončí. Chybí trvalá fronta událostí a chování offline.
- `sleep_timer_set.option` vyjmenovává `minutes_15/…`, appka má volby
  5/10/15/30/45/60 min a „konec pořadu“.
- „Nemá duplikovat `listening_daily`“ vs. `seconds_listened` v
  `playback_session_ended`: čas poslechu se de facto měří dvakrát.
- `device_class: tablet`: appka je jen pro iPhone (`TARGETED_DEVICE_FAMILY: "1"`).
- DAU podle `app_opened` podhodnotí posluchače, kteří ovládají jen
  zamykací obrazovku nebo CarPlay a appku „neotevřou“.

---

## Co je v pořádku

- **Oprávnění funkcí** (lokálně přes `has_function_privilege` i na ostrém
  projektu přes `get_advisors`): `anon` smí jen `public_stats` a
  `stats_available`. `record_listening`, `get_my_stats` a
  `delete_my_listening_data` smí jen `authenticated`.
  `prune_inactive_listeners` nesmí nikdo z klientů. Všechny security-definer
  funkce statistik mají `set search_path = public`.
- **RLS**: zapnuté na všech pěti tabulkách statistik bez politik a s
  `revoke all` (advisor: „RLS enabled, no policy“, to je záměr).
- **Idempotence dávek** funguje (`listening_batches` +
  `on conflict do nothing` + `if not found then return`). **Souběh** čtyř
  stejných dávek nového uživatele se správně zastaví na rezervě (zámek
  `for update`).
- **Hraniční hodnoty**: neplatné datum, `seconds` mimo `integer` nebo
  desetinné číslo končí chybou (HTTP 400) a appka takovou dávku zahodí.
  Postihne to jen data volajícího. Strop 24 h na den, maximálně 200 řádků,
  okno −60/+1 den, regex `show_id` (všech 18 ID v `schedule.json` mu
  vyhovuje) a limit 24 pořadů za den fungují, jak jsou popsané.
- **Klient**: fronta v `UserDefaults` se ukládá před odesláním (`inflight`
  s pevným `id`), takže pád mezi odesláním a potvrzením nevede ke
  zdvojení. Kredit za jeden tik je omezený na 30 s, takže uspání ani posun
  hodin nepřičtou čas navíc. Den se počítá gregoriánsky s `en_US_POSIX`.
  HTTP 429 (`PT429`) se správně opakuje, ne zahazuje.
- **Keychain**: `AfterFirstUnlockThisDeviceOnly` odpovídá nahrávání na
  pozadí i zásadám (bez iCloudu).
- **Fonty**: PostScript názvy v `Theme.swift` (`ManropeExtraLight-*`)
  odpovídají souborům v `Resources/Fonts` (ověřeno přes `fc-scan`).
  Písmo škáluje s Dynamic Type (`relativeTo:`).
- **Privacy manifest** odpovídá tomu, co appka sbírá (User ID a Product
  Interaction jako linked, zpětná vazba, diagnostika a audio jako
  not linked, UserDefaults `CA92.1`). Jiná „required reason“ API jsem
  v kódu nenašel.
- **Tajemství**: žádné kromě veřejného publishable klíče.

## Nepotvrzené podezření

1. **IP adresa v `auth.sessions`**: novější GoTrue ukládá k relaci `ip` a
   `user_agent`. Pokud to platí i na tomto projektu, neplatí doslova věta
   zásad „Do databáze se statistikami se IP adresa neukládá“, protože jde
   o tutéž databázi a relace je navázaná na anonymní ID (souvisí
   s nálezem 6). Ověřit čtením schématu `auth` na projektu; já jsem
   dotaz nespouštěl.
2. **Souběh obnovy tokenu**: `StatsAPIClient` je actor, ale přes `await`
   je reentrantní. Dvě souběžná volání s prošlým tokenem pošlou
   `refresh_token` dvakrát. Supabase to v rámci reuse intervalu (10 s)
   toleruje. Pokud by se jedno zpozdilo déle, hrozí zneplatnění relace a
   nové anonymní ID, tedy rozdělená historie. Bez relace by dvě souběžná
   volání mohla vytvořit dva anonymní účty. Realistická cesta je úzká.
3. **Opakování dávky po více než 7 dnech**: `listening_batches` se maže po
   7 dnech. Když server dávku přijme, odpověď se ztratí a appka se pak
   týden neotevře, další pokus se započítá podruhé (do limitů 24 h na den
   a rezervy).
4. **`search_path = public` bez `pg_temp`**: u security-definer funkcí se
   doporučuje `public, pg_temp`. Přes PostgREST si ale klient dočasnou
   tabulku vytvořit nemůže, takže neznám realistickou cestu.
5. **Energie**: `SleepTimerButton` má `Timer.publish(every: 1)` stále
   připojený, i když žádný časovač neběží, takže se každou sekundu
   překresluje kus domovské obrazovky. `ICYMetadataService` každých 20 s
   otevírá druhé spojení na stream, i když rádio nehraje. Dopad by bylo
   potřeba změřit v Instruments.
6. **`NowPlayingWaveform`** (`TimelineView(.animation)`, 48 sloupců) běží
   na plnou snímkovou frekvenci (až 120 Hz na ProMotion), dokud hraje a
   domovská obrazovka je v hierarchii. Neověřil jsem, jestli SwiftUI
   časovou osu pozastaví, když je aktivní jiná záložka. Vzhled ani
   animaci neměnit; nanejvýš zvážit `.animation(minimumInterval: 1/30)`
   po odsouhlasení.
7. **Funkce 001–004** (`diversity_weekly` a další) mají podle advisoru
   proměnlivý `search_path`. Jsou to `security invoker`, takže riziko je
   malé. Pro úplnost by stačilo jim `search_path` nastavit.

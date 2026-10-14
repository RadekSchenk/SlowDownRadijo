# Analytika – seznam událostí a pravidla (návrh)

*Stav: návrh, nic z toho zatím není implementované. Názvy a vlastnosti jsou
společné pro iOS i Android, aby šlo data obou appek porovnávat a sčítat.*

> Právní části (souhlas, GDPR, App Store) jsou orientační, nejde o právní
> poradenství. Před vydáním je dobré je nechat potvrdit.

## 1. Na co se chceme umět zeptat

1. **Kolik lidí appku používá** (denně, týdně, měsíčně) a jak se vracejí (1. a 7. den).
2. **Kdy a jak dlouho se poslouchá** (rozložení délky poslechu, špičky během dne).
3. **Jak spolehlivé je přehrávání** (kolik pokusů o spuštění selže, jak často se
   stream přerušuje, na jakých verzích systému a appky).
4. **Které části appky se používají** (Statistiky, Program, Vzkaz, Novinky, Nastavení).
5. **Funguje podpora rádia** (kolik lidí z appky klepne na Patreon/Herohero/Forendors).
6. **Zpětná vazba a vzkazy** (kolik jich vzniká a kolik jich selže).

Co už máme jinde a analytika to **nemá duplikovat**: čas poslechu po pořadech a
po dnech je v tabulce `listening_daily` (anonymní statistiky), historie přehraných
skladeb v `played_tracks`.

## 2. Zásady

- **Jména**: `snake_case`, tvar `objekt_akce` v minulém čase (`playback_started`,
  `message_sent`). Stejná jména na obou platformách.
- **Vlastnosti**: malé, ploché, bez textu zadaného uživatelem. Čísla a výčty,
  žádné volné texty (zpětná vazba, názvy souborů, e-maily).
- **Žádná osobní data**: ne jména, ne e-maily, ne přesná poloha, ne IP v datech
  (země se odvozuje serverem a IP se nezapisuje).
- **Šetřit počtem**: žádné události po sekundách. Poslech se měří jedním záznamem
  za souvislý úsek (`playback_session_ended`).
- **Verze schématu**: každá událost nese `schema_version`. Změna významu
  vlastnosti = nová verze, ne tiché přepsání.
- **Společné vlastnosti** se přidávají automaticky ke všem událostem (tabulka níže).

## 3. Společné vlastnosti (u každé události)

| vlastnost | příklad | poznámka |
|---|---|---|
| `platform` | `ios` / `android` | |
| `app_version`, `build` | `1.0`, `12` | |
| `os_version` | `iOS 18.1` / `Android 15` | |
| `device_class` | `phone` / `tablet` | ne přesný model |
| `language` | `cs` / `en` | jazyk appky |
| `session_id` | náhodné UUID | nový při každém spuštění appky |
| `install_id` | náhodné UUID | viz sekce 8, **ne** stejné jako ID statistik |
| `schema_version` | `1` | |

Země a čas přidá server (z IP, kterou nezapisuje).

## 4. Události

### Životní cyklus a navigace
| událost | kdy | vlastnosti |
|---|---|---|
| `app_opened` | spuštění nebo návrat z pozadí po > 30 min | `launch_type` (`cold`/`warm`), `entry` (`normal`/`widget`/`notification`/`deep_link`) |
| `screen_viewed` | zobrazení obrazovky | `screen` (`home`, `stats`, `message`, `support`, `menu`, `news_list`, `news_detail`, `settings`, `feedback`) |
| `language_changed` | přepnutí CZ/EN | `to` |

### Přehrávání
| událost | kdy | vlastnosti |
|---|---|---|
| `playback_started` | stream začal hrát (po připojení) | `trigger` (`user`/`autoplay`/`widget`/`lock_screen`/`headphones`), `show_id`, `connect_ms` (doba připojení, zaokrouhleno) |
| `playback_session_ended` | pauza, chyba nebo ukončení | `seconds_listened` (zaokrouhleno), `end_reason` (`user`/`sleep_timer`/`interruption`/`error`/`app_exit`), `reconnects` (počet), `stalls` (počet přerušení), `show_id` (pořad, který hrál nejdéle) |
| `playback_failed` | pokus o spuštění nebo přerušení neskončil hrajícím streamem | `stage` (`connecting`/`stalled`), `error_code`, `attempt` |
| `sleep_timer_set` | nastavení časovače | `option` (`minutes_15`/`…`/`end_of_show`) |
| `sleep_timer_fired` | časovač vypnul přehrávání | |

### Program a statistiky
| událost | kdy | vlastnosti |
|---|---|---|
| `program_day_selected` | výběr dne v Pořadech | `is_today` (bool), `weekday` (1–7, ISO) |
| `past_shows_toggled` | rozbalení/sbalení předchozích pořadů | `expanded` (bool) |
| `stats_viewed` | otevření záložky Statistiky | `community_unlocked` (bool), `has_rank` (bool) |
| `stats_enabled_changed` | přepínač „Statistiky poslechu“ | `enabled` (bool) |
| `stats_data_deleted` | „Smazat moje statistiky“ | `success` (bool) |

### Zapojení a podpora
| událost | kdy | vlastnosti |
|---|---|---|
| `support_link_tapped` | klepnutí na platformu podpory | `platform` (`patreon`/`herohero`/`forendors`) |
| `social_link_tapped` | klepnutí na sociální síť | `network` |
| `news_opened` | otevření článku | `post_id` |
| `news_notifications_changed` | přepínač oznámení o novinkách | `enabled` |
| `message_recording_started` | začátek nahrávání vzkazu | |
| `message_sent` | odeslání hlasového vzkazu | `duration_s` (zaokrouhleno), `success` (bool), `error_stage` |
| `feedback_sent` | odeslání zpětné vazby | `success` (bool), `length_bucket` (`short`/`medium`/`long`) |
| `privacy_policy_opened` | otevření zásad | |

### Chyby (nefatální)
| událost | kdy | vlastnosti |
|---|---|---|
| `app_error` | zachycená chyba, která se dá řešit | `domain` (`catalog`/`stats`/`news`/`upload`), `code` |

Pády appky se nesbírají jako události, jen přes nástroj pro pády (Crashlytics nebo
Sentry), který se nasadí zvlášť.

## 5. Z čeho se počítají metriky

| metrika | výpočet |
|---|---|
| Denní / týdenní / měsíční aktivní | unikátní `install_id` s `app_opened` |
| Posluchači za den | unikátní `install_id` s `playback_started` |
| Průměrná délka poslechu | průměr `seconds_listened` z `playback_session_ended` |
| Retence den 1 / den 7 | podíl nových `install_id`, které se vrátí |
| Čas do prvního přehrání | od `app_opened` (první) po `playback_started` |
| Spolehlivost přehrávání | `playback_failed` na 1 000 `playback_started` |
| Konverze podpory | `support_link_tapped` / unikátní zobrazení záložky Podpora |
| Využití Statistik | `stats_viewed` / `app_opened` |

## 6. Co záměrně neměříme

Žádné klepání po obrazovce, polohu, seznam nainstalovaných aplikací, reklamní ID,
obsah zpětné vazby ani vzkazů, ani přesné modely zařízení.

## 7. Nástroj (srovnání)

Cena a podmínky se mění, ověř před výběrem.

| | Silné stránky | Slabé stránky |
|---|---|---|
| **PostHog (EU cloud)** | události, trychtýře, retence, **přepínače funkcí** (nahradí vlastní „feature flags“); serverové zpracování v EU; jde vypnout IP | další služba k nastavení |
| **Firebase Analytics** | zdarma, jednoduché SDK pro iOS i Android, napojení na pády | Google, přísnější souhlas, méně flexibilní dotazy |
| **Mixpanel / Amplitude** | silné produktové reporty | cena a limity u větších objemů |
| **Vlastní tabulka v Supabase** | plná kontrola, žádná třetí strana | žádné grafy hotové, vše se dělá ručně (např. Metabase) |

**Doporučení:** PostHog (EU) pro produktové otázky. Čas poslechu po pořadech zůstává
v Supabase (`listening_daily`). Důležité je držet **vlastní vrstvu**: appka volá
jednu funkci `track(event, properties)`, a nástroj za ní se dá vyměnit.

## 8. Souhlas, soukromí, App Store

- **`install_id`** je nové náhodné ID pro analytiku, **ne** stejné jako ID anonymních
  statistik (aby se oba světy nepropojily) a při přeinstalaci se změní.
- **Souhlas**: protože se na zařízení ukládá identifikátor, je bezpečné ptát se
  na souhlas při prvním spuštění (jednoduchá obrazovka, „Povolit“ / „Nepovolit“,
  jde změnit v Nastavení). Alternativa je „bezidentifikátorový“ režim (bez
  trvalého ID, jen součty), kde souhlas být nemusí. Má nižší užitek (žádná
  retence) a výklad je sporný. K rozhodnutí je dobré právní stanovisko.
- **Zásady soukromí** se doplní: co se měří, k čemu, kdo je zpracovatel, jak to
  vypnout.
- **App Store (privacy labely)**: přibude *Usage Data → Product Interaction* a
  případně *Identifiers → Device ID*, pokud nástroj ID používá; ověřit podle
  skutečného chování SDK.
- **Google Play (Data safety)**: stejný soupis údajů.

## 9. Postup zavedení (po schválení)

| # | Krok | Velikost |
|---|---|---|
| 1 | Rozhodnout souhlas a nástroj (sekce 7 a 8) | rozhodnutí |
| 2 | Tenká vrstva `Analytics.track(...)` + posílání společných vlastností | malá |
| 3 | Základní události: `app_opened`, `screen_viewed`, `playback_*` | střední |
| 4 | Zbytek událostí + obrazovka souhlasu a přepínač v Nastavení | střední |
| 5 | Zásady soukromí a štítky v obchodech | malá |
| 6 | Android přebírá tento dokument beze změny | – |

## 10. Otevřené otázky

1. **Jaké tři otázky jsou pro rádio nejdůležitější?** (podle toho se může seznam zkrátit.)
2. **Souhlas při prvním spuštění**, nebo bezidentifikátorový režim?
3. **Chcete přepínače funkcí** (vzdálené zapínání) ve stejném nástroji?
4. **Pády**: Crashlytics, nebo Sentry (obojí zvlášť od analytiky)?
5. **Jak dlouho uchovávat data** (návrh: 14 měsíců)?

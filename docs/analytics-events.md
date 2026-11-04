# Analytika – co měříme a kde to najdeš

*Stav: implementováno v iOS (schema_version 1). Názvy a vlastnosti platí i pro
budoucí Android, aby šlo data obou appek sčítat.*

Analytika má dvě části, každou na jiné otázky:

| | Odkud | Na co | Souhlas |
|---|---|---|---|
| **Poslechovost** | Supabase, statistiky poslechu (`listening_daily`) → pohledy `reports.*` | kolik lidí poslouchá, jak dlouho, jak často se vrací, které pořady | ne (oprávněný zájem, jde vypnout v Nastavení) |
| **Používání appky** | PostHog (EU), události níže | které funkce se používají, spolehlivost přehrávání | ano, karta na úvodní obrazovce / přepínač v Nastavení |

Poslechovost tak pokrývá všechny posluchače se zapnutými statistikami, ne jen ty,
kdo souhlasili s měřením.

## 1. Poslechovost (Supabase)

Pohledy ve schématu `reports` (SQL `backend/supabase/sql/013_audience_reports.sql`).
API je nevystavuje a appka je číst nemůže; otevírají se v Supabase ▸ SQL Editor:

```sql
select * from reports.overview;            -- celkem: posluchači, hodiny, průměr, aktivní za 7/30 dní
select * from reports.daily_listeners;     -- po dnech
select * from reports.weekly_listeners;    -- po týdnech (od pondělí)
select * from reports.monthly_listeners;   -- po měsících + průměr denně + stickiness
select * from reports.monthly_segments;    -- příležitostní / pravidelní / věrní
select * from reports.show_listening;      -- pořady po měsících
```

**Definice**

- **Aktivní den**: aspoň 60 s poslechu za den (stejná hranice jako u žebříčku).
- **Segmenty za kalendářní měsíc**:
  - `occasional` (příležitostný): 1 aktivní den,
  - `regular` (pravidelný): 2–7 dní,
  - `loyal` (věrný / heavy): 8+ dní, nebo 10+ hodin za měsíc.
- **Průměr posluchačů denně** = součet aktivních dní všech posluchačů / počet dní
  (u běžícího měsíce jen do dneška).
- **Stickiness** = průměr denně / posluchači za měsíc (kolik % měsíčních posluchačů
  přijde v průměrný den).
- Dny jsou podle času v telefonu posluchače. Kdo si statistiky smaže, zmizí
  i z přehledů.

## 2. Používání appky (PostHog)

Vše jde přes `Analytics.shared.track(_:)` (`SlowDownRadijo/Services/Analytics/Analytics.swift`);
nástroj za ním se dá vyměnit nebo doplnit (Google Analytics) beze změny volání.

### Zásady

- `snake_case`, tvar `objekt_akce` v minulém čase.
- Žádný volný text, žádné názvy skladeb, nic, co vede k osobě. Délky zaokrouhlené
  (poslech na 10 s, vzkaz na 5 s).
- Každá událost nese `language` (`cs`/`en`) a `schema_version`. Změna významu
  vlastnosti = nová verze.
- PostHog sám přidá verzi appky a systému, typ zařízení, časové pásmo a typ
  připojení. Přesný model zařízení appka před odesláním maže. IP se v projektu
  neukládá (Settings ▸ Privacy ▸ Discard client IP data).
- Vypnuto: autocapture, záznam obrazovky, ankety, profily osob, swizzling,
  automatické události životního cyklu a obrazovek.

### Události

| událost | kdy | vlastnosti |
|---|---|---|
| `app_opened` | spuštění, návrat po 30+ min na pozadí, udělení souhlasu | `kind`: `cold` / `warm` / `consent` |
| `screen_viewed` | zobrazení obrazovky | `screen`: `home`, `message`, `support`, `stats`, `menu`, `settings`, `show_reminders`, `news` |
| `language_changed` | přepnutí CZ/EN v hlavičce | `to`: `cs` / `en` |
| `playback_started` | stream opravdu začal hrát | `trigger`: `user`, `autoplay`, `lock_screen`, `notification`, `resume`, `preview`; `show_id`; `connect_ms` |
| `playback_stopped` | konec souvislého poslechu | `seconds_listened`, `end_reason`: `user`, `sleep_timer`, `interruption`, `headphones`, `voice_message`, `preview`; `show_id`; `reconnects` |
| `playback_failed` | stream se nespustil / spadl (jednou za sérii pokusů) | `stage`: `connecting` / `interrupted`; `show_id` |
| `sleep_timer_set` | nastavení časovače | `option`: `5m`, `10m`, `15m`, `30m`, `45m`, `60m`, `end_of_show` |
| `show_reminder_changed` | zapnutí/vypnutí upozornění na pořad | `show_id`, `on`, `source`: `bell` / `settings` |
| `show_notification_opened` | klepnutí na upozornění na pořad | `show_id`, `listen` (tlačítko „Poslouchat“) |
| `spotify_opened` | klepnutí na právě hrající skladbu | `show_id` |
| `link_opened` | WhatsApp, sociální sítě v menu | `target`: `whatsapp`, `youtube`, `threads`, `instagram`, `facebook` |
| `stats_opened` | otevření záložky Statistiky | `community_unlocked` |
| `support_link_opened` | klepnutí na platformu podpory | `platform` (id platformy) |
| `message_sent` | odeslání hlasového vzkazu | `success`, `duration_s` |
| `feedback_sent` | odeslání zpětné vazby | `success` |

`show_id` je id pořadu ze `schedule.json`, `_` když žádný neběží.

### Doporučené přehledy v PostHogu

| otázka | jak |
|---|---|
| Nejpoužívanější funkce | Trends ▸ Total count, všechny události kromě `app_opened`/`playback_*`, breakdown podle události |
| Obrazovky | Trends `screen_viewed`, breakdown `screen` |
| Odkud se pouští rádio | Trends `playback_started`, breakdown `trigger` |
| Proč poslech končí | Trends `playback_stopped`, breakdown `end_reason` |
| Spolehlivost | `playback_failed` / `playback_started` (Formula), breakdown `$app_version` |
| Fungují upozornění | Funnel `show_reminder_changed` (on=true) → `show_notification_opened` |
| Podpora | Funnel `screen_viewed` (screen=support) → `support_link_opened` |
| Návraty | Retention, `app_opened` → `app_opened` |

## 3. Souhlas

- Karta „Pomůžeš nám appku vylepšovat?“ na úvodní obrazovce od 3. spuštění,
  dokud posluchač neodpoví. Neblokuje appku.
- Stejná volba: Menu ▸ Nastavení ▸ Anonymní měření používání.
- Do souhlasu SDK nic neodesílá (startuje jako opted-out). Odvolání zahodí
  analytické ID; nový souhlas = nové ID.

## 4. Google Analytics (připraveno, zatím vypnuto)

Až bude přístup do GA4:

1. Ve Firebase vytvořit projekt napojený na existující GA4 property a přidat iOS
   appku `cz.slowdownradijo.app`; stáhnout `GoogleService-Info.plist`.
2. Přidat balíček `firebase-ios-sdk` (jen `FirebaseAnalyticsWithoutAdIdSupport`)
   do `project.yml`, v Info.plist vypnout sběr do souhlasu
   (`FIREBASE_ANALYTICS_COLLECTION_ENABLED = NO`, `GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS = NO`).
3. V `Analytics.track` posílat tytéž události i do Firebase a v `setConsent`
   přepínat `setAnalyticsCollectionEnabled`.
4. Zveřejnit připravený odstavec v `PRIVACY_POLICY.md` (je v komentáři na konci)
   a doplnit privacy manifest / štítky v App Store Connect.

## 5. App Store Connect – štítky soukromí

- **Usage Data ▸ Product Interaction**: Analytics + App Functionality, nepropojeno
  s identitou, bez sledování.
- **Identifiers ▸ Device ID**: Analytics (náhodné ID PostHogu), nepropojeno, bez sledování.
- **Identifiers ▸ User ID**: App Functionality (anonymní ID statistik).
- Další údaje (zpětná vazba, vzkaz, diagnostika) beze změny, viz `PrivacyInfo.xcprivacy`.

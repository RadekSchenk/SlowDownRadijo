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
| `screen_viewed` | zobrazení obrazovky | `screen`: `home`, `message`, `support`, `stats`, `profile`, `menu`, `settings`, `show_reminders`, `news` |
| `language_changed` | přepnutí CZ/EN v hlavičce | `to`: `cs` / `en` |
| `playback_started` | stream opravdu začal hrát | `trigger`: `user`, `autoplay`, `lock_screen`, `notification`, `resume`, `preview`; `show_id`; `connect_ms`; `stream`: `mp3` / `aac` (co opravdu hraje); `quality`: nastavení `auto` / `high` / `low` (od 1.3) |
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
| `chat_opened` | otevření chatu (1.3) | `source`: `home_section` / `home_field` / `invite`; `signed_in` |
| `chat_message_sent` | odeslání zprávy do chatu | `kind`: `text` / `emoji` / `starter`; `success` |
| `chat_join_shown` | nepřihlášenému se vysunulo „Připoj se do chatu“ | `reason`: `send` / `report` |
| `chat_moderated` | akce DJ nebo admina | `action`: `pin`, `unpin`, `delete`, `restore`, `mute`, `unmute`, `block`; `minutes` (jen `mute`) |
| `chat_reported` | nahlášení zprávy | — |
| `chat_user_hidden` | skrytí zpráv od posluchače | — |
| `dj_invite_opened` | otevření pozvánky pro DJ | `valid`: `yes` / `no` / `unknown` |
| `dj_invite_claimed` | propojení účtu s DJ | `success` |

U chatu se nikdy neposílá text zpráv, přezdívky ani kdo komu psal.

#### Chat v3 a účty (od 1.3, implementováno v obou appkách)

`account` u událostí chatu: `none` (bez anonymního účtu), `anonymous` (píše bez registrace), `registered`.

| událost | kdy | vlastnosti |
|---|---|---|
| `chat_opened` | otevření chatu | `source`: `home_section` / `home_field` / `invite`; `account` (nahrazuje `signed_in`) |
| `chat_message_sent` | odeslání zprávy | `kind`: `text` / `emoji` / `starter`; `success`; `first` (první zpráva vůbec); `account` |
| `chat_nickname_prompt_shown` | při první zprávě vyjelo „Tvoje přezdívka“ | — |
| `chat_nickname_set` | přezdívka uložena | `when`: `first_message` / `change` |
| `registration_prompt_shown` | výzva k registraci | `reason`: `nickname_change`, `profile_card`, `chat_existing_account` |
| `account_registered` | anonym se zaregistroval (klíčová konverze) | `method`: `apple` / `google` / `email`; `source`: `nickname_change`, `profile_card`, `profile_empty`, `chat_existing_account`; `had_nickname` |
| `account_signed_in` | přihlášení existujícím účtem („Už máš účet?“) | `method`; `source` |
| `account_deleted` | smazání účtu nebo údajů | `registered` |
| `profile_dashboard_viewed` | Profil s přehledem Tvůj Slowride | `weeks_member` |
| `chat_moderated`, `chat_reported`, `chat_user_hidden` | beze změny | |
| `dj_invite_opened`, `dj_invite_claimed` | beze změny | |
| `admin_invite_created` | superadmin vytvořil pozvánku pro moderátora | `from_programme` (z programu / host mimo program) |
| `admin_invite_shared` | Sdílet nebo Kopírovat | `via`: `share` / `copy` |
| `admin_host_unlinked` | odpojení moderátora | — |
| `admin_admins_changed` | přidání / odebrání správce | `action`: `add` / `remove` |

`chat_join_shown` z 1.3 zmizí (psaní už přihlášení nevyžaduje).

Přehledy v PostHogu pro v3:

| otázka | jak |
|---|---|
| Kolik lidí v chatu píše | Trends `chat_message_sent` (success), unikátní uživatelé, breakdown `account` |
| Kdo se po první zprávě vrátí | Retention: `chat_message_sent` (`first` = true) → `chat_message_sent` |
| Funguje motivace k registraci | Funnel `registration_prompt_shown` → `account_registered`, breakdown `reason` |
| Kolik je registrovaných (všichni, i bez souhlasu) | Dashboard „Slow Down Rádijo – appka“: „Registrovaní Slowriders“, „Registrace podle platformy“, „Nové registrace podle způsobu přihlášení“. Data warehouse `radiopostgres_account_registrations` ze Supabase (`posthog_export.account_registrations`, 024 a 025), jen počty |
| Chat ze Supabase (všichni, i bez souhlasu) | Dashboard „Slow Down Rádijo – appka“: „Chat – zprávy a pisatelé po dnech“, „Chat – kde se nejvíc píše (30 dní)“, „Chat – vracejí se noví pisatelé?“. Tabulky `radiopostgres_chat_daily`, `_chat_shows_30d`, `_chat_retention` (027), jen počty |
| V jaké kvalitě lidé poslouchají | Dashboard: „Poslech podle kvality streamu (hodiny)“, „Posluchači podle nastavení kvality (30 dní)“. Tabulky `radiopostgres_listening_quality_daily` a `_users` (027); appky před 1.3 se počítají jako „Starší verze“ |
| Odkud přicházejí registrace | Trends `account_registered`, breakdown `source` a `method` |
| Odrazuje okno přezdívky | Funnel `chat_nickname_prompt_shown` → `chat_nickname_set` → `chat_message_sent` |

`show_id` je id pořadu ze `schedule.json`, `_` když žádný neběží.

### Doporučené přehledy v PostHogu

| otázka | jak |
|---|---|
| Nejpoužívanější funkce | Trends ▸ Total count, všechny události kromě `app_opened`/`playback_*`, breakdown podle události |
| Obrazovky | Trends `screen_viewed`, breakdown `screen` |
| Odkud se pouští rádio | Trends `playback_started`, breakdown `trigger` |
| Píše se do chatu? | Funnel `chat_opened` → `chat_message_sent` (success = true), breakdown `signed_in` |
| Odrazuje přihlášení? | Funnel `chat_join_shown` → `chat_message_sent` |
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

#### Soutěže (od 1.3, implementováno v obou appkách)

| událost | kdy | vlastnosti |
|---|---|---|
| `contest_infobox_shown` | žlutá nabídka soutěže se poprvé za spuštění ukázala na homepage | `contest_id` |
| `contest_infobox_tapped` | klepnutí na nabídku (otevře soutěž) | `contest_id` |
| `contest_infobox_dismissed` | posluchač nabídku zavřel křížkem a potvrdil „Zavřít a nesoutěžit“ | `contest_id` |
| `contest_entry_submitted` | odeslání odpovědi | `contest_id`; `answer_type`: `choice` / `text`; `success`; `error`: `closed`, `alreadyEntered`, `answerInvalid`, `phoneInvalid`, `accountRequired`, `offline`, `other` |
| `registration_prompt_shown` / `account_registered` | registrace ze soutěže | `reason` / `source`: `contest` |
| `admin_contest_created` | správce spustil soutěž | `answer_type`, `winners` |
| `admin_contest_ended` | předčasné ukončení | — |
| `admin_contest_drawn` | losování | `replacement` (náhradník) |

Nikdy se neposílá odpověď ani telefon. Konverze: funnel `contest_infobox_tapped` → `registration_prompt_shown` (reason = contest) → `account_registered` (source = contest) → `contest_entry_submitted` (success).


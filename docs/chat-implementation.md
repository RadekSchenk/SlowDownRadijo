# Chat a přihlášení — plán implementace (iOS + Android)

Návrh: Figma „Slow Down Rádijo“, stránky **Chat** a **Profil**. Koncept a pravidla: `docs/chat-concept.md`.
Podle `CLAUDE.md` jde všechno do obou appek v jedné větvi (`claude/chat`) a jednom PR, verze **1.3** na obou platformách.

## Fáze

| # | Co | iOS | Android | Backend |
|---|---|---|---|---|
| 1 ✅ | **Datový model a pravidla** | — | — | `020_chat.sql` (otestováno lokálně, na produkci zatím **nespuštěno**): `profiles`, `chat_hosts`, `chat_host_invites`, `chat_messages` (+ Realtime), `chat_deleted_bodies`, `chat_mutes`, `chat_reports`, `chat_hidden_users`; funkce `chat_me`, `set_nickname`, `nickname_available`, `send_chat_message`, `delete_chat_message`, `restore_chat_message`, `pin_chat_message`, `unpin_chat_message`, `mute_chat_user`, `unmute_chat_user`, `block_chat_user`, `chat_user_status`, `claim_host_invite`, `report_chat_message`, `hide_chat_user`, `unhide_chat_user`, `my_hidden_chat_users`, `delete_my_account`. Pořad ke zprávě posílá appka (zná program), server ho jen ověří — stejně jako u statistik. Chyby vrací stabilní kódy (`nickname_taken`, `muted`, …). |
| 2 | **Přihlášení** | `supabase-swift` (Auth, Realtime) + `GoogleSignIn-iOS` + Sign in with Apple | `supabase-kt` (Auth, Realtime) + Credential Manager (Google) + Apple přes web OAuth | Poskytovatelé Apple, Google, e‑mail OTP. Anonymní účet ze statistik se při přihlášení **povýší** na trvalý (statistiky zůstanou). |
| 3 | **Záložka Profil** | 16 stavů z Figmy | totéž | `delete_my_account` (navazuje na `011_delete_auth_user.sql`) |
| 4 | **Chat** | sekce na homepage s tickerem, chat sheet, předěly, připnutá zpráva, sloučené reakce, psaní s přihlášením až při odeslání | totéž | — |
| 5 | **Moderace a DJ** | menu zprávy, ztlumení/blokace/smazání, nahlášení, skrytí; pozvánka DJ přes odkaz | totéž (App Links) | — |
| 6 | **Dokončení** | texty v `L10n.swift`, analytika, UI testy | `strings.xml` skriptem, Roborazzi | parita v `docs/android.md`, zásady ochrany soukromí |

## Co musí udělat Radek (účty a klíče)

1. **Apple Developer:** zapnout *Sign in with Apple* u App ID aplikace; vytvořit *Services ID* a klíč `.p8` pro Sign in with Apple (potřebuje ho Supabase kvůli přihlášení na Androidu).
2. **Google Cloud Console:** OAuth consent screen; OAuth klienti **iOS**, **Android** (SHA‑1 upload klíče i podpisového klíče z Google Play) a **Web** (pro Supabase).
3. **Supabase → Authentication:** zapnout Apple, Google a e‑mail (OTP, 6 číslic, platnost 10 min); *Manual linking* (povýšení anonymního účtu); vlastní SMTP přes Resend, aby e‑maily chodily z domény rádia.
4. **slowdownradijo.cz:** soubory `/.well-known/apple-app-site-association` a `/.well-known/assetlinks.json` pro odkazy pozvánek DJ (`/dj/<kód>`). Obsah připravím.
5. **Obchody:** po dokončení aktualizovat App Privacy (App Store) a Data safety (Google Play) — přibude účet, e‑mail a obsah od uživatelů.

## Rozhodnutí z konverzace

- Záložka **Profil** nahrazuje skrytou Podporu jako 4. záložku.
- Oficiální SDK (`supabase-swift`, `supabase-kt`) místo vlastního REST klienta pro auth a realtime; stávající `StatsAPIClient` / `StatsApi` přejdou na session z SDK.
- Migrace se na produkční Supabase pouští až po odsouhlasení; předtím na větvi databáze nebo lokálně.

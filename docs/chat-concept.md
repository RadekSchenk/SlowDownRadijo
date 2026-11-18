# Chat v aplikaci Slow Down Rádijo — koncept a prompt pro Figma Make

Stav: koncept (17. 11. 2026). Řeší rámec, ne implementaci.

---

## 1. Rozhodnutí v kostce

| Otázka | Rozhodnutí | Proč |
|---|---|---|
| Vázat chat na pořad? | **Ne jako oddělené místnosti.** Jeden souvislý stream pro celé rádio, do kterého se automaticky vkládají **předěly pořadů** („▶ 07:00 Morning Coffee · DJ Pufaz“). | Při malém počtu lidí by se místnosti po pořadech roztříštily na prázdná místa. Předěl dá kontext („o čem se tu mluvilo“) a zároveň z ticha udělá přirozený rytmus vysílání. Každá zpráva si v datech nese `show_id`, takže filtrování podle pořadu jde doplnit později. **Předěl se zobrazí jen před první zprávou daného pořadu** — pořady, do kterých nikdo nenapsal, ve streamu vůbec nejsou (viz „Pravidla předělů“). |
| Vázat na čas? | **Ano, ale jen jako metadata zobrazená lidsky:** denní předěly („Dnes“, „Včera“, „Po 10. 11.“), relativní čas u posledních zpráv („před 3 h“), přesný čas při podržení. | Relativní čas otevřeně říká „píše se tu málo“, ale neschovává to — a to působí důvěryhodněji než falešný ruch. |
| Jen jméno a zpráva? | **Jméno + zpráva + čas + role (odznak).** Bez avatarů na začátku (jen barevná iniciála), bez vláken, bez odpovídání na konkrétní zprávu (v1). | Minimální vizuální šum, rychlá implementace, prostor pro odlišení moderátora a podporovatele. |
| Čtení chatu | **Bez přihlášení.** | Prázdnou místnost nikdo nenaplní, když ji nevidí. Čtení je zároveň „náhled“, který motivuje k registraci. |
| Psaní | **Jen přihlášení** (Sign in with Apple, Google, e‑mail magic link). | Proti spamu a zneužití, nutná podmínka pro budoucí placený účet. |
| Přezdívka | Nastavuje se **po registraci** (první vstup do chatu) a v **Profilu**. Změna **max. 1× za 24 h**, unikátní (bez ohledu na velikost písmen), 3–20 znaků, písmena bez diakritiky, číslice, tečka, podtržítko. Rezervovaná jména (jména DJů, „slowdown“, „moderator“, „admin“, „radijo“…) zakázaná. | Brání vydávání se za moderátora a „přejmenovávání pro trolling“. |
| Homepage | **Kompaktní karta chatu** mezi přehrávačem a statistikami: 2–3 poslední zprávy + falešný composer „Napiš zprávu…“ + řádek rychlých emoji. Tap kamkoli → otevře sheet. | Homepage je výloha, plnohodnotná konverzace patří do sheetu (jak už máte navrženo — zachovat). |
| Sheet | Zachovat současný model: sheet nad homepage, nahoře zůstává mini‑přehrávač s aktuálním pořadem, detenty **střední / plná výška**. | Posluchač nepřijde o kontext toho, co hraje. Je to dobře nastřelené, není důvod přepracovávat. |
| Moderátor | Role `dj` přidělená adminem v backendu, propojená s pořadem(y) v katalogu. Zpráva DJ: jméno v akcentové červené + odznak „DJ“ + 🎙 když je právě jeho pořad ON‑AIR + jemně tónované pozadí zprávy. Může zprávu **připnout**, smazat, ztlumit uživatele. | Moderátor musí být čitelný na první pohled, i ve 3řádkovém náhledu na homepage. |
| Placený účet (budoucnost) | Role `supporter`: jméno ve zlaté/teplé barvě + malý odznak ★, bez tónovaného pozadí. **Vizuálně vždy slabší než moderátor.** | Odměna, ne megafon. |

### Pravidla předělů
- Předěly se **neukládají jako zprávy**, klient je dopočítá při vykreslení ze `show_id` a `created_at` zpráv.
- **Předěl pořadu** se vloží jen tehdy, když se `show_id` liší od předchozí zprávy ve streamu. Pořad bez zpráv = žádný předěl. Dva pořady za sebou bez zpráv mezi nimi se tedy nikdy nezobrazí jako dvě prázdné linky.
- **Předěl dne** stejně: jen před první zprávou dne. Prázdné dny se přeskočí („Včera“ → rovnou „Po 10. 11.“).
- Pokud do aktuálně vysílaného pořadu ještě nikdo nenapsal, kontext nese **hlavička sheetu** (mini‑přehrávač + podtitul pořadu), ne předěl. Předěl se objeví v okamžiku, kdy přijde první zpráva — i ta vlastní, takže posluchač vidí, že „otevřel“ pořad.
- Zprávy mimo program (mezi pořady, playlist bez moderace) mají `show_id = null` a předěl „▶ Hudba bez moderace“ — opět jen pokud tam někdo napsal.

### Jak nastavovat moderátory

Staví na tom, co už je: Supabase projekt a katalog s tabulkou `hosts` (stabilní `id`, `name`) a `shows.hostIds[]`, upravovaný v Table Editoru (viz `catalog-data-model.md`). Žádná vlastní administrace není potřeba.

**Data**
- `auth.users` — účty ze Supabase Auth (Apple / Google / e‑mail).
- `profiles` — `user_id`, `nickname`, `nickname_changed_at`, `is_admin` (bool), později `supporter_until`.
- `hosts.user_id` (nový sloupec, nullable, unikátní) — **jediná vazba „tenhle účet je tenhle moderátor“**. Role DJ se nikam zvlášť nezapisuje, odvozuje se: účet je DJ, právě když na něj ukazuje nějaký řádek v `hosts`.
- `host_invites` — `code`, `host_id`, `expires_at`, `used_by`, `used_at`.

**Postup propojení DJ (zvací odkaz)**
1. V Table Editoru přidáš řádek do `host_invites` (`host_id = 'dj-pufaz'`, platnost 7 dní; kód vygeneruje default sloupce).
2. Pošleš DJ odkaz `https://slowdownradijo.cz/dj/<kód>` (universal link → otevře appku) třeba přes WhatsApp.
3. DJ v appce se přihlásí jako kdokoli jiný. Appka kód předá edge funkci `claim-host-invite`, ta ověří platnost a nastaví `hosts.user_id`. Kód je jednorázový.
4. DJ uvidí potvrzení „Jsi propojený jako DJ Pufaz“. V chatu se od té chvíle zobrazuje pod jménem z katalogu (`hosts.name`), ne pod přezdívkou, a přezdívku nenastavuje.

Proč odkaz, a ne „pošli mi e‑mail a já tě najdu“: přes Sign in with Apple má většina lidí skrytý e‑mail (`xyz@privaterelay.appleid.com`), takže by se účet v `auth.users` hledal špatně. Nouzová varianta: v Profilu je řádek „ID účtu“ (kopírovat), DJ ti ho pošle a ty ho vložíš do `hosts.user_id` ručně.

**Admin (ty)** — jednou ručně `profiles.is_admin = true` u svého účtu. Admin má stejné akce jako DJ, jen v chatu vystupuje pod svou přezdívkou s odznakem „Slow Down“ (nebo bez odznaku, rozhodnout).

**Co z toho plyne v chatu**
- Odznak „DJ“ = autor má řádek v `hosts`. Mikrofon 🎙 (ON‑AIR) = pořad vysílaný v okamžiku odeslání má autora v `hostIds`. Server to při uložení zprávy zapíše do `messages.author_badge` / `messages.on_air`, aby historie zůstala správně, i když se program později změní.
- Jména všech `hosts.name` jsou automaticky rezervovaná — nikdo jiný si je nedá jako přezdívku.
- Moderátorské akce (podržet zprávu → Připnout / Smazat / Ztlumit na 24 h / Zablokovat) se ukážou jen DJ a adminovi. Žádná „admin sekce“ v appce.
- Zrušení role: smazat `hosts.user_id`. Moderátor, který odejde, zůstane v katalogu, jen ztratí vazbu.
- Host na jeden večer: pozvánka může odkazovat i na dočasný řádek v `hosts`, nebo (v2) pozvánka s `role_until`.

**Bezpečnost (RLS)**
- Klient nikdy nemůže zapsat `hosts.user_id`, `profiles.is_admin` ani `supporter_until` — jen service role (edge funkce) nebo ty v dashboardu.
- Mazání/skrývání cizích zpráv a ztlumení povolí RLS jen tomu, kdo je v `hosts.user_id` nebo má `is_admin`.

**Placený účet (později)** — `supporter_until` nastavuje edge funkce z App Store Server Notifications (StoreKit 2), ne appka. Odznak ★ = `supporter_until > now()`.

### Jak neprůsvitnou prázdnotu udělat přijatelnou
- **Nikdy neukazovat počty online** („0 lidí v chatu“). Badge „ŽIVĚ“ v hlavičce chatu patří k vysílání, ne k chatu.
- **Předěly pořadů a dní** dělají ze streamu „deník vysílání“ — i když v něm jsou 3 zprávy za den, vypadá to jako záznam, ne jako prázdný pokoj.
- **Připnutá zpráva moderátora** (uvítání, téma dne, otázka pro posluchače) nahoře ve sheetu i jako první řádek karty na homepage, pokud nic novějšího není.
- **Konverzační startér v prázdném stavu**: „Dnes tu zatím ticho. Co posloucháš? Pozdrav DJ Pufaze 👋“ + rychlá emoji.
- **Rychlá emoji** (🔥 ❤️ 😂 🎶 👏 💜 🎧) snižují bariéru „napsat něco chytrého“. Stejná emoji poslaná za sebou během 60 s se slučují do jedné bubliny „🔥 ×4“ — žádný spam, ale vidět odezvu.
- **Na homepage** u poslední zprávy relativní čas: „před 2 h“. Pokud je nejnovější zpráva starší než 24 h, karta se přepne do stavu „startér“ (viz artboard A3).
- **Budoucí most z WhatsAppu**: zprávy, které moderátor přepošle/označí z WhatsAppu, se mohou objevit v chatu jako „via WhatsApp“ — dočasně naplní prostor, než se komunita přesune. (v2, jen zmínka v designu)

### Flow přihlášení z chatu („draft‑first“)
1. Nepřihlášený uživatel vidí v sheetu normální composer s placeholderem „Napiš zprávu…“ a pod ním drobný text „Pro psaní se přihlas“.
2. Může psát i klikat na emoji. **Při odeslání** se místo odeslání vysune auth sheet: „Připoj se do chatu“ — Apple / Google / e‑mail. Rozepsaná zpráva zůstává viditelná v pozadí.
3. Po přihlášení (nový účet) → krok **Tvoje přezdívka** (předvyplněný návrh z Apple/Google jména, validace živě).
4. Po uložení se sheet zavře a **zpráva se odešle automaticky** (toast „Zpráva odeslána jako vinylovy_tom“).
5. Existující účet s přezdívkou → krok 3 se přeskočí.
6. Zrušení auth sheetu → draft zůstane v composeru, nic se neztratí.

Alternativa (konzervativnější): místo composeru tlačítko „Přihlas se a piš“. Doporučuji draft‑first — vyšší konverze, protože člověk už do zprávy investoval.

### Pravidla změny přezdívky (Profil)
- Řádek „Přezdívka“ v Profilu → editační obrazovka.
- Pokud je změna možná: pole + „Uložit“, pod tím info „Přezdívku můžeš měnit jednou za 24 hodin.“
- Po uložení: potvrzovací dialog „Opravdu změnit na … ? Další změna bude možná zítra v 8:04.“
- V cooldownu: pole zamčené, text „Další změna možná za 17 h 22 min (zítra 8:04)“.
- Staré zprávy zobrazují **aktuální** přezdívku (zprávy jsou vázané na `user_id`), takže přejmenování nemaže stopu.

---

## 2. Prompt pro Figma Make

> Zkopíruj od řádku níže. Přilož k němu screenshot stávajících artboardů (homepage + chat sheety), Make z nich převezme vizuální styl.

```
Navrhni chat pro iOS aplikaci internetového rádia „Slow Down Rádijo“. Převezmi přesně vizuální styl z přiložených artboardů: tmavé fialovo‑námořnické pozadí, karty o odstín světlejší se zaoblením ~16 px, bílý text, sekundární text šedofialový, akcentová červeno‑růžová (tlačítka, ON‑AIR, moderátor), font geometrický sans (Inter/Manrope styl), malé velikosti písma jako v podkladu. Rámy iPhone 393×852, status bar 08:04, dole tab bar se 4 záložkami: Rádio, Statistiky, Vzkaz, Profil. Všechny texty česky.

KONCEPT
- Jeden společný chat pro celé rádio (ne místnosti po pořadech). Do streamu se automaticky vkládají předěly pořadů: tenká linka + „▶ 07:00 Morning Coffee · DJ Pufaz“ a denní předěly „Dnes“, „Včera“. Předěl se zobrazuje JEN před první zprávou daného pořadu/dne — pořady a dny bez zpráv se ve streamu vůbec neobjeví (žádné prázdné linky za sebou).
- Zpráva = barevná iniciála (kroužek 20 px) + přezdívka (tučně) + text + čas (šedě, malý, vpravo nebo pod). Žádné avatary s fotkami.
- Role: 
  • Moderátor/DJ: jméno v akcentové červené, odznak „DJ“, ikona 🎙 když je jeho pořad právě ON‑AIR, zpráva má jemně tónované pozadí (akcent 8 % opacity) a levý 2px proužek v akcentu.
  • Podporovatel (placený účet, budoucí): jméno v teplé zlaté barvě + malý odznak ★, bez pozadí. Vizuálně vždy slabší než DJ.
  • Běžný posluchač: bílé jméno.
- Připnutá zpráva DJ: lišta pod hlavičkou sheetu s ikonou špendlíku, 1–2 řádky, sbalitelná.
- Rychlá emoji řada: 🔥 ❤️ 😂 🎶 👏 💜 🎧. Opakované emoji se slučují do bubliny „🔥 ×4“.
- Nikde nezobrazuj počet lidí online.
- Čtení je bez přihlášení, psaní vyžaduje přihlášení.

ARTBOARDY (každý jako samostatný frame, nadpis nad framem):

A. HOMEPAGE – karta chatu (mezi přehrávačem a „Tvoje statistiky poslechu“)
 A1 Aktivní: hlavička „Chat“ + vpravo „3 nové“ (badge). 3 poslední zprávy (jedna od DJ Pufaz se zvýrazněním), relativní časy „teď“, „před 4 min“. Pod nimi pill „Napiš zprávu…“ a řada rychlých emoji.
 A2 Klidný: 2 poslední zprávy s časem „před 3 h“ a „před 5 h“. Stejný composer.
 A3 Prázdný / starší než 24 h: připnutá zpráva DJ („Dobré ráno! Co dnes posloucháte u kafe?“) + text „Dnes tu zatím ticho — pozdrav DJ Pufaze 👋“ + emoji řada jako hlavní akce.
 A4 Nepřihlášený: jako A1, pod composerem drobně „Číst může každý, psát po přihlášení“.
 Celá homepage ve frame A1 (přehrávač nahoře, karta chatu, statistiky, týdenní program, tab bar), ostatní varianty jen jako výřez karty.

B. CHAT SHEET – přihlášený, plná výška
 Nahoře zůstává mini‑přehrávač (cover, „The Best of Slow Down“, „Moderuje DJ Pufaz“). Sheet s grabberem, hlavička „Chat · ŽIVĚ“ (ŽIVĚ se vztahuje k vysílání), podtitul aktuálního pořadu, křížek. Připnutá zpráva. Stream: předěl „Včera“, několik zpráv, předěl pořadu „▶ 22:00 Noční linka · Slowdown Crew“, předěl „Dnes“, předěl „▶ 07:00 Morning Coffee · DJ Pufaz“, zprávy včetně DJ a podporovatele, sloučená bublina „🔥 ×4“. Dole emoji řada, „Píšeš jako vinylovy_tom“, composer s tlačítkem nastavení vlevo, emoji vpravo a červeným tlačítkem odeslat.

C. CHAT SHEET – psaní s klávesnicí (iOS klávesnice CZ, návrhy slov), rozepsaný text, aktivní odesílací tlačítko.

D. CHAT SHEET – historie: uživatel odscrollovaný nahoru, plovoucí pill „↓ 6 nových zpráv“ nad composerem.

E. CHAT SHEET – výběr emoji: panel místo klávesnice, mřížka 8 sloupců, nadpis „Emoji“, „Vyber emoji a odešli ho i bez textu“.

F. CHAT SHEET – prázdný den: předěl „Včera“ se 2 zprávami (pod předělem pořadu „▶ 20:00 Weekend Aftertaste“), žádný předěl „Dnes“ ani předěl aktuálního pořadu (zatím v něm nikdo nepsal — kontext nese jen hlavička sheetu), pod zprávami ilustrativní prázdný stav: ikona vlny/mikrofonu, „Dnes tu zatím ticho“, „Začni ty — pozdrav DJ Pufaze nebo napiš, co posloucháš.“ + tři chips s návrhy („Dobré ráno 👋“, „Co to teď hrálo?“, „🔥“).

G. CHAT SHEET – nepřihlášený: stejný stream jako B, composer aktivní s placeholderem „Napiš zprávu…“, pod ním „Pro odeslání se přihlas“. Bez řádku „Píšeš jako…“.

H. AUTH SHEET „Připoj se do chatu“ (vysune se po stisku Odeslat v G, rozepsaná zpráva „Tenhle groove jede 🔥“ je vidět ztmavená v pozadí):
 Nadpis, text „Čtení je pro všechny. Psát můžeš po přihlášení — zabere to pár vteřin.“, tlačítka „Pokračovat s Apple“ (bílé), „Pokračovat s Google“, „Pokračovat e‑mailem“, drobně odkaz na Pravidla chatu a Zásady ochrany soukromí, „Teď ne“.

I. E‑MAIL – zadání e‑mailu a obrazovka „Zkontroluj e‑mail, poslali jsme ti přihlašovací odkaz“ (2 malé framy).

J. PŘEZDÍVKA – první nastavení po registraci (3 stavy):
 J1 Výchozí: „Tvoje přezdívka“, „Pod tímhle jménem tě uvidí ostatní v chatu.“, pole předvyplněné návrhem „tomas_v“, počítadlo 7/20, pravidla „3–20 znaků: písmena bez diakritiky, číslice, tečka a podtržítko“, info „Změnit ji půjde v Profilu, nejvýš jednou za 24 hodin.“, tlačítko „Uložit a odeslat zprávu“.
 J2 Platná: zelená fajfka v poli, „vinylovy_tom je volná“, aktivní červené tlačítko.
 J3 Chyba: červený rámeček, „Tahle přezdívka je obsazená“ / „Mezery a diakritika nejsou povolené“, návrhy volných variant jako chips („vinylovy_tom2“, „vinyl.tom“).

K. CHAT SHEET – po odeslání: navazuje na F — s první zprávou dne se nad ní nově objeví předěl „Dnes“ a „▶ 07:00 Morning Coffee · DJ Pufaz“, zpráva uživatele pod nimi, toast „Odesláno jako vinylovy_tom“. Variantně zpráva ve stavu „odesílám…“ (ztlumená) a „Neodesláno · Zkusit znovu“ (červeně).

L. AKCE NA ZPRÁVĚ (podržení):
 L1 Běžný uživatel na cizí zprávě: Kopírovat, Nahlásit, Skrýt zprávy od uživatele.
 L2 DJ/moderátor: Připnout, Smazat, Ztlumit na 24 h, Zablokovat, Kopírovat. Smazaná zpráva se ve streamu zobrazí jako „Zpráva byla odstraněna moderátorem“.
 L3 Uživatel ve stavu ztlumení: composer nahrazen textem „Psaní máš pozastavené do 9:15. Pravidla chatu“.

M. PROFIL – záložka Profil (přihlášený): hlavička s iniciálou a přezdívkou, odznak role (příp. „Podporovatel ★“ jako budoucí stav), řádky: Přezdívka (vinylovy_tom ›), E‑mail / způsob přihlášení, Notifikace, Pravidla chatu, Odhlásit se, Smazat účet.
 M2 Profil nepřihlášený: „Přihlas se a piš do chatu“ + stejná tři tlačítka jako v H.

N. ÚPRAVA PŘEZDÍVKY (Profil):
 N1 Změna možná: pole, „Přezdívku můžeš měnit jednou za 24 hodin.“, tlačítko Uložit.
 N2 Potvrzení (dialog): „Změnit přezdívku na vinyl.tom? Další změna bude možná zítra v 8:04.“ Zrušit / Změnit.
 N3 Cooldown: pole zamčené (ikona zámku), „Další změna možná za 17 h 22 min (zítra 8:04)“, tlačítko neaktivní.

O. LEGENDA ROLÍ: samostatný frame s ukázkou typů zpráv vedle sebe (posluchač, podporovatel, DJ ON‑AIR, DJ mimo vysílání), připnutá zpráva, sloučená emoji bublina, systémový předěl pořadu, předěl dne, smazaná zpráva. Použij jako komponenty.

P. PROPOJENÍ DJ (otevření zvacího odkazu): P1 nepřihlášený — „Pozvánka pro moderátora DJ Pufaz“, foto moderátora z katalogu, „Přihlas se a propoj účet“ + tlačítka Apple/Google/e‑mail. P2 hotovo — „Jsi propojený jako DJ Pufaz“, náhled vlastní zprávy s odznakem DJ, „V chatu můžeš připínat, mazat a ztlumovat zprávy.“ P3 chyba — „Pozvánka vypršela nebo už byla použita. Napiš rádiu o novou.“

Připrav vše jako komponenty s variantami (Message: role × stav; Composer: přihlášen/nepřihlášen/ztlumen/psaní; ChatCard: aktivní/klidný/prázdný/nepřihlášený; NicknameField: výchozí/platné/chyba/zamčené). Framy uspořádej zleva doprava v pořadí A → P a propoj prototypem: A1 tap → B; G odeslat → H → J1 → K; M řádek Přezdívka → N1 → N2 → N3; P1 → P2.
```

---

## 2b. Figma v2 — co se oproti promptu změnilo (17. 11. 2026)

Výstup z Figma Make byl nahrazen ručně postavenými editovatelnými artboardy (sekce „Chat v2 — …“ v souboru Slow Down Rádijo). Rozdíly proti promptu výše:

- **Zpráva bez kroužku s iniciálou a bez času.** Jméno nad textem. Kdy se psalo, říkají předěly („Dnes · 07:00 Morning Coffee“); přesný čas je až v menu po podržení zprávy („Včera 23:41 · Noční linka“). Při malém provozu by časy u každé zprávy zbytečně ukazovaly hodinové mezery. Role jen barvou jména: posluchač `mutedText`, podporovatel `gold` + ★, DJ `liveRed` + štítek „DJ“. Žádné tónované pozadí ani levý proužek.
- **Bez ikony 🎙 ON‑AIR u DJ** — kdo moderuje, říká hlavička sheetu.
- **Předěl dne a pořadu je jeden řádek**: „Dnes · 07:00 Morning Coffee“, další pořad téhož dne „22:00 Noční linka“.
- **Composer bez tlačítka nastavení** (přezdívka je v Profilu). Pole a odeslat 44 pt, emoji 44×36.
- **Homepage: sekce bez rámečku (~192 pt)** — nadpis „Chat“ ve stylu ostatních sekcí (19 ExtraBold, bez ikony) a vpravo šipka, pod ním poslední 4 zprávy přímo na pozadí a pole „Napiš zprávu…“ (44 pt, bez řady emoji). Appku používají hlavně věrní posluchači, takže psaní má být na dosah: klepnutí do pole otevře chat rovnou s klávesnicí (píše se s kontextem konverzace, homepage neposkakuje); klepnutí jinam otevře chat bez klávesnice. Nepřihlášený píše stejně, přihlášení přijde až při odeslání. Zprávy jsou každá na jeden řádek („jméno  text…“), nejnovější dole a jako jediná s textem v plné bílé, starší výš a postupně bledší (40 / 60 / 80 / 100 %). Žádné tečky ani osa, **žádný počet nových**, bez času. Stavy jen dva: Běžný a Ticho (nic za 24 h: připnutá otázka DJ + „Dnes tu zatím ticho — pozdrav DJ Pufaze 👋“).
- **Ticker:** novinky se poznají pohybem, ne číslem. Po otevření appky dlaždice ukáže, co už posluchač viděl, a po 600 ms nové zprávy „dohraje“ jednu po druhé (rozestup 1,2 s, nejvýš 4, při víc jedna animace na poslední čtyři). Za běhu přijede nová zpráva stejně. Pohyb: řádky o 26 pt nahoru, 350 ms `Motion.smoothOut`, nová z +8 pt a blur 2 pt (P22 Reveal), nejstarší zmizí v ořezu, bílý text přejde na novou zprávu. Bez nových zpráv se nic nehýbe. Reduce Motion = okamžitá výměna. „Viděl“ = čas posledního zobrazení dlaždice/chatu, uložený v telefonu. Storyboard: Figma → stránka Chat → „Homepage s chatem“ → „Ticker — dohrání nových zpráv“.
- **Pozvánka DJ bez fotky** — místo ní náhled zprávy se štítkem DJ, ať je jasné, co propojení udělá.
- **Typografie podle `Theme.Typography`**: text zprávy 16 Regular (`Copy.reading`), jméno 13 ExtraBold, čas a popisky 13 SemiBold (`Copy.label`), nadpis sheetu 21 (`Heading.hero`), sekce 19, tlačítka 15 ExtraBold. Nic menšího než 13 kromě štítku „DJ“ (12).

## 2c. Přihlášení a záložka Profil

**Způsoby přihlášení:** Apple, Google, e‑mail bez hesla (6místný kód, platí 10 minut; v e‑mailu je zároveň odkaz, který appku otevře). Přihlášení a registrace jsou jeden flow — neexistující e‑mail účet rovnou založí, nový účet pak projde krokem „Ještě přezdívka“.
- Apple je povinný, jakmile appka nabízí Google (App Store, guideline 4.8).
- Smazání účtu přímo v appce je povinné (App Store, guideline 5.1.1(v)).
- Passkeys až později, SMS ne (cena za zprávu), Facebook ne.

**Stavy Profilu ve Figmě (sekce „Chat v2 — záložka Profil“):** nepřihlášený · e‑mail · kód · špatný kód · chyba přihlášení · registrace (přezdívka) · přihlášený · DJ (jméno z programu, přezdívku nemění) · ztlumený (banner s časem) · změna přezdívky (možná / potvrzení / čeká se 24 h) · skrytí uživatelé · pravidla chatu · potvrzení odhlášení · potvrzení smazání účtu (zprávy zůstanou jako „Smazaný účet“).

## 2d. Moderace: smazání, ztlumení, blokace

| Akce | Kdo | Dopad | Konec | Potvrzení |
|---|---|---|---|---|
| Smazat zprávu | DJ, admin | Zpráva se nahradí „Zprávu odstranil moderátor“ | — | Ne, oznámení s „Vrátit“ (4 s) |
| Ztlumit | DJ, admin | Autor nemůže psát ani posílat emoji; číst a poslouchat může | Sám po 1 h / 24 h / 7 dnech (výchozí 24 h), nebo dřív „Zrušit ztlumení“ | Výběr délky, pak oznámení s „Vrátit“ |
| Zablokovat | DJ, admin | Jako ztlumení, ale natrvalo | Jen když ho admin zruší | Ano, potvrzovací sheet |
| Skrýt uživatele | Kdokoli | Jen u mě se jeho zprávy nezobrazují | V Profilu → Skrytí uživatelé → Zobrazit | Ne |

- Data: `chat_mutes` (`user_id`, `muted_by`, `message_id`, `until`, `until = null` = blokace). Psaní hlídá RLS politika na `messages` (`insert` jen bez aktivního záznamu), takže to nejde obejít upraveným klientem.
- Ztlumení je tiché — ostatní posluchači nic nevidí. Ztlumený vidí místo pole pro psaní „Psaní máš pozastavené do zítra 8:04“ a stejný banner v Profilu.
- U zprávy ztlumeného uživatele vidí DJ v menu „Ztlumený do … · ztlumil DJ …“ a akci „Zrušit ztlumení · zbývá 17 h“.

## 2e. Chat v3 — psaní bez účtu, Slowriders a správa (návrh 18. 11. 2026, čeká na schválení ve Figmě)

Registrace je **předpoklad pro budoucí prémiové funkce**, ne podmínka chatu. Chat se nezamyká; registraci motivuje první funkce navíc: změna přezdívky.

**Psaní bez účtu (Figma Chat: G, J1–J3, H)**
- Kdo nemá účet, píše normálně. Při **první zprávě** vyjede „Tvoje přezdívka“ (J1–J3, „Účet k tomu nepotřebuješ“), po uložení se zpráva odešle.
- Přezdívka se uloží k anonymnímu účtu, který appka už má kvůli statistikám (na iOS přežije přeinstalaci, je v Klíčence).
- V okně přezdívky je odkaz **„Už máš účet? Přihlas se“** → H (přihlášení existujícím účtem; vrátí se přezdívka i statistiky).
- **Změnu přezdívky** má jen registrovaný Slowrider. Klepnutí na zamčenou přezdívku v Profilu → M8 „Přezdívku změníš s účtem“.
- Registrace povýší anonymní účet: přezdívka, zprávy i statistiky zůstanou. **První změna hned po registraci je bez 24h čekání**, další už jednou za 24 h.
- Riziko: ztlumení/blokace anonyma se dá na Androidu obejít přeinstalací (nový anonymní účet). Krotí to rate limit a moderace; kdyby se to zneužívalo, psaní se dá znovu podmínit registrací jedním přepínačem na serveru.

**Profil (Figma Profil: M2, M7–M11)**
- M2 prázdný: „Staň se Slowriderem“ a výhody registrace: správa profilu včetně změny přezdívky; statistiky poslechu u účtu, přenositelné na nový telefon; další výhody budou přibývat.
- M7 píše bez účtu: přezdívka se zámkem, karta „Staň se Slowriderem“, „Smazat moje údaje“.
- M9 po registraci: oznámení „Vítej mezi Slowriders! Přezdívku teď můžeš změnit.“
- M1/M11 registrovaný: „Jsi součástí Slowriders od 18. 11. 2026“ (datum registrace = první trvalá identita, na serveru `profiles.registered_at`).
- M11 **Tvůj Slowride** (malý dashboard): jak dlouho je Slowriderem, odposloucháno celkem, zprávy v chatu, hlasové vzkazy, top 3 pořady podle času poslechu.
  - Počet zpráv a vzkazů potřebuje čítače na serveru (`profiles.chat_messages_count`, `voice_messages_count`): zprávy se po 90 dnech mažou a hlasové vzkazy dnes jdou jen e-mailem bez vazby na účet. Počítat se tedy bude od nasazení.

**Superadmin a správa (Figma Profil: M10, A1–A6)**
- Role: posluchač → **správce** (moderuje pod svou přezdívkou, ruší blokace) → **superadmin** (navíc zve DJe a spravuje správce). Radek = superadmin (`profiles.is_superadmin`, nastaví se jednou po jeho registraci).
- Profil superadmina má sekci **Správa chatu**: DJové a Správci.
- A1 DJové: seznam s propojením (propojený / pozvánka čeká / bez účtu) → A2 výběr DJe z programu (nebo host mimo program) → A3 odkaz se Sdílet / Kopírovat (7 dní, jednou) → A4 detail DJe: nová pozvánka, odpojit účet.
- A5 Správci → A6 přidat správce podle přezdívky (jen registrovaný Slowrider).
- Hosté a pozvánky tak už nejsou potřeba v Table Editoru; SQL v README zůstane jako nouzová cesta.

**Archiv chatu pro analýzy (návrh)**
- Před 90denním smazáním přesunout zprávy do archivní tabulky **bez vazby na účet** (bez `user_id` a přezdívky; zůstane text, čas, pořad, role autora). Text může sám obsahovat osobní údaje, proto archiv jen pro interní analýzy, ne veřejný, a zmínit ho v zásadách.
- Smazání účtu maže vazbu, ne archivovaný text (ten už na účet vázaný není).

## 3. Otevřené otázky na později
- Retence historie (návrh: zobrazovat 7 dní, ukládat 90 dní kvůli moderaci).
- Push notifikace: jen na připnutou zprávu DJ / odpověď moderátora? (v1 vypnuto).
- Odpovídání na konkrétní zprávu a zmínky @ — v2.
- Most z WhatsAppu — jakou formou zprávy přenášet a s jakým souhlasem pisatelů.
- Pravidla chatu (text) — nutné před spuštěním kvůli App Store (UGC: nahlášení, blokace, moderace jsou povinné — pokryto v L).

# Zásady ochrany osobních údajů — Slow Down Rádijo (aplikace)

*Poslední aktualizace: [DOPLNIT DATUM PŘED ZVEŘEJNĚNÍM]*

Tento dokument popisuje, jaké údaje aplikace Slow Down Rádijo pro iOS (a Android, pokud vznikne) zpracovává. Aplikaci provozuje [DOPLNIT: jméno/název provozovatele, IČO pokud relevantní], kontakt: jsem@radekschenk.cz.

## Aplikace nevyžaduje žádný účet

Aplikaci lze plně používat bez registrace, přihlášení nebo zadávání jména či e-mailu. Neshromažďujeme žádné trvalé identifikátory uživatele ani reklamní ID a aplikace nikoho nesleduje napříč jinými appkami nebo weby.

## Jaké údaje aplikace zpracovává

**Uloženo pouze v telefonu (nikam se neodesílá):**
- Oblíbené skladby, historie "Co hrálo", nastavení jazyka/vzhledu/notifikací — vše zůstává lokálně na zařízení a lze to kdykoliv smazat odinstalováním aplikace.

**Odesíláno na vyžádání uživatele:**
- **Zpětná vazba** — pokud v appce napíšeš zprávu vývojáři, spolu s textem se odešle i základní technický přehled (verze appky, verze systému, model zařízení, jazyk a vzhled aplikace), aby šlo případnou chybu skutečně dohledat. Nic z toho neobsahuje jméno, e-mail ani jiný osobní identifikátor, pokud ho sám nenapíšeš do textu zprávy.
- **Hlasový vzkaz** — pokud si v appce nahraješ a odešleš hlasovou zprávu pro rádio, nahrávka se odešle na e-mail rádia za účelem případného odvysílání.

Obojí se odesílá přes zabezpečené API a doručuje e-mailem přes službu [Resend](https://resend.com) — zprávy nejsou nikde veřejně publikovány ani sdíleny s třetími stranami mimo doručení e-mailu.

## Použité služby třetích stran

- **Supabase** — databáze a serverová logika appky (historie přehraných skladeb, statistiky). Nepracuje s žádnými osobními údaji uživatele appky.
- **Resend** — doručení e-mailů (zpětná vazba, hlasové vzkazy) na adresu rádia.
- **Apple iTunes Search API** — vyhledání obalu alba a krátké ukázky skladby podle názvu/interpreta; appka posílá jen text názvu a interpreta, nic osobního.
- **slowdownradijo.cz** — appka čte veřejný obsah webu (rubrika Novinky) přes standardní WordPress rozhraní.

## Mikrofon

Aplikace požaduje přístup k mikrofonu výhradně pro nahrání hlasového vzkazu v sekci "Vzkaz" — pouze když to sám aktivně spustíš, nikdy na pozadí.

## Sledování a reklama

Aplikace neobsahuje žádné reklamní ani analytické SDK třetích stran, nezobrazuje reklamy a nesleduje chování uživatele pro marketingové účely.

## Děti

Aplikace není cílená na děti a vědomě neshromažďuje údaje od dětí mladších 13 let.

## Změny těchto zásad

Tento dokument může být čas od času aktualizován. Aktuální verze je vždy dostupná na [DOPLNIT URL].

## Kontakt

Dotazy k ochraně osobních údajů směřuj na: jsem@radekschenk.cz

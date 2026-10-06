# Zásady ochrany osobních údajů — Slow Down Rádijo (aplikace)

*Poslední aktualizace: [DOPLNIT DATUM PŘED ZVEŘEJNĚNÍM]*

Tento dokument popisuje, jaké údaje aplikace Slow Down Rádijo pro iOS (a Android, pokud vznikne) zpracovává. Aplikaci provozuje **Slow Down Radio s.r.o.**, IČO 23309440, se sídlem Jeseniova 1575/69, Žižkov, 130 00 Praha 3 (kontakt: info@slowdownradijo.cz). Technickou stránku aplikace a zpětnou vazbu má na starosti jsem@radekschenk.cz.

## Aplikace nevyžaduje žádný účet

Aplikaci lze plně používat bez registrace, přihlášení nebo zadávání jména či e-mailu. Neshromažďujeme reklamní ID ani identifikátory zařízení a aplikace nikoho nesleduje napříč jinými appkami nebo weby.

Jediný trvalý identifikátor, který aplikace používá, je **náhodné anonymní ID** pro statistiky poslechu (viz níže). Nevzniká z tvého jména, e-mailu, telefonu ani z žádného identifikátoru zařízení a nelze z něj tebe jako osobu odvodit.

## Jaké údaje aplikace zpracovává

**Uloženo pouze v telefonu (nikam se neodesílá):**
- Oblíbené skladby, historie "Co hrálo", nastavení jazyka/vzhledu/notifikací — vše zůstává lokálně na zařízení a lze to kdykoliv smazat odinstalováním aplikace.

**Statistiky poslechu (zapnuté ve výchozím stavu, lze vypnout):**
- Aplikace měří, **kolik sekund rádio v appce skutečně hraje** — za každý kalendářní den (podle času v tvém telefonu) a za každý pořad zvlášť. Měří se jen přehrávání, ne to, co se na obrazovce prohlížíš.
- K tomu se na server odesílá **náhodné anonymní ID** (vytvoří se při prvním delším poslechu a uloží se do zabezpečeného úložiště klíčů v telefonu, takže přežije přeinstalaci appky) a **verze appky**. Neodesíláme přesné časy jednotlivých poslechů ani model zařízení. Do databáze se statistikami se IP adresa neukládá; jako při každé komunikaci přes internet ji ale po omezenou dobu vidí provozní logy poskytovatele služby (Supabase), a to jen pro zajištění provozu a bezpečnosti.
- Z těchto údajů appka ukazuje **tvoje vlastní statistiky** (čas dnes, celkem, poslech po dnech a po pořadech), **tvoje pořadí** mezi posluchači appky a **celkový čas poslechu všech posluchačů**. Ostatním posluchačům se nezobrazuje nic, co by tě identifikovalo — vidí jen souhrnná čísla a své vlastní pořadí.
- Statistiky se v appce zobrazí, až když je v aplikaci dostatek posluchačů; měření ale probíhá od začátku.
- **Právní základ:** oprávněný zájem provozovatele rádia znát poslechovost a nabídnout posluchačům statistiky (čl. 6 odst. 1 písm. f) GDPR).
- **Doba uchování:** do smazání — kdykoli v appce (Menu ▸ Nastavení ▸ Smazat moje statistiky), nebo automaticky po 24 měsících, kdy appku nepoužiješ.
- **Co po smazání zůstane:** když statistiky smažeš ručně, zmizí úplně, včetně tvého podílu na celkovém čase všech posluchačů. Při automatickém smazání po 24 měsících nepoužívání odstraníme celý tvůj záznam a ze žebříčku zmizíš; jen **celkový počet odposlouchaných sekund** se přičte do jednoho anonymního souhrnného čísla, aby celkový čas posluchačů neklesal. Toto číslo neobsahuje žádné ID ani jiný údaj, podle kterého by šlo kohokoli určit.
- **Vypnutí:** v Menu ▸ Nastavení ▸ Statistiky poslechu. Po vypnutí se nic neměří ani neodesílá; už uložené údaje zůstanou, dokud je nesmažeš.
- Pokud budeme v budoucnu nabízet volitelnou registraci, propojení dosavadních statistik s tvým profilem proběhne jen s tvým vědomím a tyto zásady aktualizujeme předem.

**Odesíláno na vyžádání uživatele:**
- **Zpětná vazba** — pokud v appce napíšeš zprávu vývojáři, spolu s textem se odešle i základní technický přehled (verze appky, verze systému, model zařízení, jazyk a vzhled aplikace), aby šlo případnou chybu skutečně dohledat. Nic z toho neobsahuje jméno, e-mail ani jiný osobní identifikátor, pokud ho sám nenapíšeš do textu zprávy.
- **Hlasový vzkaz** — pokud si v appce nahraješ a odešleš hlasovou zprávu pro rádio, nahrávka se odešle na e-mail rádia za účelem případného odvysílání.

Obojí se odesílá přes zabezpečené API a doručuje e-mailem přes službu [Resend](https://resend.com) — zprávy nejsou nikde veřejně publikovány ani sdíleny s třetími stranami mimo doručení e-mailu.

## Použité služby třetích stran

- **Supabase** — databáze a serverová logika appky (historie přehraných skladeb, anonymní statistiky poslechu). Zpracovává pouze anonymní ID a sečtené sekundy poslechu popsané výše, žádné jméno ani e-mail. Data jsou uložena v regionu [DOPLNIT REGION PROJEKTU, např. EU – Frankfurt].
- **Resend** — doručení e-mailů (zpětná vazba, hlasové vzkazy) na adresu rádia.
- **Apple iTunes Search API** — vyhledání obalu alba a krátké ukázky skladby podle názvu/interpreta; appka posílá jen text názvu a interpreta, nic osobního.
- **slowdownradijo.cz** — appka čte veřejný obsah webu (rubrika Novinky) přes standardní WordPress rozhraní.

## Mikrofon

Aplikace požaduje přístup k mikrofonu výhradně pro nahrání hlasového vzkazu v sekci "Vzkaz" — pouze když to sám aktivně spustíš, nikdy na pozadí.

## Sledování a reklama

Aplikace neobsahuje žádné reklamní ani analytické SDK třetích stran, nezobrazuje reklamy a nesleduje chování uživatele pro marketingové účely. Anonymní statistiky poslechu slouží jen k zobrazení tvých statistik v appce a k souhrnnému přehledu poslechovosti rádia; nepředáváme je třetím stranám a nepoužíváme je k reklamě.

## Tvoje práva

Můžeš kdykoli **vypnout měření** a **smazat své statistiky** přímo v appce (Menu ▸ Nastavení). Protože jsou statistiky vázané jen na anonymní ID v tvém telefonu, nedokážeme je spárovat s konkrétní osobou — využít další práva (přístup, výmaz) tak jde právě přes appku. S dotazy nebo stížností se na nás můžeš obrátit na info@slowdownradijo.cz; máš také právo podat stížnost u Úřadu pro ochranu osobních údajů (uoou.cz).

## Děti

Aplikace není cílená na děti a vědomě neshromažďuje údaje od dětí mladších 13 let.

## Změny těchto zásad

Tento dokument může být čas od času aktualizován. Aktuální verze je vždy dostupná na [DOPLNIT URL].

## Kontakt

Dotazy k ochraně osobních údajů směřuj na: info@slowdownradijo.cz (provozovatel) nebo jsem@radekschenk.cz (technická stránka aplikace).

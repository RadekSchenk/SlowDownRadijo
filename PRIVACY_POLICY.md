# Zásady ochrany osobních údajů — Slow Down Rádijo (aplikace)

*Poslední aktualizace: [DOPLNIT DATUM PŘED ZVEŘEJNĚNÍM]*

Tento dokument popisuje, jaké údaje aplikace Slow Down Rádijo pro iOS (a Android, pokud vznikne) zpracovává. Aplikaci provozuje **Slow Down Radio s.r.o.**, IČO 23309440, se sídlem Jeseniova 1575/69, Žižkov, 130 00 Praha 3 (kontakt: info@slowdownradijo.cz). Technickou stránku aplikace a zpětnou vazbu má na starosti jsem@radekschenk.cz.

## Aplikace nevyžaduje žádný účet

Aplikaci lze plně používat bez registrace, přihlášení nebo zadávání jména či e-mailu. Neshromažďujeme reklamní ID ani identifikátory zařízení od Applu a aplikace nikoho nesleduje napříč jinými appkami nebo weby.

Aplikace používá nanejvýš dvě **náhodná anonymní ID**, která spolu nejsou nijak propojená: jedno pro statistiky poslechu a druhé pro anonymní měření používání, jen pokud s ním souhlasíš (viz níže). Žádné z nich nevzniká z tvého jména, e-mailu, telefonu ani z identifikátoru zařízení a nelze z nich tebe jako osobu odvodit.

## Jaké údaje aplikace zpracovává

**Uloženo pouze v telefonu (nikam se neodesílá):**
- Oblíbené skladby, historie "Co hrálo", nastavení jazyka/vzhledu/notifikací — vše zůstává lokálně na zařízení a lze to kdykoliv smazat odinstalováním aplikace.

**Statistiky poslechu (zapnuté ve výchozím stavu, lze vypnout):**
- Aplikace měří, **kolik sekund rádio v appce skutečně hraje** — za každý kalendářní den (podle času v tvém telefonu) a za každý pořad zvlášť. Měří se jen přehrávání, ne to, co se na obrazovce prohlížíš.
- K tomu se na server odesílá **náhodné anonymní ID** (vytvoří se při prvním delším poslechu a uloží se do zabezpečeného úložiště klíčů v telefonu, takže přežije přeinstalaci appky) a **verze appky**. Neodesíláme přesné časy jednotlivých poslechů ani model zařízení. Do databáze se statistikami se IP adresa neukládá; jako při každé komunikaci přes internet ji ale po omezenou dobu vidí provozní logy poskytovatele služby (Supabase), a to jen pro zajištění provozu a bezpečnosti.
- Z těchto údajů appka ukazuje **tvoje vlastní statistiky** (čas dnes, celkem, poslech po dnech a po pořadech), **tvoje pořadí** mezi posluchači appky a **celkový čas poslechu všech posluchačů**. Ostatním posluchačům se nezobrazuje nic, co by tě identifikovalo — vidí jen souhrnná čísla a své vlastní pořadí.
- Tvoje vlastní statistiky vidíš v appce hned. Žebříček a celkový čas všech posluchačů se zobrazí, až bude v aplikaci dostatek posluchačů; měření ale probíhá od začátku.
- **Právní základ:** oprávněný zájem provozovatele rádia znát poslechovost a nabídnout posluchačům statistiky (čl. 6 odst. 1 písm. f) GDPR).
- **Doba uchování:** do smazání — kdykoli v appce (Menu ▸ Nastavení ▸ Smazat moje statistiky), nebo automaticky po 24 měsících, kdy appku nepoužiješ.
- **Co po smazání zůstane:** když statistiky smažeš ručně, zmizí úplně, včetně tvého podílu na celkovém čase všech posluchačů. Při automatickém smazání po 24 měsících nepoužívání odstraníme celý tvůj záznam a ze žebříčku zmizíš; jen **celkový počet odposlouchaných sekund** se přičte do jednoho anonymního souhrnného čísla, aby celkový čas posluchačů neklesal. Toto číslo neobsahuje žádné ID ani jiný údaj, podle kterého by šlo kohokoli určit.
- **Vypnutí:** v Menu ▸ Nastavení ▸ Statistiky poslechu. Po vypnutí se nic neměří ani neodesílá; už uložené údaje zůstanou, dokud je nesmažeš.
- Pokud budeme v budoucnu nabízet volitelnou registraci, propojení dosavadních statistik s tvým profilem proběhne jen s tvým vědomím a tyto zásady aktualizujeme předem.

**Souhrnné přehledy poslechovosti (z údajů statistik poslechu):**
- Ze stejných údajů (anonymní ID, sekundy poslechu po dnech a pořadech) sestavujeme pro rádio **souhrnné přehledy**: kolik posluchačů appku používá denně, týdně a měsíčně, kolik průměrně a celkem poslouchají, jak často se vracejí (příležitostní, pravidelní a věrní posluchači) a které pořady se poslouchají nejvíc.
- Přehledy obsahují jen součty a průměry, nikdy údaje o jednom konkrétním posluchači. Nejsou veřejné a nepředáváme je třetím stranám v podobě, podle které by šlo kohokoli určit.
- Právní základ, doba uchování i vypnutí jsou stejné jako u statistik poslechu výše: kdo statistiky vypne nebo smaže, do dalších přehledů se nezapočítá.

**Anonymní měření používání (jen se souhlasem, ve výchozím stavu vypnuté):**
- Po několika spuštěních se appka jednou zeptá, jestli smí anonymně měřit, **které funkce používáš**. Dokud neklepneš na „Povolit“, nic se neměří ani neodesílá. Volbu můžeš kdykoli změnit v Menu ▸ Nastavení ▸ Anonymní měření používání.
- Co se měří: spuštění appky, které obrazovky otevřeš, spuštění a zastavení přehrávání (jak dlouho hrálo, zaokrouhleno, a proč skončilo), chyby přehrávání, nastavení časovače, zapnutí upozornění na pořad a otevření takového upozornění, přepnutí jazyka, klepnutí na odkazy (Spotify, sociální sítě, platformy podpory) a to, jestli se podařilo odeslat vzkaz nebo zpětnou vazbu. Ke každé události se přidá jazyk appky, verze appky a systému, typ zařízení (telefon/tablet, ne přesný model), časové pásmo a typ připojení (Wi-Fi/mobilní data).
- Co se neměří: žádný text, který napíšeš, žádná nahrávka, názvy skladeb, poloha, reklamní ID, kontakty ani nic, co by vedlo k tvé osobě. Nesledujeme klepání po obrazovce ani nenahráváme obrazovku.
- Události se ukládají pod **samostatným náhodným ID** (jiným než u statistik poslechu). Zpracovatelem je **PostHog** (PostHog Inc.) s daty uloženými v **EU (Frankfurt)**. IP adresu PostHog podle našeho nastavení neukládá.
- **Právní základ:** tvůj souhlas (čl. 6 odst. 1 písm. a) GDPR a § 89 odst. 3 zákona o elektronických komunikacích). Souhlas můžeš kdykoli odvolat v Nastavení; dosavadní zpracování tím nepřestává být zákonné.
- **Doba uchování:** nejdéle 12 měsíců, pak se události mažou.
- **Po odvolání souhlasu** appka přestane cokoli odesílat a zahodí své analytické ID; pokud souhlas znovu udělíš, vznikne nové ID, které se se starým nedá spojit.

**Odesíláno na vyžádání uživatele:**
- **Zpětná vazba** — pokud v appce napíšeš zprávu vývojáři, spolu s textem se odešle i základní technický přehled (verze appky, verze systému, model zařízení, jazyk a vzhled aplikace), aby šlo případnou chybu skutečně dohledat. Nic z toho neobsahuje jméno, e-mail ani jiný osobní identifikátor, pokud ho sám nenapíšeš do textu zprávy.
- **Hlasový vzkaz** — pokud si v appce nahraješ a odešleš hlasovou zprávu pro rádio, nahrávka se odešle na e-mail rádia za účelem případného odvysílání.

Obojí se odesílá přes zabezpečené API a doručuje e-mailem přes službu [Resend](https://resend.com) — zprávy nejsou nikde veřejně publikovány ani sdíleny s třetími stranami mimo doručení e-mailu. Jako ochranu proti zneužití (hromadnému rozesílání) si server po dobu 24 hodin pamatuje jen jednosměrný otisk (hash) IP adresy odesílatele a počet odeslaných zpráv; pak se záznam smaže.

## Použité služby třetích stran

- **Supabase** — databáze a serverová logika appky (historie přehraných skladeb, anonymní statistiky poslechu). Zpracovává pouze anonymní ID a sečtené sekundy poslechu popsané výše, žádné jméno ani e-mail. Data jsou uložena ve **Spojeném království (Londýn, region AWS eu-west-2)**. Spojené království má od Evropské komise rozhodnutí o odpovídající ochraně osobních údajů, takže přenos dat z EU je v souladu s GDPR bez dalších záruk.
- **PostHog** (PostHog Inc., data v EU, Frankfurt) — anonymní měření používání, jen pokud s ním souhlasíš (viz výše). Zpracovává pouze události popsané výše pod náhodným ID, bez IP adresy, jména a e-mailu.
- **Resend** — doručení e-mailů (zpětná vazba, hlasové vzkazy) na adresu rádia.
- **Apple iTunes Search API** — vyhledání obalu alba a krátké ukázky skladby podle názvu/interpreta; appka posílá jen text názvu a interpreta, nic osobního.
- **slowdownradijo.cz** — appka čte veřejný obsah webu (rubrika Novinky) přes standardní WordPress rozhraní.

## Mikrofon

Aplikace požaduje přístup k mikrofonu výhradně pro nahrání hlasového vzkazu v sekci "Vzkaz" — pouze když to sám aktivně spustíš, nikdy na pozadí.

## Sledování a reklama

Aplikace neobsahuje žádné reklamní SDK, nezobrazuje reklamy a nesleduje chování uživatele pro marketingové účely ani napříč jinými appkami a weby. Jediný analytický nástroj třetí strany (PostHog) běží jen se souhlasem a slouží ke zlepšování appky. Anonymní statistiky poslechu slouží jen k zobrazení tvých statistik v appce a k souhrnnému přehledu poslechovosti rádia; nepředáváme je třetím stranám a nepoužíváme je k reklamě.

## Tvoje práva

Můžeš kdykoli **vypnout měření**, **smazat své statistiky** a **odvolat souhlas s anonymním měřením používání** přímo v appce (Menu ▸ Nastavení). Protože jsou statistiky vázané jen na anonymní ID v tvém telefonu, nedokážeme je spárovat s konkrétní osobou — využít další práva (přístup, výmaz) tak jde právě přes appku. S dotazy nebo stížností se na nás můžeš obrátit na info@slowdownradijo.cz; máš také právo podat stížnost u Úřadu pro ochranu osobních údajů (uoou.cz).

## Děti

Aplikace není cílená na děti a vědomě neshromažďuje údaje od dětí mladších 13 let.

## Změny těchto zásad

Tento dokument může být čas od času aktualizován. Aktuální verze je vždy dostupná na [DOPLNIT URL].

## Kontakt

Dotazy k ochraně osobních údajů směřuj na: info@slowdownradijo.cz (provozovatel) nebo jsem@radekschenk.cz (technická stránka aplikace).

<!--
PŘIPRAVENO, ZATÍM NEZVEŘEJŇOVAT. Vložit do sekce „Anonymní měření používání“
a do „Použité služby třetích stran“ až ve chvíli, kdy appka začne posílat
data do Google Analytics (Firebase). Do té doby tento text v zásadách být nemá.

**Google Analytics for Firebase** (Google Ireland Limited) — stejné anonymní
události jako výše, jen pokud s měřením souhlasíš, pod náhodným ID instalace
(ne reklamním ID). Reklamní funkce a propojení s reklamními službami Google
jsou vypnuté a appka nesbírá reklamní identifikátor (IDFA). Data se
zpracovávají v EU a mohou být předána do USA na základě rámce EU–USA pro
ochranu osobních údajů (Data Privacy Framework), k němuž je Google
přistoupený. Doba uchování: 14 měsíců. Souhlas a jeho odvolání platí pro
PostHog i Google Analytics zároveň.
-->

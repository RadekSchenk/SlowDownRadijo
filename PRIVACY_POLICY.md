# Zásady ochrany osobních údajů — Slow Down Rádijo (aplikace)

*Poslední aktualizace: 18. listopadu 2026 (verze aplikace 1.3: účet a chat posluchačů)*

Tento dokument popisuje, jaké údaje aplikace Slow Down Rádijo pro iOS a Android zpracovává. Aplikaci provozuje **Slow Down Radio s.r.o.**, IČO 23309440, se sídlem Jeseniova 1575/69, Žižkov, 130 00 Praha 3 (kontakt: info@slowdownradijo.cz). Technickou stránku aplikace a zpětnou vazbu má na starosti jsem@radekschenk.cz.

## Účet je dobrovolný

Rádio, program, statistiky poslechu i chat posluchačů fungují bez registrace. Psát do chatu můžeš pod přezdívkou i bez účtu. **Registrace (Slowrider)** je dobrovolná: přidá správu profilu včetně změny přezdívky a statistiky uložené k účtu, které ti zůstanou i na novém telefonu. Co se ukládá, popisujeme níže v části „Chat posluchačů a účet“. Neshromažďujeme reklamní ID ani identifikátory zařízení od Applu nebo Googlu a aplikace nikoho nesleduje napříč jinými appkami nebo weby.

Bez účtu aplikace používá nanejvýš dvě **náhodná anonymní ID**, která spolu nejsou nijak propojená: jedno pro statistiky poslechu a druhé pro anonymní měření používání, jen pokud s ním souhlasíš (viz níže). Žádné z nich nevzniká z tvého jména, e-mailu, telefonu ani z identifikátoru zařízení a nelze z nich tebe jako osobu odvodit. Když se přihlásíš, stane se z ID pro statistiky poslechu tvůj účet (viz níže), aby ti statistiky zůstaly.

## Jaké údaje aplikace zpracovává

**Uloženo pouze v telefonu (nikam se neodesílá):**
- Nastavení aplikace (jazyk, automatické přehrávání, statistiky, upozornění na novinky), tvoje volba u anonymního měření a seznam pořadů, na jejichž začátek chceš upozornit — vše zůstává lokálně v telefonu a smaže se odinstalováním aplikace.
- **Upozornění na začátek pořadů** naplánuje přímo tvůj telefon (místní oznámení systému). Nikam se neodesílá, které pořady sleduješ, a nepoužíváme k tomu žádnou službu pro push notifikace.

**Statistiky poslechu (zapnuté ve výchozím stavu, lze vypnout):**
- Aplikace měří, **kolik sekund rádio v appce skutečně hraje** — za každý kalendářní den (podle času v tvém telefonu) a za každý pořad zvlášť. Měří se jen přehrávání, ne to, co se na obrazovce prohlížíš.
- K tomu se na server odesílá **náhodné anonymní ID** (vytvoří se při prvním delším poslechu a uloží se do zabezpečeného úložiště klíčů v telefonu, takže přežije přeinstalaci appky) a **verze appky**. Neodesíláme přesné časy jednotlivých poslechů ani model zařízení. Do databáze se statistikami se IP adresa neukládá; jako při každé komunikaci přes internet ji ale po omezenou dobu vidí provozní logy poskytovatele služby (Supabase), a to jen pro zajištění provozu a bezpečnosti.
- Z těchto údajů appka ukazuje **tvoje vlastní statistiky** (čas dnes, celkem, poslech po dnech a po pořadech), **tvoje pořadí** mezi posluchači appky a **celkový čas poslechu všech posluchačů**. Ostatním posluchačům se nezobrazuje nic, co by tě identifikovalo — vidí jen souhrnná čísla a své vlastní pořadí.
- Tvoje vlastní statistiky vidíš v appce hned. Žebříček a celkový čas všech posluchačů se zobrazí, až bude v aplikaci dostatek posluchačů; měření ale probíhá od začátku.
- **Právní základ:** oprávněný zájem provozovatele rádia znát poslechovost a nabídnout posluchačům statistiky (čl. 6 odst. 1 písm. f) GDPR).
- **Doba uchování:** do smazání — kdykoli v appce (Menu ▸ Nastavení ▸ Smazat moje statistiky), nebo automaticky po 24 měsících, kdy appku nepoužiješ.
- **Co po smazání zůstane:** když statistiky smažeš ručně, zmizí úplně, včetně tvého podílu na celkovém čase všech posluchačů. Při automatickém smazání po 24 měsících nepoužívání odstraníme celý tvůj záznam a ze žebříčku zmizíš; jen **celkový počet odposlouchaných sekund** se přičte do jednoho anonymního souhrnného čísla, aby celkový čas posluchačů neklesal. Toto číslo neobsahuje žádné ID ani jiný údaj, podle kterého by šlo kohokoli určit.
- **Vypnutí:** v Menu ▸ Nastavení ▸ Statistiky poslechu. Po vypnutí se nic neměří ani neodesílá; už uložené údaje zůstanou, dokud je nesmažeš.
- **Po přihlášení** zůstanou statistiky u tvého účtu: anonymní ID pro statistiky se při prvním přihlášení změní na tvůj účet, takže o naměřený čas nepřijdeš. Ostatním posluchačům se ani pak nezobrazuje nic, co by tě identifikovalo. Když se odhlásíš, začne se v telefonu počítat znovu pod novým anonymním ID.

**Souhrnné přehledy poslechovosti (z údajů statistik poslechu):**
- Ze stejných údajů (anonymní ID, sekundy poslechu po dnech a pořadech) sestavujeme pro rádio **souhrnné přehledy**: kolik posluchačů appku používá denně, týdně a měsíčně, kolik průměrně a celkem poslouchají, jak často se vracejí (příležitostní, pravidelní a věrní posluchači) a které pořady se poslouchají nejvíc.
- Přehledy obsahují jen součty a průměry, nikdy údaje o jednom konkrétním posluchači. Nejsou veřejné a nepředáváme je třetím stranám v podobě, podle které by šlo kohokoli určit.
- Právní základ, doba uchování i vypnutí jsou stejné jako u statistik poslechu výše: kdo statistiky vypne nebo smaže, do dalších přehledů se nezapočítá.

**Chat posluchačů a účet (jen pokud píšeš nebo se zaregistruješ):**
- **Psaní bez účtu:** při první zprávě si zvolíš přezdívku. Uloží se k náhodnému anonymnímu ID v telefonu (tomu, které slouží statistikám poslechu), spolu s tvými zprávami. Přezdívku pak změníš jen s registrací; registrace převede anonymní ID na účet, takže přezdívka, zprávy i statistiky zůstanou.
- **Čtení chatu** je bez účtu. Appka k tomu stahuje zprávy posledních 7 dní a při otevřené appce přijímá nové; nic o tobě se přitom neodesílá.
- **Přihlášení:** přes Apple, Google nebo e-mail s jednorázovým kódem. Ukládáme e-mail (u přihlášení přes Apple můžeš použít skrytý e-mail, který Apple přeposílá), identifikátor účtu u Applu či Googlu, způsob přihlášení a čas posledního přihlášení. Heslo nikde nevzniká. Přihlašovací kód ti posíláme e-mailem přes službu Resend. Při přihlášení vidí poskytovatel Supabase v bezpečnostních záznamech IP adresu a typ aplikace, a to jen pro zajištění provozu a ochranu účtů.
- **Profil v chatu:** přezdívka (u registrovaných měnit jde jednou za 24 hodin), datum registrace („Jsi součástí Slowriders od …“), počet tvých zpráv v chatu a odeslaných hlasových vzkazů (pro přehled „Tvůj Slowride“ v Profilu), u moderátorů vazba na jméno z programu rádia a u správců jejich role.
- **Zprávy:** text zprávy, čas, pořad, během kterého jsi psal(a), a tvoje přezdívka. **Zprávy jsou veřejné pro všechny uživatele aplikace**, i nepřihlášené — nepiš do nich nic, co nechceš sdílet.
- **Moderace a bezpečnost:** když zprávu nahlásíš, uložíme, kdo a kterou zprávu nahlásil. Moderátoři pořadů a správci chatu mohou zprávy mazat a psaní dočasně pozastavit nebo zablokovat; ukládáme, kdo to udělal, u které zprávy a do kdy. Text smazané zprávy držíme 1 den, aby šlo smazání vrátit. Seznam lidí, jejichž zprávy sis skryl(a), vidíš jen ty.
- **Ochrana proti spamu:** server počítá, kolik zpráv jsi poslal(a) za posledních 30 sekund a za hodinu, a nadměrné posílání odmítne. Odmítne také stejnou zprávu poslanou znovu do minuty a odkazy na weby od těch, kdo píšou bez účtu. Ke kontrole používá jen tvoje zprávy v chatu, nic dalšího neukládá.
- **Právní základ:** plnění smlouvy, tedy poskytnutí služby chatu, o kterou sis řekl(a) tím, že začneš psát nebo se zaregistruješ (čl. 6 odst. 1 písm. b) GDPR); moderace, nahlášení a ochrana proti spamu z oprávněného zájmu na bezpečném chatu (čl. 6 odst. 1 písm. f) GDPR).
- **Doba uchování:** zprávy 90 dní (v appce se zobrazuje posledních 7 dní); záznamy o ztlumení 30 dní po jeho konci; nahlášení se smažou spolu se zprávou. Účet a profil do doby, než účet nebo údaje smažeš.
- **Archiv a statistiky chatu:** po 90 dnech zprávu z chatu smažeme a její text si ponecháme v interním archivu **bez vazby na účet, ID i přezdívku** (zůstane jen text, čas, pořad a to, jestli psal posluchač, nebo moderátor). Archiv a denní souhrnná čísla (počty zpráv, pisatelů, pořady, kde se nejvíc píše) slouží jen rádiu k analýzám, nejsou veřejné a nepředáváme je dál. Text zprávy může sám obsahovat osobní údaje, které do něj autor napsal, proto do zpráv nepiš nic, co nechceš sdílet. **Právní základ:** oprávněný zájem rádia porozumět, jak se chat používá (čl. 6 odst. 1 písm. f) GDPR).
- **Smazání účtu:** kdykoli v appce (Profil ▸ Smazat účet, bez registrace Profil ▸ Smazat moje údaje). Smaže se účet, e-mail, přezdívka, statistiky poslechu, seznam skrytých uživatelů i tvoje nahlášení. Tvoje už odeslané zprávy zůstanou v chatu do konce 90denní lhůty bez přezdívky, jako „Smazaný účet“, aby konverzace dávala smysl.

**Anonymní měření používání (jen se souhlasem, ve výchozím stavu vypnuté):**
- Po několika spuštěních se appka jednou zeptá, jestli smí anonymně měřit, **které funkce používáš**. Dokud neklepneš na „Povolit“, nic se neměří ani neodesílá. Volbu můžeš kdykoli změnit v Menu ▸ Nastavení ▸ Anonymní měření používání.
- Co se měří: spuštění appky, které obrazovky otevřeš, spuštění a zastavení přehrávání (jak dlouho hrálo, zaokrouhleno, proč skončilo, kam zvuk hraje, tedy reproduktor, sluchátka nebo auto, a v jaké kvalitě), chyby přehrávání, nastavení časovače, zapnutí upozornění na pořad a otevření takového upozornění, přepnutí jazyka, klepnutí na odkazy (Spotify, sociální sítě, platformy podpory), to, jestli se podařilo odeslat vzkaz nebo zpětnou vazbu, a u chatu otevření chatu, odeslání zprávy (jen jestli šlo o text nebo emoji, ne obsah), zobrazení nabídky přihlášení, nahlášení či skrytí a akce moderátorů (bez toho, koho se týkaly). Ke každé události se přidá jazyk appky, verze appky a systému, typ zařízení (telefon/tablet, ne přesný model), časové pásmo a typ připojení (Wi-Fi/mobilní data).
- Co se neměří: žádný text, který napíšeš, žádné přezdívky ani kdo komu v chatu psal, žádná nahrávka, názvy skladeb, poloha, reklamní ID, kontakty ani nic, co by vedlo k tvé osobě. Nesledujeme klepání po obrazovce ani nenahráváme obrazovku.
- Události se ukládají pod **samostatným náhodným ID** (jiným než u statistik poslechu). Zpracovatelem je **PostHog** (PostHog Inc.) s daty uloženými v **EU (Frankfurt)**. IP adresu PostHog podle našeho nastavení neukládá.
- **Právní základ:** tvůj souhlas (čl. 6 odst. 1 písm. a) GDPR a § 89 odst. 3 zákona o elektronických komunikacích). Souhlas můžeš kdykoli odvolat v Nastavení; dosavadní zpracování tím nepřestává být zákonné.
- **Doba uchování:** nejdéle 12 měsíců, pak se události mažou.
- **Po odvolání souhlasu** appka přestane cokoli odesílat a zahodí své analytické ID; pokud souhlas znovu udělíš, vznikne nové ID, které se se starým nedá spojit.

**Odesíláno na vyžádání uživatele:**
- **Zpětná vazba** — pokud v appce napíšeš zprávu vývojáři, spolu s textem se odešle i základní technický přehled (verze appky, verze systému, model zařízení a jazyk aplikace), aby šlo případnou chybu skutečně dohledat. Nic z toho neobsahuje jméno, e-mail ani jiný osobní identifikátor, pokud ho sám nenapíšeš do textu zprávy.
- **Hlasový vzkaz** — pokud si v appce nahraješ a odešleš hlasovou zprávu pro rádio, nahrávka se odešle na e-mail rádia za účelem případného odvysílání.
- **Právní základ:** tvůj souhlas, který dáváš tím, že zprávu nebo vzkaz sám odešleš (čl. 6 odst. 1 písm. a) GDPR). **Doba uchování:** zprávy a nahrávky mažeme, jakmile je přestaneme potřebovat, nejpozději po 12 měsících; nahrávka, která zazní ve vysílání, se může stát součástí archivu pořadu.

Obojí se odesílá přes zabezpečené API a doručuje e-mailem přes službu [Resend](https://resend.com) — zprávy nejsou nikde veřejně publikovány ani sdíleny s třetími stranami mimo doručení e-mailu. Jako ochranu proti zneužití (hromadnému rozesílání) si server po dobu 24 hodin pamatuje jen jednosměrný otisk (hash) IP adresy odesílatele a počet odeslaných zpráv; pak se záznam smaže.

## Použité služby třetích stran

- **Supabase** — databáze, přihlašování a serverová logika appky (historie přehraných skladeb, statistiky poslechu, účty a chat). Bez účtu zpracovává jen anonymní ID a sečtené sekundy poslechu; s účtem navíc e-mail, přezdívku a zprávy popsané výše. Data jsou uložena ve **Spojeném království (Londýn, region AWS eu-west-2)**. Spojené království má od Evropské komise rozhodnutí o odpovídající ochraně osobních údajů, takže přenos dat z EU je v souladu s GDPR bez dalších záruk.
- **PostHog** (PostHog Inc., data v EU, Frankfurt) — anonymní měření používání, jen pokud s ním souhlasíš (viz výše). Zpracovává pouze události popsané výše pod náhodným ID, bez IP adresy, jména a e-mailu.
- **Resend** — doručení e-mailů: zpětná vazba a hlasové vzkazy na adresu rádia a přihlašovací kódy na tvůj e-mail.
- **Přihlášení přes Apple a Google** — když zvolíš „Pokračovat s Apple“ nebo „Pokračovat s Google“, přihlášení proběhne u nich a appka od nich dostane jen identifikátor účtu a e-mail (u Applu případně skrytý). Další zpracování se řídí zásadami Applu a Googlu.
- **Apple iTunes Search API** — vyhledání obalu alba a krátké ukázky skladby podle názvu/interpreta; appka posílá jen text názvu a interpreta, nic osobního.
- **slowdownradijo.cz** — appka čte veřejný obsah webu (rubrika Novinky) přes standardní WordPress rozhraní.
- **Spotify** — když klepneš na právě hrající skladbu, otevře se vyhledávání této skladby na Spotify (v aplikaci Spotify nebo v prohlížeči). Spotify se tak dozví jen název skladby a interpreta; další zpracování už se řídí zásadami Spotify. Bez klepnutí appka se Spotify nekomunikuje.
- **Platformy podpory (Herohero, Patreon, Forendors)** a **sociální sítě** — appka na ně jen odkazuje. Pokud odkaz otevřeš, řídí se zpracování údajů zásadami daného webu.

## Mikrofon

Aplikace požaduje přístup k mikrofonu výhradně pro nahrání hlasového vzkazu v sekci "Vzkaz" — pouze když to sám aktivně spustíš, nikdy na pozadí.

## Sledování a reklama

Aplikace neobsahuje žádné reklamní SDK, nezobrazuje reklamy a nesleduje chování uživatele pro marketingové účely ani napříč jinými appkami a weby. Jediný analytický nástroj třetí strany (PostHog) běží jen se souhlasem a slouží ke zlepšování appky. Anonymní statistiky poslechu slouží jen k zobrazení tvých statistik v appce a k souhrnnému přehledu poslechovosti rádia; nepředáváme je třetím stranám a nepoužíváme je k reklamě.

## Tvoje práva

Můžeš kdykoli **vypnout měření**, **smazat své statistiky** a **odvolat souhlas s anonymním měřením používání** přímo v appce (Menu ▸ Nastavení), a pokud máš účet, **změnit přezdívku** a **smazat účet** (Profil). Bez účtu jsou statistiky vázané jen na anonymní ID v tvém telefonu, takže je nedokážeme spárovat s konkrétní osobou; využít další práva (přístup, výmaz) jde právě přes appku. S účtem nám můžeš napsat o kopii svých údajů (přezdívka, e-mail, zprávy) a ověříme to přes e-mail účtu. S dotazy nebo stížností se na nás můžeš obrátit na info@slowdownradijo.cz; máš také právo podat stížnost u Úřadu pro ochranu osobních údajů (uoou.cz).

## Děti

Aplikace není cílená na děti a vědomě neshromažďuje údaje od dětí mladších 13 let. Chat posluchačů je určený lidem od 13 let.

## Změny těchto zásad

Tento dokument může být čas od času aktualizován. Aktuální verze je vždy dostupná na https://slowdownradijo.cz/ochrana-osobnich-udaju/.

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

# Google Play

Co se vyplňuje v Play Console pro Slow Down Rádijo (Android). Stejné
pravidlo jako u `docs/app-store.md`: funkce zmíněná v obchodě musí být
ve verzi, která se vydává. Limity: název 30 znaků, krátký popis 80,
úplný popis 4000.

Grafika je v `android/store/`:

| Soubor | Kam | Vznik |
|---|---|---|
| `icon-512.png` | Ikona aplikace (512 × 512) | `python3 tools/android/store_graphics.py` |
| `feature-graphic.png` | Úvodní grafika (1024 × 500) | totéž |
| `play/cs/*.png`, `play/en/*.png` | **Snímky do obchodu (od 1.3):** text nahoře, obrazovka bez telefonu, mraky; 1080 × 1920 (Play chce přesně 9 : 16), v pořadí podle čísla | `StoreScreenshotTest` (`-Proborazzi.test.record=true`) → `screenshots/`, pak `python3 tools/appstore/frame.py <obrazovky> <výstup> clouds --play --bare` |
| `screenshots/cs/*.png`, `screenshots/en/*.png` | Holé obrazovky z testu (podklad pro `play/`) | `StoreScreenshotTest` |

## Nastavení obchodu (Zvýšení počtu uživatelů → Nastavení obchodu)

| Pole | Hodnota |
|---|---|
| Kategorie | Aplikace → Hudba a zvuk |
| Štítky | Rádio, Hudba, Streamování hudby (co Play nabídne) |
| E-mail | info@slowdownradijo.cz (povinný, uvidí ho uživatelé) |
| Telefon | nevyplněno |
| Externí marketing | zapnutý |
| Web | https://slowdownradijo.cz |

## Hlavní záznam v obchodu – čeština (výchozí)

**Název aplikace**

Slow Down Rádijo

**Krátký popis**

Živé vysílání Slow Down Rádija: hip hop, soul, jazz a funk vybraný lidmi.

**Úplný popis**

```
Slow Down Rádijo v kapse. Živé vysílání rádia, které hraje hip hop, soul, funk, jazz, afrobeat i elektroniku – a hlavně věci, které jinde neuslyšíš. Ruční kurátorský výběr hudby namísto automatických algoritmů.

CO APPKA UMÍ
• Živé vysílání na jedno klepnutí – i na pozadí, ze zamčené obrazovky, přes Bluetooth a v autě s Android Auto
• Chat posluchačů: piš si s ostatními i s moderátory během vysílání – stačí přezdívka, bez registrace
• Co se právě vysílá: pořad, moderátor a skladba, kterou jedním klepnutím najdeš na Spotify
• Skladby, které hrály před chvílí – stačí přejet prstem do strany
• Program na celý týden s popisy pořadů a připomínkou, když začíná tvůj oblíbený
• Tvoje statistiky poslechu: dnešek, týden, celkový čas, oblíbené pořady a místo mezi posluchači
• Profil Slowridera: s volitelným účtem si změníš přezdívku a statistiky ti zůstanou i na novém telefonu
• Soutěže o ceny od rádia – odpověz na otázku přímo v appce (pro Slowridery s účtem)
• Hlasový vzkaz do rádia – nahraj pozdrav nebo přání a pošli ho moderátorům
• Kvalita zvuku podle připojení: na Wi-Fi naplno, na datech úsporně
• Časovač vypnutí, novinky z rádia a widget na plochu
• Česky i anglicky

BEZ REKLAM, ÚČET JEN KDYŽ CHCEŠ
Appku používáš bez reklam a bez registrace – i do chatu můžeš psát jen s přezdívkou. Účet Slowridera je dobrovolný. Statistiky poslechu jsou anonymní a můžeš je kdykoli vypnout i smazat. Měření používání appky se zapne jen s tvým souhlasem.

Zpomal se Slow Down Rádijem.
Tohle algoritmus neumí.
No music. No life.
```

## Hlavní záznam v obchodu – angličtina (přidat překlad: en-US)

**App name**

Slow Down Rádijo

**Short description**

Slow Down Rádijo live: hip hop, soul, jazz and funk, hand-picked by people.

**Full description**

```
Slow Down Rádijo in your pocket. The live stream of a radio station playing hip hop, soul, funk, jazz, Afrobeat and electronica – and above all, music you won't hear anywhere else. Hand-picked by people, not by algorithms.

WHAT IT DOES
• The live stream in one tap – in the background, from the lock screen, over Bluetooth, and in the car with Android Auto
• Listeners' chat: talk with other listeners and the hosts during the show – just pick a nickname, no sign-up
• What's on air: the show, the host and the song, which you can find on Spotify in one tap
• The songs that played a moment ago – just swipe sideways
• The whole week's schedule with show descriptions and a reminder when your favourite starts
• Your listening stats: today, this week, all time, your favourite shows and where you are among listeners
• Slowrider profile: with an optional account you can change your nickname and keep your stats on a new phone
• Contests with prizes from the station – answer the question right in the app (for Slowriders with an account)
• Voice messages to the station – record a shout-out or a request and send it to the hosts
• Sound quality to match your connection: full quality on Wi-Fi, data-saving on mobile
• A sleep timer, news from the station and a home screen widget
• In Czech and English

NO ADS, AN ACCOUNT ONLY IF YOU WANT ONE
No ads and no sign-up – you can even write in the chat with just a nickname. A Slowrider account is optional. Listening stats are anonymous, and you can turn them off and delete them at any time. Usage measurement only starts with your consent.

Slow down with Slow Down Rádijo.
No algorithm can do this.
No music. No life.
```

## Poznámky k verzi

Limit 500 znaků na jazyk (kratší než v App Store).

**1.4 – čeština**

```
• Zimní vzhled: od první adventní neděle do Tří králů v appce sněží a slunce v logu se mění ve vánoční ozdobu. Vypnout jde v Nastavení.
• Zimní ikona na sezónu.
• Budík s rádiem: ráno tě vzbudí živé vysílání.
• Týdenní a měsíční žebříček poslechu a dny v řadě.
```

**1.4 – English**

```
• Winter look: from the first Sunday of Advent to Epiphany it snows in the app and the sun in the logo turns into a Christmas bauble. You can turn it off in Settings.
• A winter icon for the season.
• Radio alarm: wake up to the live broadcast.
• Weekly and monthly listening leaderboards, and your days in a row.
```

**1.3 – čeština**

```
• Chat posluchačů: piš si s ostatními i s moderátory. Stačí přezdívka.
• Soutěže o ceny přímo v appce (pro Slowridery s účtem).
• Profil Slowridera: přezdívka, tvoje čísla a oblíbené pořady. S účtem ti statistiky zůstanou.
• Nové statistiky: dnešek, týden a místo mezi posluchači.
• Lepší zvuk: na Wi-Fi naplno, na datech úsporně.
• V autě začne rádio hrát hned po otevření.
```

**1.3 – English**

```
• Listeners' chat: talk with other listeners and the hosts. Just pick a nickname.
• Contests with prizes right in the app (for Slowriders with an account).
• Slowrider profile: your nickname, numbers and favourite shows. With an account, your stats stay.
• New stats: today, this week and where you are among listeners.
• Better sound: full quality on Wi-Fi, data-saving on mobile.
• In the car, the radio starts as soon as you open the app.
```

**1.2 – čeština**

```
První verze Slow Down Rádija pro Android: živé vysílání, program s připomínkami, časovač vypnutí, statistiky poslechu, hlasový vzkaz do rádia, widget a Android Auto.
```

**1.2 – English**

```
The first Slow Down Rádijo for Android: the live stream, the schedule with reminders, a sleep timer, listening stats, voice messages to the station, a widget and Android Auto.
```


## Obsah aplikace (Zásady → Obsah aplikace)

| Položka | Odpověď |
|---|---|
| Zásady ochrany soukromí | https://slowdownradijo.cz/ochrana-osobnich-udaju/ |
| Přihlašovací údaje (dříve Přístup k aplikaci) | Od 1.3: chat funguje i bez účtu (přezdívka s první zprávou); přihlášení (Google, Apple nebo e-mail s kódem) je potřeba jen pro změnu přezdívky, profil Slowridera a soutěže (1.3). Odpověď **Ano** (část je omezená). Recenzenti si nesmí zakládat účty ani používat vlastní, proto je zadaný samostatný Google účet jen pro recenzenty (e-mail a heslo jen v Play Console a ve správci hesel, bez dvoufázového ověření) s pokyny „Profile → Sign in → Continue with Google“; přepínač testování na zařízeních Googlu zapnutý. Když během kontroly žádná soutěž neběží, karta soutěže se nezobrazí |
| Reklamy | Aplikace neobsahuje reklamy |
| Cílová skupina | 13–15, 16–17, 18 a více (ne pod 13: to by zapnulo pravidla pro rodiny a děti) |
| Zpravodajská aplikace | Ne |
| Státní aplikace | Ne |
| Status obchodníka | Ano, vztahuje se (Slow Down Radio s.r.o.); smluvní podmínky nevyplněné |
| Reklamní ID | Ne (aplikace nemá oprávnění AD_ID) |
| Finanční funkce | Žádné |
| Zdraví | Žádné zdravotní funkce |
| Oprávnění používat služby v popředí | Jen **Přehrávání mediálního obsahu** (`FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `PlaybackService`). Povinné video: 58 s z emulátoru s buildem 41 (rádio hraje, notifikace s přehrávačem, plocha), neveřejné na YouTube: https://www.youtube.com/watch?v=csGbULUwVnc. Vyplněno 23. 11. 2026 |

### Hodnocení obsahu (dotazník IARC)

Vyplněno 12. 11. 2026. Výsledek: IARC 12+, PEGI „Dohled rodičů“, ESRB Teen,
USK 12, ClassInd 14.

- Kategorie: **Všechny ostatní typy aplikací**.
- Stažená aplikace (hodnocený obsah v balíčku): **Ne**.
- Sdílení uživatelského obsahu: **Ne** do 1.2. **Od 1.3 Ano**: veřejný chat posluchačů (text), s moderací, nahlášením a blokací. Podotázky (23. 11. 2026): primární zdroj obsahu Ne, nahota Ne, násilí Ne, blokace Ano, nahlášení Ano, moderování Ano, jen pozvaní přátelé Ne. Soutěže o věcné ceny nejsou hazard, digitální nákup ani peněžní odměna (u dárkových karet nebo poukázek jako výhry vyplnit znovu).
- Online obsah: **Ano** (živé vysílání, novinky a program z webu).
- Násilí: **Ne**. Sexualita: **Ne**.
- Jazyk: **Ano**. Rádio může pustit necenzurované verze skladeb. Hlavní zaměření: Ne; mírné klení: Ano; mírné nadávky: Ano; diskriminační mluva: Ne; sexuální nadávky: Ano (necenzurovaný rap).
- Drogy (sekce se jmenuje „Léky na předpis“): **Ano**, odkazy v textech písní (hlavní zaměření Ne, vyobrazení Ne).
- Výsledek 23. 11. 2026 (1.3) beze změny: IARC 12+, PEGI Dohled rodičů, ESRB Teen, USK 12, ClassInd 14, vše s „Interakce uživatelů“.
- Propagace produktů s věkovým omezením: **Ne**.
- Různé (poloha, digitální nákupy, odměny, prohlížeč, zpravodajství): vše **Ne**.

### Bezpečnost údajů

Odpovídá štítku soukromí v App Store (`docs/app-store.md`) a zásadám ochrany soukromí.

- Shromažďuje aplikace data? **Ano**.
- Jsou všechna data při přenosu šifrovaná? **Ano** (vše jde přes HTTPS).
- Metody vytvoření účtu (od 1.3): **Uživatelské jméno a jiné ověřování** (e-mail s jednorázovým kódem) a **OAuth** (Google, Apple). Účet je volitelný: pro změnu přezdívky, profil Slowridera a soutěže.
- Mohou uživatelé požádat o smazání? **Ano**: účet v aplikaci (Profil → Smazat účet), statistiky v Menu → Nastavení → Smazat moje statistiky; URL pro žádost o smazání: https://slowdownradijo.cz/ochrana-osobnich-udaju/.
- U všech typů: jen shromažďováno (ne sdíleno), nezpracovává se dočasně, uživatelé si mohou zvolit.
- Sdílení s třetími stranami: **Ne**. Supabase, PostHog a Resend jsou zpracovatelé (poskytovatelé služeb), to se podle Googlu za sdílení nepočítá.

| Typ dat (Play Console) | Co to je | Účel | Povinné? |
|---|---|---|---|
| Aktivita v aplikaci → Interakce s aplikací | Sekundy poslechu po dnech a pořadech; se souhlasem i to, které funkce lidé používají | Funkce aplikace, Analytika | Volitelné (statistiky jdou vypnout, analytika jen se souhlasem) |
| ID zařízení nebo jiná ID | Náhodné anonymní ID pro statistiky poslechu; náhodné ID analytiky (jen se souhlasem) | Funkce aplikace, Analytika | Volitelné |
| Osobní údaje → E-mailová adresa | E-mail účtu (1.3, volitelný účet) | Funkce aplikace, Správa účtu | Volitelné |
| Osobní údaje → Telefonní číslo | Telefon, který Slowrider zadá při přihlášce do soutěže, jen kvůli kontaktu s výhercem; smaže se 30 dní po losování, nejpozději 90 dní po konci soutěže (1.3) | Funkce aplikace | Volitelné |
| Osobní údaje → ID uživatele | Účet a přezdívka v chatu | Funkce aplikace, Správa účtu | Volitelné |
| Zvuk → Hlasové nebo zvukové nahrávky | Hlasové vzkazy, které posluchač nahraje a odešle | Funkce aplikace | Volitelné |
| Zprávy → Jiné zprávy v aplikaci | Text zpětné vazby; zprávy v chatu posluchačů (1.3, veřejné v aplikaci) | Funkce aplikace | Volitelné |
| Informace o aplikaci a výkonu → Jiné údaje o výkonu aplikace | Verze appky a Androidu a model telefonu, poslané se zpětnou vazbou; verze appky a Androidu u událostí analytiky (jen se souhlasem) | Funkce aplikace, Analytika | Volitelné |

Neshromažďuje se: jméno, poloha, kontakty, fotky,
platby, historie prohlížení, zdravotní ani finanční údaje, záznamy o
pádech, diagnostika. PostHog má zapnuté anonymizování IP adres, takže
se nezjišťuje ani přibližná poloha.

## Vydání

1. **Interní testování**: `app-release.aab` z běhu „Android“ v GitHub Actions (artefakt `slowdownradijo-release`). Testeři přes odkaz pro připojení.
2. **Produkce**: vyplnit vše výše, pak Produkce → Vytvořit novou verzi → stejný `.aab` → Zahájit zavádění. Účet organizace nemusí projít 14denním uzavřeným testem s 12 testery.
3. **Další verze**: každý build v CI má vyšší versionCode (číslo běhu), takže stačí nahrát nový `.aab`.

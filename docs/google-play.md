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
| `screenshots/cs/*.png`, `screenshots/en/*.png` | Snímky obrazovky telefonu (1080 × 1920, Play chce přesně 9 : 16), v pořadí podle čísla | `StoreScreenshotTest` (`-Proborazzi.test.record=true`), pak `store_graphics.py` |

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
• Co se právě vysílá: pořad, moderátor a skladba, kterou jedním klepnutím najdeš na Spotify
• Skladby, které hrály před chvílí – stačí přejet prstem do strany
• Program na celý týden s popisy pořadů a připomínkou, když začíná tvůj oblíbený
• Časovač vypnutí, když s rádiem usínáš
• Tvoje statistiky poslechu: kolik času jsi s rádiem strávil, tvoje nejposlouchanější pořady a tvoje místo mezi posluchači
• Hlasový vzkaz do rádia – nahraj pozdrav nebo přání a pošli ho moderátorům
• Novinky z rádia a widget na plochu s tím, co se právě vysílá
• Česky i anglicky

BEZ ÚČTU A BEZ REKLAM
Appku používáš bez registrace a bez reklam. Statistiky poslechu jsou anonymní a můžeš je kdykoli vypnout i smazat. Měření používání appky se zapne jen s tvým souhlasem.

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
• The live stream in one tap – in the background, from the lock screen, over Bluetooth and in the car with Android Auto
• What's on air: the show, the host and the song, which you can find on Spotify in one tap
• The songs that played a moment ago – just swipe sideways
• The whole week's schedule with show descriptions and a reminder when your favourite starts
• A sleep timer for falling asleep to the radio
• Your listening stats: how much time you've spent with the station, your most-listened shows and where you rank among listeners
• Voice messages to the station – record a shout-out or a request and send it to the hosts
• News from the station and a home screen widget showing what's on air
• In Czech and English

NO ACCOUNT, NO ADS
No sign-up and no ads. Listening stats are anonymous, and you can turn them off and delete them at any time. Usage measurement only starts with your consent.

Slow down with Slow Down Rádijo.
No algorithm can do this.
No music. No life.
```

## Poznámky k verzi

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
| Přihlašovací údaje (dříve Přístup k aplikaci) | Ne, žádná část aplikace není omezená |
| Reklamy | Aplikace neobsahuje reklamy |
| Cílová skupina | 13–15, 16–17, 18 a více (ne pod 13: to by zapnulo pravidla pro rodiny a děti) |
| Zpravodajská aplikace | Ne |
| Státní aplikace | Ne |
| Status obchodníka | Ano, vztahuje se (Slow Down Radio s.r.o.); smluvní podmínky nevyplněné |
| Reklamní ID | Ne (aplikace nemá oprávnění AD_ID) |
| Finanční funkce | Žádné |
| Zdraví | Žádné zdravotní funkce |
| Služby na popředí (pokud se zeptá) | Přehrávání médií: živé vysílání rádia hraje na pozadí a ovládá se z notifikace a zamčené obrazovky. Spouští ho uživatel. |

### Hodnocení obsahu (dotazník IARC)

Vyplněno 12. 11. 2026. Výsledek: IARC 12+, PEGI „Dohled rodičů“, ESRB Teen,
USK 12, ClassInd 14.

- Kategorie: **Všechny ostatní typy aplikací**.
- Stažená aplikace (hodnocený obsah v balíčku): **Ne**.
- Sdílení uživatelského obsahu: **Ne**. Vzkazy a zpětná vazba jdou soukromě rádiu.
- Online obsah: **Ano** (živé vysílání, novinky a program z webu).
- Násilí: **Ne**. Sexualita: **Ne**.
- Jazyk: **Ano**. Rádio může pustit necenzurované verze skladeb. Hlavní zaměření: Ne; mírné klení: Ano; mírné nadávky: Ano; diskriminační mluva: Ne; sexuální nadávky: podle odpovědi v Play Console.
- Drogy: **Ano**, odkazy v textech písní (vyobrazení: Ne).
- Propagace produktů s věkovým omezením: **Ne**.
- Různé (poloha, digitální nákupy, odměny, prohlížeč, zpravodajství): vše **Ne**.

### Bezpečnost údajů

Odpovídá štítku soukromí v App Store (`docs/app-store.md`) a zásadám ochrany soukromí.

- Shromažďuje aplikace data? **Ano**.
- Jsou všechna data při přenosu šifrovaná? **Ano** (vše jde přes HTTPS).
- Metody vytvoření účtu: **Aplikace uživatelům vytvoření účtu neumožňuje**.
- Mohou uživatelé požádat o smazání? **Ano**, URL: https://slowdownradijo.cz/ochrana-osobnich-udaju/ (Menu → Nastavení → Smazat moje statistiky; ostatní přes e-mail rádia).
- U všech typů: jen shromažďováno (ne sdíleno), nezpracovává se dočasně, uživatelé si mohou zvolit.
- Sdílení s třetími stranami: **Ne**. Supabase, PostHog a Resend jsou zpracovatelé (poskytovatelé služeb), to se podle Googlu za sdílení nepočítá.

| Typ dat (Play Console) | Co to je | Účel | Povinné? |
|---|---|---|---|
| Aktivita v aplikaci → Interakce s aplikací | Sekundy poslechu po dnech a pořadech; se souhlasem i to, které funkce lidé používají | Funkce aplikace, Analytika | Volitelné (statistiky jdou vypnout, analytika jen se souhlasem) |
| ID zařízení nebo jiná ID | Náhodné anonymní ID pro statistiky poslechu; náhodné ID analytiky (jen se souhlasem) | Funkce aplikace, Analytika | Volitelné |
| Zvuk → Hlasové nebo zvukové nahrávky | Hlasové vzkazy, které posluchač nahraje a odešle | Funkce aplikace | Volitelné |
| Zprávy → Jiné zprávy v aplikaci | Text zpětné vazby | Funkce aplikace | Volitelné |
| Informace o aplikaci a výkonu → Jiné údaje o výkonu aplikace | Verze appky a Androidu a model telefonu, poslané se zpětnou vazbou; verze appky a Androidu u událostí analytiky (jen se souhlasem) | Funkce aplikace, Analytika | Volitelné |

Neshromažďuje se: jméno, e-mail, telefon, poloha, kontakty, fotky,
platby, historie prohlížení, zdravotní ani finanční údaje, záznamy o
pádech, diagnostika. PostHog má zapnuté anonymizování IP adres, takže
se nezjišťuje ani přibližná poloha.

## Vydání

1. **Interní testování**: `app-release.aab` z běhu „Android“ v GitHub Actions (artefakt `slowdownradijo-release`). Testeři přes odkaz pro připojení.
2. **Produkce**: vyplnit vše výše, pak Produkce → Vytvořit novou verzi → stejný `.aab` → Zahájit zavádění. Účet organizace nemusí projít 14denním uzavřeným testem s 12 testery.
3. **Další verze**: každý build v CI má vyšší versionCode (číslo běhu), takže stačí nahrát nový `.aab`.

# Katalog pořadů a rozvrh – neutrální datový model (návrh)

*Stav: návrh, nic z toho zatím není implementované. Slouží jako společná
„smlouva“ pro iOS i Android.*

## 1. Proč

Dnes:

- **Rozvrh žije ve třech kopiích**: `SlowDownRadijo/Resources/schedule.json`
  (appka), jeho kopie ve widgetu a `backend/supabase/functions/collect-now-playing/schedule.json`.
  Rozcházejí se (už se to jednou stalo).
- **Obrázky pořadů** (17 JPG) se stahují přímo z WordPressu
  `slowdownradijo.cz/wp-content/uploads/…`: jedna velikost pro všechna zařízení,
  nikdo nezaručí, že URL zůstanou, a Android by je musel hlídat zvlášť.
- **Fotky moderátorů** (12) jsou zabudované v appce (`Host*.imageset`), takže
  nová fotka = nová verze appky, a Android by je potřeboval znovu.
- **Texty** (popisky) jsou jen česky a v appce.
- **ID pořadu obsahuje jméno moderátora** (`diggin-time-s-dj-magic`). Když se
  moderátor změní, změní se i ID, a s ním se přeruší statistiky poslechu, které
  podle ID pořadu ukládáme (`listening_daily.show_id`).

Cíl: **jeden zdroj pravdy na serveru, oba klienti čtou totéž, změna obsahu bez
vydání appky.**

## 2. Zásady

1. **Server je zdroj pravdy, klient má jen uloženou kopii** (cache) a zabudovanou
   zálohu pro první spuštění bez internetu.
2. **ID jsou stabilní a nemění se nikdy** (nezávislá na moderátorovi i názvu).
3. **Všechno v jednom JSON** (katalog je malý: ~20 pořadů, ~15 moderátorů).
4. **Neutrální formát**: žádné konvence z iOS (např. číslování dnů od neděle).
5. **Dopředná kompatibilita**: klienti ignorují neznámá pole; zásadní změny
   zvedají `schemaVersion` a `minAppVersion`.
6. **Obsah může upravit i nevývojář** (Table Editor v Supabase), bez nasazování.

## 3. Entity

### `hosts` (moderátoři)
| pole | typ | poznámka |
|---|---|---|
| `id` | text, stabilní | např. `jaro-cossiga` |
| `name` | text | zobrazované jméno |
| `photo` | image set | čtverec, viz sekce 7 |
| `sort` | int | volitelné řazení |

### `shows` (pořady)
| pole | typ | poznámka |
|---|---|---|
| `id` | text, stabilní | např. `diggin-time` (bez moderátora) |
| `title` | text | „Diggin Time“ (bez „s DJ Magič“) |
| `hostIds` | text[] | 0, 1 nebo víc moderátorů |
| `summary` | `{cs, en?}` | max 2 řádky, `en` volitelné (fallback na `cs`) |
| `cover` | image set | viz sekce 7; může chybět (The Golden Era) |
| `kind` | `show` / `rotation` | `rotation` = „The Best of Slow Down“ (výplň bez moderátora) |
| `active` | bool | skrytí bez smazání |
| `legacyIds` | text[] | dřívější ID (pro statistiky a migraci) |

### `scheduleSlots` (týdenní rozvrh)
| pole | typ | poznámka |
|---|---|---|
| `weekday` | 1–7 | **ISO: 1 = pondělí … 7 = neděle** (iOS dnes používá 1 = neděle) |
| `start`, `end` | `"HH:mm"` | `end: "24:00"` místo `"00:00"` pro půlnoc |
| `showId` | text | odkaz na `shows` |

### `scheduleOverrides` (výjimky) – volitelné, až bude potřeba
`date`, `start`, `end`, `showId` (nebo `null` = „bez vysílání“), `note`.
Svátky, speciální vysílání, změny jednorázového charakteru.

### `catalogMeta`
`schemaVersion`, `version` (rostoucí číslo nebo hash obsahu), `updatedAt`,
`timezone` (= `Europe/Prague`), `minAppVersion`.

## 4. Podoba odpovědi (to, co čtou appky)

```json
{
  "schemaVersion": 1,
  "version": "2026-10-06.3",
  "updatedAt": "2026-10-06T19:00:00Z",
  "timezone": "Europe/Prague",
  "hosts": [
    {
      "id": "dj-magic",
      "name": "DJ Magič",
      "photo": {
        "base": "https://<projekt>.supabase.co/storage/v1/object/public/catalog/hosts/dj-magic",
        "widths": [96, 192, 384],
        "format": "webp",
        "placeholderColor": "#2b2347"
      }
    }
  ],
  "shows": [
    {
      "id": "diggin-time",
      "title": "Diggin Time",
      "hostIds": ["dj-magic"],
      "summary": { "cs": "Čas kopat v hudbě – autorská selekce." },
      "cover": {
        "base": "https://<projekt>.supabase.co/storage/v1/object/public/catalog/shows/diggin-time",
        "widths": [480, 960, 1440],
        "format": "webp",
        "placeholderColor": "#1f2a3a"
      },
      "kind": "show",
      "legacyIds": ["diggin-time-s-dj-magic"]
    }
  ],
  "schedule": [
    { "weekday": 2, "start": "09:00", "end": "12:00", "showId": "beat-brunch" }
  ],
  "overrides": []
}
```

URL obrázku se skládá jako `{base}-{width}.{format}` (např. `…/diggin-time-960.webp`).
Klient vybere nejmenší šířku, která pokryje potřebnou velikost × měřítko displeje.

## 5. Pravidla, na kterých záleží

- **Časová zóna rozvrhu je pražská.** Dnes appka počítá „co hraje teď“ podle
  času v telefonu, takže posluchač v jiném pásmu vidí posunutý rozvrh. Katalog
  proto nese `timezone` a klienti rozhodují „co hraje“ v ní. (Statistiky
  „Dnes“ zůstávají podle místního času telefonu, to je záměr.)
- **Zpětná kompatibilita statistik**: dokud nikdo nepoužívá ostrou appku, lze
  zvolit krátká nová ID ještě před vydáním. Staré ID zůstávají v `legacyIds`.
- **Žádná čeština v ID**, jen `a-z0-9-` (shoduje se s kontrolou na serveru).
- **Chybějící obrázek není chyba**: klient ukáže `placeholderColor` (nebo
  značkový zástupný obrázek) a po načtení obrázek odhalí (viz animace „reveal“).

## 6. Doručení a cache

- **Jedno čtení**: Edge Function `catalog` (nebo SQL funkce) složí JSON z tabulek
  a vrátí ho s `ETag` a `Cache-Control: public, max-age=300`.
- **Klient**: při startu a při návratu do popředí (nejvýš jednou za několik
  hodin) zavolá s `If-None-Match`; `304` = nic se nestahuje. Poslední dobrou
  kopii drží v místním úložišti.
- **Záloha v balíčku**: při sestavení se stáhne aktuální katalog a vloží do
  appky (i widgetu), aby první spuštění bez internetu fungovalo.
- **Widget** si katalog čte sám (nebo má vlastní zabudovanou kopii), protože
  nesdílí úložiště s appkou.
- **Sběr skladeb** (`collect-now-playing`) čte rozvrh přímo z tabulek, takže
  kopie `schedule.json` v backendu zmizí.

## 7. Obrázky

**Zdroj**: originály v dobré kvalitě (nejlépe 1440 px na šířku a víc), poměr
stran jednotný (návrh **4 : 3**, odpovídá kartě „nejposlouchanější pořad“ 350×260
a hero fotce; klient ořezává `cover`).

**Zpracování** (jednorázový skript, pak při každém nahrání):
| druh | hlavní rozměry | šířky | formát |
|---|---|---|---|
| `cover` pořadu | 1440 × 1080 | 480, 960, 1440 | WebP (kvalita ~80) |
| `photo` moderátora | 384 × 384 čtverec | 96, 192, 384 | WebP |

WebP umí iOS 14+ i Android. **Uložení**: veřejný bucket `catalog` v Supabase
Storage (CDN). Název souboru `shows/<showId>-<šířka>.webp`.
`placeholderColor` = průměrná barva obrázku (skript ji spočítá).

Dnešní 17 JPG ze slowdownradijo.cz se přenese jednorázově (jsou to vlastní
materiály rádia). Fotky 12 moderátorů se ze zabudovaných `Host*.imageset`
přenesou stejně.

## 8. Kdo upravuje obsah

Tabulky `shows`, `hosts`, `scheduleSlots` se upravují v Supabase **Table Editoru**
(bez kódu); obrázky se nahrají do bucketu. Každá změna zvedne `version`
(automaticky triggerem). Pokud by editace v dashboardu nestačila, později vznikne
malé administrační rozhraní. Data jsou veřejná jen ke čtení, zapisovat smí jen
správce.

## 9. Postup zavedení (po schválení)

| # | Krok | Velikost |
|---|---|---|
| 1 | Tabulky + naplnění z `schedule.json` + převod ID (`legacyIds`) | malá |
| 2 | Bucket a skript na obrázky (17 + 12), `placeholderColor` | střední |
| 3 | Edge Function `catalog` (ETag, cache) | malá |
| 4 | iOS: `CatalogStore` místo `ScheduleStore`, zálohy v balíčku, widget | střední |
| 5 | `collect-now-playing` čte z tabulek, smazat kopii `schedule.json` | malá |
| 6 | Pražský čas pro „co hraje teď“ | malá |
| 7 | Android: stejná smlouva od začátku | – |

## 10. Otevřené otázky

1. **Anglické popisky** pořadů: chcete je (volitelné pole je připravené)?
2. **Víc moderátorů** u jednoho pořadu nebo hosté: stačí `hostIds[]`?
3. **Výjimky v rozvrhu** (svátky, speciály): potřebujete je hned, nebo až později?
4. **Kdo bude obsah upravovat** a stačí mu Table Editor?
5. **Žánry/štítky** pořadů (dřív vypuštěné): počítat s polem `tags`, i když se zatím
   nezobrazují?

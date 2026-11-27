# Zimní vzhled (1.4)

Návrh: Figma „Slow Down Rádijo“ → stránka **Advent ❄︎** (ikona I4, splash S3,
záhlaví A1). Od první adventní neděle do Tří králů (6. 1. včetně), podle
pražského času.

## Co se děje samo podle data

| Co | iOS | Android |
|---|---|---|
| Sněžení v záhlaví (za mrakem, mizí před přehrávačem) a ozdoba na „O“ v logu | ✅ | ✅ |
| Přepínač Nastavení → Zimní vzhled (jen v sezóně; volba platí i do dalších let) | ✅ | ✅ |
| Zimní splash (noc, sněžení, ozdoba na niti) při prvním spuštění dne, ~1,5 s | ✅ | – (Android nemá vlastní splash; systémový ukazuje ikonu aplikace) |
| Přání „Klidné svátky přeje Slow Down Rádijo“ na splashi 24.–26. 12. | ✅ | – |

Logika: `WinterSeason.swift` a `android/.../winter/WinterSeason.kt` (unit
testy v `WinterSeasonTest`). Při „Omezit pohyb“ vločky stojí, v úsporném
režimu nejsou vůbec.

Náhled mimo sezónu (simulátor, iOS):

```
xcrun simctl spawn booted defaults write cz.slowdownradijo.app winterLookPreview -bool YES
xcrun simctl spawn booted defaults write cz.slowdownradijo.app winterLookChristmasPreview -bool YES
```

(`defaults delete cz.slowdownradijo.app winterLookPreview` vrátí normál.)
Android: screenshot testy `home_winter_cs` a `settings_winter_cs`.

## Ikona: měnit jen vydáním

Za běhu ikonu automaticky nepřepínáme: iOS by pokaždé ukázal systémové
hlášení „Změnili jste ikonu…“. Zimní ikona je proto hlavní ikonou verze 1.4
a vrací se v první verzi po Třech králích.

- iOS: `ASSETCATALOG_COMPILER_APPICON_NAME: AppIconWinter` v `project.yml`
  (původní `AppIcon` zůstává v katalogu).
- Android: `android:icon="@mipmap/ic_launcher_winter"` a
  `android:roundIcon="@mipmap/ic_launcher_winter_round"` v `AndroidManifest.xml`
  (původní `ic_launcher*` zůstávají). Generuje je
  `tools/android/icons.py --winter` z `AppIconWinter` a
  `BrandAssets/WinterIcon/foreground-1024.png` (export z Figmy).

## Plán vydání

1. **1.4** poslat ke schválení do ~26. 11. a zvolit ruční vydání
   (App Store: „Manually release this version“; Google Play: řízené
   publikování je zapnuté). Vydat ráno **29. 11. 2026**. Kdo má verzi
   dřív, uvidí jen zimní ikonu; sněžení se zapne samo 29. 11.
2. **Návrat ikony** (1.4.1 nebo 1.5): v `project.yml` zpět `AppIcon`,
   v manifestu zpět `ic_launcher` / `ic_launcher_round`. Poslat ke schválení
   začátkem prosince (Apple má mezi 23. a 27. 12. omezený provoz), schválit
   dopředu a vydat ručně **7. 1. 2027**. Kód zimního vzhledu zůstává, příští
   advent se zapne sám; stačí znovu přepnout ikonu.

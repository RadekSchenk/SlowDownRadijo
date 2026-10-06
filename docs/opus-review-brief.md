# Zadání: nezávislá revize projektu (audit, ne přepis)

*Určeno pro novou relaci Claude Code s modelem Opus 5.5. Vložte celý tento
dokument jako první zprávu, nebo napište: „Přečti `docs/opus-review-brief.md`
a postupuj podle něj.“*

## Cíl

Najít **skutečné chyby a rizika** v aplikaci Slow Down Rádijo (iOS, SwiftUI,
XcodeGen, iOS 17) a jejím backendu (Supabase). Cílem **není** přepsat nebo
„vylepšit“ existující kód. Hodnotí se jen to, co se dá doložit.

## Pravidla (tvrdá)

1. **Pracuj na nové větvi** `review/opus-audit` z větve
   `claude/adoring-tesla-bj752w` (stav pull requestu #1). Nepushuj do
   `claude/adoring-tesla-bj752w` ani do `main`. Nevytvářej pull request, dokud
   to uživatel výslovně nezadá.
2. **Nejdřív jen zpráva, žádné změny kódu.** Výsledkem první fáze je soubor
   `docs/opus-review-findings.md`. Opravy se dělají až po schválení konkrétních
   nálezů uživatelem, každý nález zvlášť.
3. **Každý nález musí mít důkaz**: soubor a řádek, konkrétní vstup nebo stav a
   chybný výsledek. Nálezy bez realistické cesty (kdo to může zavolat, kdy to
   nastane) uveď zvlášť v sekci „nepotvrzené“, nebo vynech.
4. **Nesahej na odladěný vzhled.** Hodnoty ze Figmy (rozměry, barvy, odsazení,
   typografie, animace v `DesignSystem/Motion.swift`, ekvalizér, dolní
   navigace) jsou změřené a odsouhlasené. Smíš je označit jen jako chybu, když
   odporují Figmě nebo způsobují funkční problém, ne z důvodu vlastního vkusu.
5. **Neměň databázi na ostrém projektu.** Žádné `apply_migration`, žádné
   zápisy ani mazání v Supabase. SQL zkoušej jen na lokálním Postgresu.
6. **Žádná tajemství.** Nevypisuj klíče ani tokeny. Publishable klíč v repu je
   veřejný záměrně, ostatní klíče v repu být nesmějí (ověř).
7. **Swift se v cloudu nepřeloží.** Rozlišuj „zjevná chyba při čtení kódu“ od
   „nelze ověřit bez překladu“ a nic nevydávej za otestované.

## Rozsah a priority

Pořadí podle ceny případné chyby.

### A. Backend statistik (nejvyšší priorita)
Soubory: `backend/supabase/sql/005–008_*.sql`,
`backend/supabase/functions/get-stats`, `backend/README.md`.
- Oprávnění: kdo smí volat které funkce (`anon` vs. `authenticated`), RLS na
  všech tabulkách, `security definer` + `search_path`.
- Ochrana proti falešným datům (008): jde ji obejít? souběh dvou dávek,
  hraniční hodnoty (`day`, `seconds`, `show_id`), přetečení čísel, časová pásma.
- Soukromí: dá se z veřejných funkcí (`public_stats`) zjistit něco o jednom
  posluchači? Co se děje s malým počtem posluchačů?
- Úklid: `prune_inactive_listeners`, archiv v `community_archive`, mazání na
  žádost uživatele. Zůstanou po smazání někde osobní stopy?
- Výkon: indexy, dotazy, které porostou s počtem posluchačů.

### B. Sběr a odesílání statistik v appce
Soubory: `SlowDownRadijo/Services/Stats/*`, `Models/ListeningStats.swift`.
- `ListeningTracker`: počítá jen skutečné přehrávání? přechody pozadí/popředí,
  přerušení hovorem, změna časového pásma, přechod přes půlnoc.
- Fronta v `UserDefaults`: ztráta nebo zdvojení dat při pádu, souběh,
  opakování po chybě (idempotence dávek).
- Keychain a token: obnova, odhlášení, přeinstalace, chyby při zamčeném zařízení.
- Vlákna a `@MainActor`: souběh, uvíznutí, únik paměti (Combine, `Task`).

### C. Přehrávání a stabilita
Soubory: `SlowDownRadijo/Services`, `ViewModels`.
- Streamování, výpadky sítě, přerušení, ovládání na zámku, widget
  (`SlowDownRadijoWidget`), časovač spánku.
- Zbytečné překreslování a energetická náročnost (ekvalizér, `TimelineView`).

### D. Soukromí a obchody
Soubory: `PRIVACY_POLICY.md`, `SlowDownRadijo/PrivacyInfo.xcprivacy`,
`Info.plist`, `project.yml`.
- Souhlasí zásady s tím, co appka a backend skutečně dělají?
- Jsou deklarace v privacy manifestu úplné a pravdivé (App Store, UK GDPR)?
- Dá se přehrávat a používat appku bez zapnutých statistik? Jde je vypnout a
  smazat?

### E. Přístupnost a drobnosti
- VoiceOver popisky, Dynamic Type, Reduce Motion (`Motion.swift`), kontrast.
- Lokalizace (CS/EN), formátování čísel a data.

### F. Co nehledat
Žádné stylistické přepisy, žádné přejmenování, žádné nové knihovny, žádná
nová funkcionalita. Návrhy katalogu a analytiky (`docs/catalog-data-model.md`,
`docs/analytics-events.md`) jen přečti a v jedné sekci napiš, co v nich chybí
nebo si protiřečí.

## Formát výstupu: `docs/opus-review-findings.md`

Nejdřív přehled (počty podle závažnosti), potom každý nález takto:

```
### N. Krátký název
- Závažnost: vysoká / střední / nízká
- Oblast: A–E
- Místo: cesta/soubor.swift:řádek
- Co je špatně: jedna věta
- Postup, jak k chybě dojde: konkrétní vstup nebo sled událostí
- Důkaz: citace kódu, výstup dotazu, nebo „nelze ověřit bez překladu“
- Návrh opravy: nejmenší změna, která to vyřeší
- Cena opravy: malá / střední / velká
```

Na konci sekce „Co je v pořádku“ (krátce, co jsi ověřil a nenašel nic) a
„Nepotvrzené podezření“.

## Po schválení

Uživatel označí, které nálezy se opraví. Každou opravu udělej v samostatném
commitu s jasnou zprávou, bez dalších změn. Před pushem projdi vlastní diff
a znovu zkontroluj, že se nezměnila žádná hodnota z Figmy.

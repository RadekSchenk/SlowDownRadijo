# Budík s rádiem (1.4)

Návrh: Figma „Slow Down Rádijo“ → stránka **Budík s rádiem** (B1–B7).

## Kde je

Na domovské obrazovce pod „Nastavit časovač vypnutí“: „Nastavit budík ☀“,
s nastaveným budíkem „Budík Po–Pá 6:30“. Klepnutí otevře nastavení:
zapnuto/vypnuto, čas, dny (žádný den = jednou), odložení 5/9/10/15 min,
náhled pořadu, který v tu dobu hraje, a „Vyzkoušet za 10 sekund“.
Po buzení je nahoře na domovské obrazovce karta „Dobré ráno“ (Odložit /
Hotovo, sama zmizí po 15 minutách), při odložení „Odloženo · rádio v 6:39“.
Odložit jde nejvýš třikrát, pak už jen hraje.

## iOS (AlarmKit, iOS 26+)

- Systémový budík: zvoní i v tichém režimu a přes Soustředění, na zamčené
  obrazovce. Zvuk je systémový (vlastní zvuky AlarmKit zatím přehrává
  nespolehlivě).
- „Pustit rádio“ (stop tlačítko budíku) spustí `PlayRadioAlarmIntent`:
  otevře appku a pustí živé vysílání. **Bez klepnutí rádio na iOS hrát
  nezačne**, to iOS veřejně neumí.
- „Odložit“ je systémové; odpočet ukazuje Live Activity
  (`RadioAlarmLiveActivity` ve widgetu).
- Na iOS 17–25 se řádek budíku neukáže.
- Kód: `Services/RadioAlarm/`, `Views/Home/RadioAlarmViews.swift`,
  Info.plist `NSAlarmKitUsageDescription`, `NSSupportsLiveActivities`.
- **Ověřit na skutečném iPhonu (TestFlight):** v simulátoru iOS 27 AlarmKit
  oprávnění rovnou zamítl, bez systémového dotazu, takže jsme zvonění ani
  otevření appky z tlačítka v simulátoru neviděli.

## Android

- `AlarmManager.setAlarmClock` (přesný čas, ikona budíku ve stavovém řádku,
  znovu naplánováno po restartu a aktualizaci).
- V čase budíku se rádio pustí samo přes media session (`PlaybackService`),
  hlasitost naroste z 20 % na 100 % za 30 s. Notifikace „Dobré ráno“
  s Odložit / Vypnout rádio.
- Když stream do 20 s nehraje (bez internetu), zazvoní zvuk budíku telefonu
  opakovaně, dokud ho posluchač nezavře.
- Povolení: `SCHEDULE_EXACT_ALARM` (Nastavení → Budíky a připomenutí; na
  Androidu 14+ je pro nové instalace vypnuté, appka na to v nastavení budíku
  upozorní). Ne `USE_EXACT_ALARM` — ten Google Play nechává jen budíkům
  a kalendářům. Bez povolení se budík nenaplánuje.
- Celoobrazovkové buzení přes zámek (B4) zatím ne: `USE_FULL_SCREEN_INTENT`
  Play dává jen budíkům a volání. Místo něj výrazná notifikace.
- Kód: `alarm/RadioAlarm.kt`, `alarm/RadioAlarmUi.kt`, testy `RadioAlarmTest`,
  screenshoty `radio_alarm_sheet_cs`, `radio_alarm_card_cs`.

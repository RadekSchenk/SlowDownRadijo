#!/usr/bin/env bash
# Walks through the Android app on a running emulator while the screen is
# recorded: home (the live stream starts by itself), the programme, the
# sleep timer, Statistiky, Vzkaz, the menu. Taps find elements by their
# text through uiautomator, not by coordinates, so it survives layout
# changes. Writes out/walkthrough.mp4 and out/*.png.
#
#   tools/android/emulator_walkthrough.sh path/to/app.apk out [package]
# No -e: one step going wrong shouldn't lose the rest of the walkthrough.
set -uo pipefail
APK=$1
OUT=$2
PKG=${3:-cz.slowdownradijo.app.debug}
mkdir -p "$OUT"

# Every adb call gets a deadline, so an emulator that goes away can't hang
# the walkthrough; the two long-running streams below call the real adb.
ADB=$(command -v adb)
adb() { timeout 60 "$ADB" "$@"; }

adb install -r -g "$APK" >/dev/null || exit 1
# The whole log, streamed to the host, so it survives the emulator going away.
adb logcat -c || true
"$ADB" logcat -v time > "$OUT/logcat.txt" 2>&1 &
LOGCAT=$!
# Czech, as most listeners.
adb shell "settings put system system_locales cs-CZ" || true
adb shell settings put global window_animation_scale 1
adb shell settings put global transition_animation_scale 1

# The coordinates of the centre of the first element whose text or
# content description is $1.
find() {
  adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
  adb shell cat /sdcard/ui.xml | python3 -c '
import re, sys
xml = sys.stdin.read()
label = sys.argv[1]
for node in re.finditer(r"<node [^>]*>", xml):
    n = node.group(0)
    text = re.search(r"text=\"([^\"]*)\"", n).group(1)
    desc = re.search(r"content-desc=\"([^\"]*)\"", n).group(1)
    if label in (text, desc) or (len(label) > 6 and (label in text or label in desc)):
        x1, y1, x2, y2 = map(int, re.search(r"bounds=\"\[(\d+),(\d+)\]\[(\d+),(\d+)\]\"", n).groups())
        print((x1 + x2) // 2, (y1 + y2) // 2)
        break
' "$1"
}

tap() {
  local at
  at=$(find "$1")
  if [ -z "$at" ]; then echo "not found: $1"; return 0; fi
  adb shell input tap $at
}

shot() {
  timeout 30 "$ADB" wait-for-device || echo "device gone before: $1"
  adb exec-out screencap -p > "$OUT/$1.png" || echo "screenshot failed: $1"
}

swipe_up() { adb shell input swipe 540 1700 540 700 400; }
swipe_down() { adb shell input swipe 540 700 540 1700 400; }

"$ADB" shell screenrecord --bit-rate 6000000 --time-limit 170 /sdcard/walkthrough.mp4 &
RECORD=$!
sleep 2

adb shell am start -n "$PKG/cz.slowdownradijo.app.MainActivity" >/dev/null
sleep 14                       # the stream connects, the song and programme load
shot 01_home
swipe_up; sleep 3; shot 02_programme
tap "Út"; sleep 3; shot 03_programme_tuesday
swipe_down; sleep 1; swipe_down; sleep 2
tap "Nastavit časovač vypnutí"; sleep 3; shot 04_sleep_timer
adb shell input keyevent KEYCODE_BACK; sleep 2
tap "Statistiky"; sleep 5; shot 05_stats
swipe_up; sleep 2; shot 06_stats_more
tap "Vzkaz"; sleep 3; shot 07_message
tap "Rádio"; sleep 2
tap "Menu"; sleep 3; shot 08_menu
tap "English"; sleep 3; shot 09_menu_english
tap "Čeština"; sleep 2
tap "Nastavení"; sleep 3; shot 10_settings
adb shell input keyevent KEYCODE_BACK; sleep 2
tap "Novinky"; sleep 6; shot 11_news
adb shell input keyevent KEYCODE_BACK; sleep 1
adb shell input keyevent KEYCODE_BACK; sleep 2
adb shell cmd statusbar expand-notifications; sleep 3; shot 12_notification
adb shell cmd statusbar collapse; sleep 2
shot 13_home_again

sleep 3
kill -INT $RECORD 2>/dev/null || true
sleep 5
# A recording whose device went away never ends by itself.
kill -9 $RECORD 2>/dev/null || true
adb pull /sdcard/walkthrough.mp4 "$OUT/walkthrough.mp4" >/dev/null
kill $LOGCAT 2>/dev/null || true
# Crashes, ANRs, the app killed for memory, and the player's errors.
grep -E "FATAL EXCEPTION|AndroidRuntime|ANR in|lowmemorykiller|Killing .*slowdownradijo|ExoPlayerImplInternal.*E|E/MediaSessionService" "$OUT/logcat.txt" > "$OUT/errors.log" || true
# Android's crash buffer keeps every crash since boot, whatever happened to the stream above.
adb logcat -d -b crash > "$OUT/crashes.log" 2>&1 || true
{ echo "app process: $(adb shell pidof "$PKG" || echo 'not running')"; } > "$OUT/status.txt"
ls -la "$OUT"

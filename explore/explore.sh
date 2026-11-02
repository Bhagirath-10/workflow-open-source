#!/usr/bin/env bash
# Explores one installed app (app exploration workflow, separate from scripts/): opens it and taps
# through its screens for <minutes>, every new screen screenshotted with its texts and buttons.
# Never taps money, account, delete, call, share or rating buttons (explore/ui_nodes.py SKIP), never
# types anything. Android's permission questions are answered Allow (and noted).
#
#   explore.sh <package> <out-dir> <minutes>
set -uo pipefail
PKG=$1; OUT=$2; MIN=${3:-12}
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$OUT/tried"; NOTES="$OUT/notes.txt"
say() { echo "$*" >> "$NOTES"; }
ui() { python3 -I "$HERE/ui_nodes.py" "$OUT/ui.xml" "$@" 2>/dev/null; }
dump() {
  local i
  for i in 1 2 3; do
    adb shell rm -f /sdcard/ui.xml
    adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
    adb shell cat /sdcard/ui.xml 2>/dev/null | tr -d '\r' > "$OUT/ui.xml"
    grep -q '<hierarchy' "$OUT/ui.xml" && return 0
    sleep 1
  done
  return 1
}
ocr_text() { adb exec-out screencap -p > "$OUT/screen.png"; tesseract "$OUT/screen.png" - --psm 11 2>/dev/null | tr -s '\n' '|' | cut -c1-800; }
launch() { adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; sleep 6; }

# What the app is, from Android itself.
adb shell dumpsys package "$PKG" | tr -d '\r' > "$OUT/package.txt"
{
  echo "## $PKG"
  grep -m1 -E "versionName=" "$OUT/package.txt" | sed 's/^ */  /'
  grep -m1 -E "minSdk=|targetSdk=" "$OUT/package.txt" | sed 's/^ */  /'
  echo "  requested permissions:"; sed -n '/requested permissions:/,/install permissions:/p' "$OUT/package.txt" | grep -o 'android\.permission\.[A-Z_]*\|com\.[a-zA-Z0-9_.]*permission[A-Za-z0-9_.]*' | sort -u | sed 's/^/    /'
  echo "  screens (activities):"; grep -oE "$PKG/[A-Za-z0-9_.\$]+" "$OUT/package.txt" | sort -u | head -60 | sed 's/^/    /'
} >> "$NOTES"

adb logcat -c
launch
# The first thing the app shows (also when it closes right away), with what Android logged.
adb exec-out screencap -p > "$OUT/000-first-launch.png"
say "first launch: on screen $(adb shell dumpsys activity activities 2>/dev/null | grep -m1 mResumedActivity | tr -d '\r' | sed 's/^ *//')"
adb logcat -d 2>/dev/null | grep -iE "$PKG|libflutter|libapp|pairip|license|UnsatisfiedLink|FATAL" | head -60 > "$OUT/first-launch-log.txt"
end=$(( $(date +%s) + MIN * 60 )); step=0; shots=0; backs=0
declare -A seen
while [ "$(date +%s)" -lt "$end" ]; do
  step=$((step + 1))
  if ! dump; then
    say "step $step: screen not readable (uiautomator); OCR: $(ocr_text)"
    [ "$shots" -lt 80 ] && { shots=$((shots + 1)); cp "$OUT/screen.png" "$OUT/$(printf %03d $shots)-unreadable.png"; }
    adb shell input keyevent KEYCODE_BACK; sleep 2; continue
  fi
  top=$(ui top)
  case "$top" in
    com.google.android.permissioncontroller|com.android.permissioncontroller|com.android.packageinstaller)
      xy=$(python3 -I "$HERE/../scripts/ui.py" "$OUT/ui.xml" text "Allow|ALLOW|While using the app|WHILE USING THE APP|Only this time|Allow all the time" 2>/dev/null)
      say "step $step: Android asked for a permission: $(ui texts)"
      shots=$((shots + 1)); adb exec-out screencap -p > "$OUT/$(printf %03d $shots)-permission.png"
      if [ -n "$xy" ]; then adb shell input tap $xy; else adb shell input keyevent KEYCODE_BACK; fi; sleep 2; continue;;
  esac
  if [ "$top" != "$PKG" ]; then
    say "step $step: left the app (on $top): $(ui texts | cut -c1-200)"
    adb shell input keyevent KEYCODE_BACK; sleep 2
    dump && [ "$(ui top)" != "$PKG" ] && launch
    continue
  fi
  sig=$(ui sig)
  if [ -z "${seen[$sig]:-}" ]; then
    seen[$sig]=1; shots=$((shots + 1))
    act=$(adb shell dumpsys activity activities 2>/dev/null | grep -m1 mResumedActivity | grep -oE "$PKG/[^ }]+" )
    name="$(printf %03d $shots)-screen-$sig"
    adb exec-out screencap -p > "$OUT/$name.png"
    say "step $step: NEW SCREEN $name ($act)"
    say "  texts: $(ui texts)"
    ui targets > "$OUT/tried/$sig.all"
    say "  buttons: $(cut -f2 "$OUT/tried/$sig.all" | tr '\n' '|' | cut -c1-600)"
  fi
  touch "$OUT/tried/$sig.done"
  next=$(grep -vxFf "$OUT/tried/$sig.done" "$OUT/tried/$sig.all" | head -1)
  if [ -n "$next" ]; then
    echo "$next" >> "$OUT/tried/$sig.done"; backs=0
    say "step $step: tap \"$(echo "$next" | cut -f2)\""
    adb shell input tap $(echo "$next" | cut -f1); sleep 3
  else
    backs=$((backs + 1))
    say "step $step: every button of this screen tried: back"
    adb shell input keyevent KEYCODE_BACK; sleep 2
    [ "$backs" -ge 4 ] && { say "step $step: back to the start"; adb shell am force-stop "$PKG"; launch; backs=0; }
  fi
done
adb logcat -d 2>/dev/null | grep -E "FATAL EXCEPTION|AndroidRuntime|ANR in|UnsatisfiedLinkError|libflutter|libapp" -A 8 | head -300 > "$OUT/crashes.txt"
say "## done: $step steps, ${#seen[@]} different screens, $shots screenshots"
rm -f "$OUT/ui.xml" "$OUT/screen.png"; rm -rf "$OUT/tried"

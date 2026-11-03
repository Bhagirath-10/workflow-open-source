# Shared by explore/signup.sh and explore/sample-data.sh (app exploration workflow): reading the
# screen (uiautomator), tapping buttons by their text, typing into fields under their label.
# The caller sets PKG, OUT, NOTES, HERE, TAG (prefix of notes and screenshots) and N=0.
say() { echo "$*" >> "$NOTES"; }
ui() { python3 -I "$HERE/ui_nodes.py" "$OUT/ui.xml" "$@" 2>/dev/null; }
dump() {
  local i
  for i in 1 2 3; do
    adb shell rm -f /sdcard/ui.xml
    timeout 25 adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
    timeout 10 adb shell cat /sdcard/ui.xml 2>/dev/null | tr -d '\r' > "$OUT/ui.xml"
    grep -q '<hierarchy' "$OUT/ui.xml" && return 0
    sleep 1
  done
  return 1
}
shot() { N=$((N + 1)); timeout 15 adb exec-out screencap -p > "$OUT/$(printf '%s-%04d' "$TAG" "$N")-$1.png"; }
# tap <regex> <what>: the lowest clickable thing with that text (the button, not a title)
tap() {
  local xy; dump; xy=$(ui click "$1") || { say "  $TAG: no \"$2\" on the screen: $(ui texts | cut -c1-300)"; return 1; }
  say "  $TAG: tap $2 ($xy)"; adb shell input tap $xy; sleep 4
}
# fill <label regex> <text> <what>: types into the field under that label (scrolls up to 3 times)
fill() {
  local xy i
  for i in 0 1 2 3; do
    dump && xy=$(ui fieldbelow "$1") && break
    adb shell input keyevent 111; adb shell input swipe 540 1300 540 500 400; sleep 1   # keyboard away, scroll up
  done
  [ -n "${xy:-}" ] || { say "  $TAG: no field \"$3\": $(ui texts | cut -c1-300)"; return 1; }
  adb shell input tap $xy; sleep 1
  adb shell input text "$(printf '%s' "$2" | sed 's/ /%s/g')"; sleep 1
  adb shell input keyevent KEYCODE_BACK  # hide the keyboard, so the fields under it can be seen
  say "  $TAG: typed $3"; sleep 1
}
launch() {
  local act; act=$(adb shell cmd package resolve-activity --brief -c android.intent.category.LAUNCHER "$PKG" 2>/dev/null | tr -d '\r' | tail -1)
  timeout 30 adb shell am start -n "$act" >/dev/null 2>&1; sleep 8
}
# Startup ad (AdMob full screen): Back closes it.
skip_ad() {
  local i
  for i in 1 2 3; do
    timeout 15 adb shell dumpsys activity activities 2>/dev/null | grep -m1 mResumedActivity | grep -q AdActivity || return 0
    # The ad closes with its "Continue to app" / Close button (Back does nothing on it)
    dump
    if xy=$(ui click "Continue to app|Close|Close ad|Skip|Skip ad|X"); then say "  $TAG: startup ad, tap its close button ($xy)"; adb shell input tap $xy
    else say "  $TAG: startup ad, Back"; adb shell input keyevent KEYCODE_BACK; fi
    sleep 3
  done
}

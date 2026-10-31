#!/usr/bin/env bash
# The whole cycle on one Android (any phone or emulator on adb; ANDROID_SERIAL picks one):
#   1. install-apks.sh   install 4bTech Space, the game and 4bTech Game, screenshot each
#   2. bot-setup.sh      4bTech Game: permissions, its own update, sign-in
#   3. bot-configure.sh  4bTech Game Setup: screen permission, game RummyHome, cloner 4bTech Space
# Start is never pressed. Needs FOUR_BTECH_GAME_EMAIL and FOUR_BTECH_GAME_PASSWORD in the
# environment. Results (notes.txt and screenshots) go to <out-dir>.
#
#   full-cycle.sh <apk-dir> <out-dir>
set -uo pipefail
APK=$1; OUT=$2
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$OUT"
bash "$HERE/install-apks.sh" "$APK" "$OUT" || exit 1
bash "$HERE/bot-setup.sh" "$OUT" || exit 2
bash "$HERE/bot-configure.sh" "$OUT" || exit 3
echo "PASS full cycle: installed, signed in, Setup done (Start not pressed)" | tee -a "$OUT/notes.txt"

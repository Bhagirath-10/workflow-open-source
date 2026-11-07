#!/usr/bin/env bash
# Makes a new test account in an app through its own "Register" screen, so explore.sh can visit
# the screens behind the login (app exploration workflow, separate from scripts/). The owner asked
# for this (3 Nov): names that fit the app, emails on the owner's domain 4born.com, a new strong
# password every run. The account is written to <out-dir>/account.txt (results stay private).
# Stops (exit 2) when the app asks for a code sent by email or SMS: nobody can read it here.
#
#   signup.sh <package> <out-dir>
set -uo pipefail
PKG=$1; OUT=$2
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$OUT"; NOTES="$OUT/notes.txt"; N=0
TAG=signup
. "$HERE/lib.sh"
asks_code() {   # the screen asks for a code (OTP) or to verify the email
  dump; ui texts | grep -qiE "\bOTP\b|verification code|verify your email|enter (the )?code|કોડ"
}

RUN=${GITHUB_RUN_NUMBER:-$(date +%s)}
PASS="Tst$(head -c 12 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 8)9@x"
case "$PKG" in
  com.mechodal.alakhjoli) NAME="Bhakti Tester"; EMAIL="bhakti.tester.$RUN@4born.com"
    # Alakh Joli refuses made-up numbers ("Please enter a genuine mobile number" for 9876543210):
    # the owner's test number, from the secret EXPLORE_MOBILE.
    # Without the secret: the company's own phone number from its website (the owner said to take it from there).
    MOBILE=${EXPLORE_MOBILE:-}
    if [ -z "$MOBILE" ]; then
      for u in https://4born.com https://www.4born.com https://4born.com/contact https://4born.com/contact-us; do
        MOBILE=$(curl -sSL -m 30 -A "Mozilla/5.0" "$u" 2>/dev/null | grep -oE '(\+91|91)?[ -]?[6-9][0-9]{4}[ -]?[0-9]{5}' | tr -d ' +-' | sed -E 's/^91([6-9][0-9]{9})$/\1/' | grep -E '^[6-9][0-9]{9}$' | head -1)
        [ -n "$MOBILE" ] && { say "  signup: mobile number from the company website ($u)"; break; }
      done
    fi
    [ -n "$MOBILE" ] || { say "STOP signup: Alakh Joli needs a genuine mobile number (no secret EXPLORE_MOBILE, none found on 4born.com)"; exit 3; };;
  com.expensetracker.renine) NAME="Expense Tester"; EMAIL="expense.tester.$RUN@4born.com"; MOBILE=;;
  *) say "signup: no sign-up steps known for $PKG"; exit 1;;
esac
say "## signup: new test account for $PKG: $NAME, $EMAIL"

launch; skip_ad; shot start
case "$PKG" in
  com.mechodal.alakhjoli)
    # Up to 3 tries: if the app closes while the form is filled (Back meant for the keyboard left it,
    # runs 198/199/201), it is opened again and the form started over.
    ok=no
    for try in 1 2 3; do
      if tap ".*રજિસ્ટર.*|.*[Rr]egister.*" "Register (રજિસ્ટર કરો)"; then
        shot register
        if fill "નામ.*|Name.*" "$NAME" "name" &&
           fill "ઈમેલ.*|Email.*" "$EMAIL" "email" &&
           fill "મોબાઇલ.*|Mobile.*" "$MOBILE" "mobile number" &&
           fill "પાસવર્ડ \*|પાસવર્ડ|Password.*" "$PASS" "password" &&
           fill "તમારો પાસવર્ડ ફરીથી.*|Confirm.*|Re-?enter.*" "$PASS" "password again"; then
          shot form-filled
          adb shell input swipe 540 1600 540 600 400; sleep 1
          tap "રજિસ્ટર કરો|Register" "the Register button" && { ok=yes; break; }
        fi
      fi
      say "  signup: try $try did not finish (the app may have closed): opening it again"; shot "form-failed-$try"
      timeout 15 adb shell am force-stop "$PKG"; launch; skip_ad
    done
    [ "$ok" = yes ] || exit 1
    ;;
  com.expensetracker.renine)
    dump; ui click "Get Started" >/dev/null && tap "Get Started" "Get Started"
    skip_ad
    tap "Create account|Create Account|Sign ?[Uu]p" "Create account" || exit 1
    shot create-account
    fill "Name.*" "$NAME" "name" &&
    fill "Email.*" "$EMAIL" "email" &&
    fill "Password.*" "$PASS" "password" || { shot form-failed; exit 1; }
    shot form-filled
    tap "Create account|Create Account|Sign ?[Uu]p|Register|Continue" "the Create account button" || exit 1
    ;;
esac
sleep 6; shot after-submit
dump; say "  signup: after the button: $(ui texts | cut -c1-400)"
if asks_code; then say "STOP signup: the app asks for a code sent to $EMAIL / $MOBILE; nobody can read it here"; exit 2; fi
printf 'app: %s\nname: %s\nemail: %s\nmobile: %s\npassword: %s\nmade: run %s, %s\n' \
  "$PKG" "$NAME" "$EMAIL" "${MOBILE:-}" "$PASS" "$RUN" "$(TZ=Asia/Kolkata date '+%d %b %Y %I:%M %p IST')" > "$OUT/account.txt"
say "signup: done (account in account.txt)"

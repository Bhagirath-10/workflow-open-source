# workflow-open-source

Sets up a fresh Android with 4bTech Space, the game (RummyHome) and 4bTech Game, signs
4bTech Game in and finishes its Setup. **Start is never pressed**: nothing is played.

## The cycle

| Step | Script | What it does |
|---|---|---|
| 1 | `scripts/install-apks.sh` | Installs `4bTech-Space.apk`, `base.apk` (RummyHome) and `4B-Rummy-Home.apk` (4bTech Game); App info + screenshot of each |
| 2 | `scripts/bot-setup.sh` | 4bTech Game: permissions (accessibility, screen capture, unknown apps, overlay, no battery limit), lets it update itself, signs in |
| 3 | `scripts/bot-configure.sh` | 4bTech Game Setup: 1. Screen permission (Accessibility › 4bTech Game › On › Allow), 2. Game = RummyHome, 3. Clone app = 4bTech Space, 4. Keep running |
| all | `scripts/full-cycle.sh` | Runs 1 → 2 → 3 and stops at the first failure |

Every screen is screenshotted and its texts go to `notes.txt`. `scripts/ui.py` finds buttons
and fields on the screen from `uiautomator` dumps.

## On GitHub Actions

`.github/workflows/android10-install.yml`: one job on an ARM runner, real arm64 Android 10
(Redroid). It downloads the APKs, runs `full-cycle.sh` and publishes the results to
the private repo `Bhautik-4B/Game-Auto`, branch `workflow-results`, folder `runs/<date>-run<N>/`
(page: `README.md` in that folder). The public run log and summary show only pass/fail.
It runs when the workflow or a script changes; on the default branch it can also be started by
hand (Actions › Run workflow).

Run workflow options: `devices` (2 or 3 phones on one Wi-Fi), `mode` and `save`. With `save`, the
phones' data (apps, sign-in, Setup, pool, clones) is saved at the end to the private release `phones`
of `Bhautik-4B/Game-Auto`. `mode: restore` starts the next run from that data: install, sign-in and
Setup are skipped, the run goes straight to the pool and Start. When nothing is saved for that many
phones yet, the run sets up from scratch. Runs started by a push always set up from scratch and
never save.

Repository secrets:

| Secret | For |
|---|---|
| `PRIVATE_REPO` | token for `Bhautik-4B/Game-Auto`: reads its releases (4bTech Space and base.apk) and stores the results there (Contents: Read and write) |
| `FOUR_BTECH_GAME_EMAIL` / `FOUR_BTECH_GAME_PASSWORD` | the 4bTech Game account |

The secrets are never printed and are replaced by `***` in every published file; no screenshot is
taken while the email is on screen. This repository is public: the published screenshots are too.

## On a phone or another emulator

Android with USB debugging (or any emulator) on `adb`, the three APKs in one folder:

```bash
export FOUR_BTECH_GAME_EMAIL='...' FOUR_BTECH_GAME_PASSWORD='...'
bash scripts/full-cycle.sh path/to/apks out
```

`ANDROID_SERIAL` picks the device when several are connected. The scripts were made on a
1080×2280 screen; the Setup button has a position fallback for that size only.

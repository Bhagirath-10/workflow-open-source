# Android 10 - install and screenshot

Run [#21](https://github.com/Bhagirath-10/workflow-open-source/actions/runs/41187497403), 2026-10-31 09:26 UTC

```
Phone 1 -> phone 2 (172.30.0.12): reachable
Phone 1 -> phone 3 (172.30.0.13): reachable
Phone 2 -> phone 1 (172.30.0.11): reachable
Phone 2 -> phone 3 (172.30.0.13): reachable
Phone 3 -> phone 1 (172.30.0.11): reachable
Phone 3 -> phone 2 (172.30.0.12): reachable
```

# phone1

```
PASS install 4bTech-Space.apk (com.fourbtech.space)
  version 1.1.5
  launch com.fourbtech.space/.MainActivity -> on screen: mResumedActivity: ActivityRecord{363c2a7 u0 com.fourbtech.space/.MainActivity t6}
PASS install base.apk (BnrOdaB.HmkEhkT.AqlWygK.SrmOtnP)
  version 1.0
  launch BnrOdaB.HmkEhkT.AqlWygK.SrmOtnP/.AppActivity -> on screen: mResumedActivity: ActivityRecord{82e0c6d u0 BnrOdaB.HmkEhkT.AqlWygK.SrmOtnP/.AppActivity t7}
PASS install 4B-Rummy-Home.apk (app.gameauto.phone)
  version 2.1.9-qa
  launch app.gameauto.phone/.MainActivity -> on screen: mResumedActivity: ActivityRecord{f9bfe4f u0 com.android.packageinstaller/.PackageInstallerActivity t9}
## 4bTech Game: permissions and sign-in
PASS accessibility service on: app.gameauto.phone/app.gameauto.phone.BotService
  appops: SYSTEM_ALERT_WINDOW: allow PROJECT_MEDIA: allow REQUEST_INSTALL_PACKAGES: allow; rejectTime=+25s935ms ago 
  battery optimisation off: 1 entry
PASS app updated itself: 2.1.9-qa -> 2.1.13
  app version 2.1.13
  secrets: email 22 chars (22 trimmed), password 13 chars (13 trimmed)
  backend https://4brummyhome.synoventum.us.cc/api/v1/auth/login: HTTP 400 error=invalid_request, message=The request body or query is not valid. 
PASS signed in (app.gameauto.phone/.MainActivity)
## 4bTech Game: Setup (game Rummy Home, cloner 4bTech Space; Start is never pressed)
  home screen not readable; tapping the Setup button by position
  screen 1 [app.gameauto.phone]: Setup | Once only. Tap each button and come back here; a green tick means it is done and stays done. | Give the last permission | 1. Screen permission | Lets the app see the game and tap for you. Find 4bTech Game in the list and switch it on. Greyed out? Open App info › ⋮ › Allow restricted settings. | Turn on | 2. Game | Install the game as usual, then pick it here. | Pick | 3. Clone app | 4bTech Space. It keeps the game's accounts, each one separate. Tap Change to use another cloner. | Change | 4. Keep running | Allowed. Android keeps the app running. | 5. Block ads (optional) | Stops most a
  tap: pick
  screen 2 [app.gameauto.phone]: Which app is the game? | Calendar | Clock | Contacts | Email | Files | Gallery | RummyHome | Search | Settings | WebView Browser Tester | Cancel
  tap: game: Rummy Home
  screen 3 [app.gameauto.phone]: Setup | Once only. Tap each button and come back here; a green tick means it is done and stays done. | Give the last permission | 1. Screen permission | Lets the app see the game and tap for you. Find 4bTech Game in the list and switch it on. Greyed out? Open App info › ⋮ › Allow restricted settings. | Turn on | 2. Game | RummyHome | Change | 3. Clone app | 4bTech Space. It keeps the game's accounts, each one separate. Tap Change to use another cloner. | 4. Keep running | Allowed. Android keeps the app running. | 5. Block ads (optional) | Stops most ads in the clone app. One setting in your ph
  tap: game: Rummy Home
  screen 4 [app.gameauto.phone]: Setup | Once only. Tap each button and come back here; a green tick means it is done and stays done. | Give the last permission | 1. Screen permission | Lets the app see the game and tap for you. Find 4bTech Game in the list and switch it on. Greyed out? Open App info › ⋮ › Allow restricted settings. | Turn on | 2. Game | RummyHome | Change | 3. Clone app | 4bTech Space. It keeps the game's accounts, each one separate. Tap Change to use another cloner. | 4. Keep running | Allowed. Android keeps the app running. | 5. Block ads (optional) | Stops most ads in the clone app. One setting in your ph
  tap: Allow|Allow the settings|Grant|Turn on|Switch on|Enable|Open settings|Continue|Next|OK|Got it|GOT IT
  screen 5 [com.android.settings]: Navigate up | Accessibility | Search settings | Volume key shortcut | No service selected | DOWNLOADED SERVICES | 4bTech Game | Off | SCREEN READERS | Text-to-speech output | DISPLAY | Font size | Default | Display size | Dark theme | OFF | Magnification | Large mouse pointer | Remove animations | INTERACTION CONTROLS
  tap: Accessibility: 4bTech Game
  screen 6 [com.android.settings]: Navigate up | 4bTech Game | Use service | OFF | Plays the chosen game on this phone for 4bTech Game: takes screenshots, reads them and taps, the same steps the emulator workflow takes.
  tap: Accessibility: switch 4bTech Game on
  screen 7 [com.android.settings]: Allow 4bTech Game to have full control of your device? | Full control is appropriate for apps that help you with accessibility needs, but not for most apps. | View and control screen | It can read all content on the screen and display content over other apps. | View and perform actions | It can track your interactions with an app or a hardware sensor, and interact with apps on your behalf. | ALLOW | DENY
  tap: confirm
  screen 8 [com.android.settings]: Navigate up | 4bTech Game | Use service | ON | Plays the chosen game on this phone for 4bTech Game: takes screenshots, reads them and taps, the same steps the emulator workflow takes.
  back
  screen 9 [com.android.settings]: Navigate up | Accessibility | Search settings | Volume key shortcut | No service selected | DOWNLOADED SERVICES | 4bTech Game | On | SCREEN READERS | Text-to-speech output | DISPLAY | Font size | Default | Display size | Dark theme | OFF | Magnification | Off | Large mouse pointer | Remove animations | INTERACTION CONTROLS
  tap: Accessibility: 4bTech Game
  screen 10 [com.android.settings]: Navigate up | 4bTech Game | Use service | ON | Plays the chosen game on this phone for 4bTech Game: takes screenshots, reads them and taps, the same steps the emulator workflow takes.
  back
  screen 11 [com.android.settings]: Navigate up | Accessibility | Search settings | Volume key shortcut | No service selected | DOWNLOADED SERVICES | 4bTech Game | On | SCREEN READERS | Text-to-speech output | DISPLAY | Font size | Default | Display size | Dark theme | OFF | Magnification | Off | Large mouse pointer | Remove animations | INTERACTION CONTROLS
  back
  screen 12 [app.gameauto.phone]: Setup | Once only. Tap each button and come back here; a green tick means it is done and stays done. | 1. Screen permission | Allowed. The app can see the game and tap for you. | 2. Game | RummyHome | Change | 3. Clone app | 4bTech Space. It keeps the game's accounts, each one separate. Tap Change to use another cloner. | 4. Keep running | Allowed. Android keeps the app running. | 5. Block ads (optional) | Stops most ads in the clone app. One setting in your phone, no extra app needed. | Set up | Clones already in the cloner app are used as they are. When there is none, the app adds them itsel
  nothing left to tap on this screen
  accessibility services on: app.gameauto.phone/app.gameauto.phone.BotService
PASS Setup done (game RummyHome, cloner 4bTech Space); Start not pressed
PASS full cycle: installed, signed in, Setup done (Start not pressed)
```

## phone1 - 0-home

<img src="phone1/0-home.png" width="300">

## phone1 - 1-4bTech-Space-1-appinfo

<img src="phone1/1-4bTech-Space-1-appinfo.png" width="300">

## phone1 - 1-4bTech-Space-2-open

<img src="phone1/1-4bTech-Space-2-open.png" width="300">

## phone1 - 10-accessibility-settings

<img src="phone1/10-accessibility-settings.png" width="300">

## phone1 - 11-installer-1

<img src="phone1/11-installer-1.png" width="300">

## phone1 - 12-app-open

<img src="phone1/12-app-open.png" width="300">

## phone1 - 13-signed-in

<img src="phone1/13-signed-in.png" width="300">

## phone1 - 14-signed-in-later

<img src="phone1/14-signed-in-later.png" width="300">

## phone1 - 2-base-1-appinfo

<img src="phone1/2-base-1-appinfo.png" width="300">

## phone1 - 2-base-2-open

<img src="phone1/2-base-2-open.png" width="300">

## phone1 - 3-4B-Rummy-Home-1-appinfo

<img src="phone1/3-4B-Rummy-Home-1-appinfo.png" width="300">

## phone1 - 3-4B-Rummy-Home-2-open

<img src="phone1/3-4B-Rummy-Home-2-open.png" width="300">

## phone1 - 30-setup-1

<img src="phone1/30-setup-1.png" width="300">

## phone1 - 31-setup-2

<img src="phone1/31-setup-2.png" width="300">

## phone1 - 32-setup-3

<img src="phone1/32-setup-3.png" width="300">

## phone1 - 33-setup-4

<img src="phone1/33-setup-4.png" width="300">

## phone1 - 34-setup-5

<img src="phone1/34-setup-5.png" width="300">

## phone1 - 35-setup-6

<img src="phone1/35-setup-6.png" width="300">

## phone1 - 36-setup-7

<img src="phone1/36-setup-7.png" width="300">

## phone1 - 37-setup-8

<img src="phone1/37-setup-8.png" width="300">

## phone1 - 38-setup-9

<img src="phone1/38-setup-9.png" width="300">

## phone1 - 39-setup-10

<img src="phone1/39-setup-10.png" width="300">

## phone1 - 40-setup-11

<img src="phone1/40-setup-11.png" width="300">

## phone1 - 41-setup-12

<img src="phone1/41-setup-12.png" width="300">

## phone1 - 42-setup-final

<img src="phone1/42-setup-final.png" width="300">

## phone1 - 43-home-after-setup

<img src="phone1/43-home-after-setup.png" width="300">

## phone1 - 9-final

<img src="phone1/9-final.png" width="300">

# phone2

```
PASS install 4bTech-Space.apk (com.fourbtech.space)
  version 1.1.5
  launch com.fourbtech.space/.MainActivity -> on screen: mResumedActivity: ActivityRecord{cf6136d u0 com.fourbtech.space/.MainActivity t6}
PASS install base.apk (BnrOdaB.HmkEhkT.AqlWygK.SrmOtnP)
  version 1.0
  launch BnrOdaB.HmkEhkT.AqlWygK.SrmOtnP/.AppActivity -> on screen: mResumedActivity: ActivityRecord{64c67fa u0 BnrOdaB.HmkEhkT.AqlWygK.SrmOtnP/.AppActivity t7}
PASS install 4B-Rummy-Home.apk (app.gameauto.phone)
  version 2.1.9-qa
  launch app.gameauto.phone/.MainActivity -> on screen: mResumedActivity: ActivityRecord{fc2729c u0 com.android.packageinstaller/.PackageInstallerActivity t9}
## 4bTech Game: permissions and sign-in
PASS accessibility service on: app.gameauto.phone/app.gameauto.phone.BotService
  appops: SYSTEM_ALERT_WINDOW: allow PROJECT_MEDIA: allow REQUEST_INSTALL_PACKAGES: allow; rejectTime=+25s939ms ago 
  battery optimisation off: 1 entry
PASS app updated itself: 2.1.9-qa -> 2.1.13
  app version 2.1.13
  secrets: email 22 chars (22 trimmed), password 13 chars (13 trimmed)
  backend https://4brummyhome.synoventum.us.cc/api/v1/auth/login: HTTP 400 error=invalid_request, message=The request body or query is not valid. 
PASS signed in (app.gameauto.phone/.MainActivity)
## 4bTech Game: Setup (game Rummy Home, cloner 4bTech Space; Start is never pressed)
  home screen not readable; tapping the Setup button by position
  screen 1 [app.gameauto.phone]: Setup | Once only. Tap each button and come back here; a green tick means it is done and stays done. | Give the last permission | 1. Screen permission | Lets the app see the game and tap for you. Find 4bTech Game in the list and switch it on. Greyed out? Open App info › ⋮ › Allow restricted settings. | Turn on | 2. Game | Install the game as usual, then pick it here. | Pick | 3. Clone app | 4bTech Space. It keeps the game's accounts, each one separate. Tap Change to use another cloner. | Change | 4. Keep running | Allowed. Android keeps the app running. | 5. Block ads (optional) | Stops most a
  tap: pick
  screen 2 [app.gameauto.phone]: Which app is the game? | Calendar | Clock | Contacts | Email | Files | Gallery | RummyHome | Search | Settings | WebView Browser Tester | Cancel
  tap: game: Rummy Home
  screen 3 [app.gameauto.phone]: Setup | Once only. Tap each button and come back here; a green tick means it is done and stays done. | Give the last permission | 1. Screen permission | Lets the app see the game and tap for you. Find 4bTech Game in the list and switch it on. Greyed out? Open App info › ⋮ › Allow restricted settings. | Turn on | 2. Game | RummyHome | Change | 3. Clone app | 4bTech Space. It keeps the game's accounts, each one separate. Tap Change to use another cloner. | 4. Keep running | Allowed. Android keeps the app running. | 5. Block ads (optional) | Stops most ads in the clone app. One setting in your ph
  tap: game: Rummy Home
  screen 4 [app.gameauto.phone]: Setup | Once only. Tap each button and come back here; a green tick means it is done and stays done. | Give the last permission | 1. Screen permission | Lets the app see the game and tap for you. Find 4bTech Game in the list and switch it on. Greyed out? Open App info › ⋮ › Allow restricted settings. | Turn on | 2. Game | RummyHome | Change | 3. Clone app | 4bTech Space. It keeps the game's accounts, each one separate. Tap Change to use another cloner. | 4. Keep running | Allowed. Android keeps the app running. | 5. Block ads (optional) | Stops most ads in the clone app. One setting in your ph
  tap: Allow|Allow the settings|Grant|Turn on|Switch on|Enable|Open settings|Continue|Next|OK|Got it|GOT IT
  screen 5 [com.android.settings]: Navigate up | Accessibility | Search settings | Volume key shortcut | No service selected | DOWNLOADED SERVICES | 4bTech Game | Off | SCREEN READERS | Text-to-speech output | DISPLAY | Font size | Default | Display size | Dark theme | OFF | Magnification | Large mouse pointer | Remove animations | INTERACTION CONTROLS
  tap: Accessibility: 4bTech Game
  screen 6 [com.android.settings]: Navigate up | 4bTech Game | Use service | OFF | Plays the chosen game on this phone for 4bTech Game: takes screenshots, reads them and taps, the same steps the emulator workflow takes.
  tap: Accessibility: switch 4bTech Game on
  screen 7 [com.android.settings]: Allow 4bTech Game to have full control of your device? | Full control is appropriate for apps that help you with accessibility needs, but not for most apps. | View and control screen | It can read all content on the screen and display content over other apps. | View and perform actions | It can track your interactions with an app or a hardware sensor, and interact with apps on your behalf. | ALLOW | DENY
  tap: confirm
  screen 8 [com.android.settings]: Navigate up | 4bTech Game | Use service | ON | Plays the chosen game on this phone for 4bTech Game: takes screenshots, reads them and taps, the same steps the emulator workflow takes.
  back
  screen 9 [com.android.settings]: Navigate up | Accessibility | Search settings | Volume key shortcut | No service selected | DOWNLOADED SERVICES | 4bTech Game | On | SCREEN READERS | Text-to-speech output | DISPLAY | Font size | Default | Display size | Dark theme | OFF | Magnification | Off | Large mouse pointer | Remove animations | INTERACTION CONTROLS
  tap: Accessibility: 4bTech Game
  screen 10 [com.android.settings]: Navigate up | 4bTech Game | Use service | ON | Plays the chosen game on this phone for 4bTech Game: takes screenshots, reads them and taps, the same steps the emulator workflow takes.
  back
  screen 11 [com.android.settings]: Navigate up | Accessibility | Search settings | Volume key shortcut | No service selected | DOWNLOADED SERVICES | 4bTech Game | On | SCREEN READERS | Text-to-speech output | DISPLAY | Font size | Default | Display size | Dark theme | OFF | Magnification | Off | Large mouse pointer | Remove animations | INTERACTION CONTROLS
  back
  screen 12 [app.gameauto.phone]: Setup | Once only. Tap each button and come back here; a green tick means it is done and stays done. | 1. Screen permission | Allowed. The app can see the game and tap for you. | 2. Game | RummyHome | Change | 3. Clone app | 4bTech Space. It keeps the game's accounts, each one separate. Tap Change to use another cloner. | 4. Keep running | Allowed. Android keeps the app running. | 5. Block ads (optional) | Stops most ads in the clone app. One setting in your phone, no extra app needed. | Set up | Clones already in the cloner app are used as they are. When there is none, the app adds them itsel
  nothing left to tap on this screen
  accessibility services on: app.gameauto.phone/app.gameauto.phone.BotService
PASS Setup done (game RummyHome, cloner 4bTech Space); Start not pressed
PASS full cycle: installed, signed in, Setup done (Start not pressed)
```

## phone2 - 0-home

<img src="phone2/0-home.png" width="300">

## phone2 - 1-4bTech-Space-1-appinfo

<img src="phone2/1-4bTech-Space-1-appinfo.png" width="300">

## phone2 - 1-4bTech-Space-2-open

<img src="phone2/1-4bTech-Space-2-open.png" width="300">

## phone2 - 10-accessibility-settings

<img src="phone2/10-accessibility-settings.png" width="300">

## phone2 - 11-installer-1

<img src="phone2/11-installer-1.png" width="300">

## phone2 - 12-app-open

<img src="phone2/12-app-open.png" width="300">

## phone2 - 13-signed-in

<img src="phone2/13-signed-in.png" width="300">

## phone2 - 14-signed-in-later

<img src="phone2/14-signed-in-later.png" width="300">

## phone2 - 2-base-1-appinfo

<img src="phone2/2-base-1-appinfo.png" width="300">

## phone2 - 2-base-2-open

<img src="phone2/2-base-2-open.png" width="300">

## phone2 - 3-4B-Rummy-Home-1-appinfo

<img src="phone2/3-4B-Rummy-Home-1-appinfo.png" width="300">

## phone2 - 3-4B-Rummy-Home-2-open

<img src="phone2/3-4B-Rummy-Home-2-open.png" width="300">

## phone2 - 30-setup-1

<img src="phone2/30-setup-1.png" width="300">

## phone2 - 31-setup-2

<img src="phone2/31-setup-2.png" width="300">

## phone2 - 32-setup-3

<img src="phone2/32-setup-3.png" width="300">

## phone2 - 33-setup-4

<img src="phone2/33-setup-4.png" width="300">

## phone2 - 34-setup-5

<img src="phone2/34-setup-5.png" width="300">

## phone2 - 35-setup-6

<img src="phone2/35-setup-6.png" width="300">

## phone2 - 36-setup-7

<img src="phone2/36-setup-7.png" width="300">

## phone2 - 37-setup-8

<img src="phone2/37-setup-8.png" width="300">

## phone2 - 38-setup-9

<img src="phone2/38-setup-9.png" width="300">

## phone2 - 39-setup-10

<img src="phone2/39-setup-10.png" width="300">

## phone2 - 40-setup-11

<img src="phone2/40-setup-11.png" width="300">

## phone2 - 41-setup-12

<img src="phone2/41-setup-12.png" width="300">

## phone2 - 42-setup-final

<img src="phone2/42-setup-final.png" width="300">

## phone2 - 43-home-after-setup

<img src="phone2/43-home-after-setup.png" width="300">

## phone2 - 9-final

<img src="phone2/9-final.png" width="300">

# phone3

```
PASS install 4bTech-Space.apk (com.fourbtech.space)
  version 1.1.5
  launch com.fourbtech.space/.MainActivity -> on screen: mResumedActivity: ActivityRecord{a7cd8ec u0 com.fourbtech.space/.MainActivity t6}
PASS install base.apk (BnrOdaB.HmkEhkT.AqlWygK.SrmOtnP)
  version 1.0
  launch BnrOdaB.HmkEhkT.AqlWygK.SrmOtnP/.AppActivity -> on screen: mResumedActivity: ActivityRecord{531c84 u0 BnrOdaB.HmkEhkT.AqlWygK.SrmOtnP/.AppActivity t7}
PASS install 4B-Rummy-Home.apk (app.gameauto.phone)
  version 2.1.9-qa
  launch app.gameauto.phone/.MainActivity -> on screen: mResumedActivity: ActivityRecord{5e45635 u0 com.android.packageinstaller/.PackageInstallerActivity t9}
## 4bTech Game: permissions and sign-in
PASS accessibility service on: app.gameauto.phone/app.gameauto.phone.BotService
  appops: SYSTEM_ALERT_WINDOW: allow PROJECT_MEDIA: allow REQUEST_INSTALL_PACKAGES: allow; rejectTime=+25s978ms ago 
  battery optimisation off: 1 entry
PASS app updated itself: 2.1.9-qa -> 2.1.13
  app version 2.1.13
  secrets: email 22 chars (22 trimmed), password 13 chars (13 trimmed)
  backend https://4brummyhome.synoventum.us.cc/api/v1/auth/login: HTTP 400 error=invalid_request, message=The request body or query is not valid. 
PASS signed in (app.gameauto.phone/.MainActivity)
## 4bTech Game: Setup (game Rummy Home, cloner 4bTech Space; Start is never pressed)
  home screen not readable; tapping the Setup button by position
  screen 1 [app.gameauto.phone]: Setup | Once only. Tap each button and come back here; a green tick means it is done and stays done. | Give the last permission | 1. Screen permission | Lets the app see the game and tap for you. Find 4bTech Game in the list and switch it on. Greyed out? Open App info › ⋮ › Allow restricted settings. | Turn on | 2. Game | Install the game as usual, then pick it here. | Pick | 3. Clone app | 4bTech Space. It keeps the game's accounts, each one separate. Tap Change to use another cloner. | Change | 4. Keep running | Allowed. Android keeps the app running. | 5. Block ads (optional) | Stops most a
  tap: pick
  screen 2 [app.gameauto.phone]: Which app is the game? | Calendar | Clock | Contacts | Email | Files | Gallery | RummyHome | Search | Settings | WebView Browser Tester | Cancel
  tap: game: Rummy Home
  screen 3 [app.gameauto.phone]: Setup | Once only. Tap each button and come back here; a green tick means it is done and stays done. | Give the last permission | 1. Screen permission | Lets the app see the game and tap for you. Find 4bTech Game in the list and switch it on. Greyed out? Open App info › ⋮ › Allow restricted settings. | Turn on | 2. Game | RummyHome | Change | 3. Clone app | 4bTech Space. It keeps the game's accounts, each one separate. Tap Change to use another cloner. | 4. Keep running | Allowed. Android keeps the app running. | 5. Block ads (optional) | Stops most ads in the clone app. One setting in your ph
  tap: game: Rummy Home
  screen 4 [app.gameauto.phone]: Setup | Once only. Tap each button and come back here; a green tick means it is done and stays done. | Give the last permission | 1. Screen permission | Lets the app see the game and tap for you. Find 4bTech Game in the list and switch it on. Greyed out? Open App info › ⋮ › Allow restricted settings. | Turn on | 2. Game | RummyHome | Change | 3. Clone app | 4bTech Space. It keeps the game's accounts, each one separate. Tap Change to use another cloner. | 4. Keep running | Allowed. Android keeps the app running. | 5. Block ads (optional) | Stops most ads in the clone app. One setting in your ph
  tap: Allow|Allow the settings|Grant|Turn on|Switch on|Enable|Open settings|Continue|Next|OK|Got it|GOT IT
  screen 5 [com.android.settings]: Navigate up | Accessibility | Search settings | Volume key shortcut | No service selected | DOWNLOADED SERVICES | 4bTech Game | Off | SCREEN READERS | Text-to-speech output | DISPLAY | Font size | Default | Display size | Dark theme | OFF | Magnification | Large mouse pointer | Remove animations | INTERACTION CONTROLS
  tap: Accessibility: 4bTech Game
  screen 6 [com.android.settings]: Navigate up | 4bTech Game | Use service | OFF | Plays the chosen game on this phone for 4bTech Game: takes screenshots, reads them and taps, the same steps the emulator workflow takes.
  tap: Accessibility: switch 4bTech Game on
  screen 7 [com.android.settings]: Allow 4bTech Game to have full control of your device? | Full control is appropriate for apps that help you with accessibility needs, but not for most apps. | View and control screen | It can read all content on the screen and display content over other apps. | View and perform actions | It can track your interactions with an app or a hardware sensor, and interact with apps on your behalf. | ALLOW | DENY
  tap: confirm
  screen 8 [com.android.settings]: Navigate up | 4bTech Game | Use service | ON | Plays the chosen game on this phone for 4bTech Game: takes screenshots, reads them and taps, the same steps the emulator workflow takes.
  back
  screen 9 [com.android.settings]: Navigate up | Accessibility | Search settings | Volume key shortcut | No service selected | DOWNLOADED SERVICES | 4bTech Game | On | SCREEN READERS | Text-to-speech output | DISPLAY | Font size | Default | Display size | Dark theme | OFF | Magnification | Off | Large mouse pointer | Remove animations | INTERACTION CONTROLS
  tap: Accessibility: 4bTech Game
  screen 10 [com.android.settings]: Navigate up | 4bTech Game | Use service | ON | Plays the chosen game on this phone for 4bTech Game: takes screenshots, reads them and taps, the same steps the emulator workflow takes.
  back
  screen 11 [com.android.settings]: Navigate up | Accessibility | Search settings | Volume key shortcut | No service selected | DOWNLOADED SERVICES | 4bTech Game | On | SCREEN READERS | Text-to-speech output | DISPLAY | Font size | Default | Display size | Dark theme | OFF | Magnification | Off | Large mouse pointer | Remove animations | INTERACTION CONTROLS
  back
  screen 12 [app.gameauto.phone]: Setup | Once only. Tap each button and come back here; a green tick means it is done and stays done. | 1. Screen permission | Allowed. The app can see the game and tap for you. | 2. Game | RummyHome | Change | 3. Clone app | 4bTech Space. It keeps the game's accounts, each one separate. Tap Change to use another cloner. | 4. Keep running | Allowed. Android keeps the app running. | 5. Block ads (optional) | Stops most ads in the clone app. One setting in your phone, no extra app needed. | Set up | Clones already in the cloner app are used as they are. When there is none, the app adds them itsel
  nothing left to tap on this screen
  accessibility services on: app.gameauto.phone/app.gameauto.phone.BotService
PASS Setup done (game RummyHome, cloner 4bTech Space); Start not pressed
PASS full cycle: installed, signed in, Setup done (Start not pressed)
```

## phone3 - 0-home

<img src="phone3/0-home.png" width="300">

## phone3 - 1-4bTech-Space-1-appinfo

<img src="phone3/1-4bTech-Space-1-appinfo.png" width="300">

## phone3 - 1-4bTech-Space-2-open

<img src="phone3/1-4bTech-Space-2-open.png" width="300">

## phone3 - 10-accessibility-settings

<img src="phone3/10-accessibility-settings.png" width="300">

## phone3 - 11-installer-1

<img src="phone3/11-installer-1.png" width="300">

## phone3 - 12-app-open

<img src="phone3/12-app-open.png" width="300">

## phone3 - 13-signed-in

<img src="phone3/13-signed-in.png" width="300">

## phone3 - 14-signed-in-later

<img src="phone3/14-signed-in-later.png" width="300">

## phone3 - 2-base-1-appinfo

<img src="phone3/2-base-1-appinfo.png" width="300">

## phone3 - 2-base-2-open

<img src="phone3/2-base-2-open.png" width="300">

## phone3 - 3-4B-Rummy-Home-1-appinfo

<img src="phone3/3-4B-Rummy-Home-1-appinfo.png" width="300">

## phone3 - 3-4B-Rummy-Home-2-open

<img src="phone3/3-4B-Rummy-Home-2-open.png" width="300">

## phone3 - 30-setup-1

<img src="phone3/30-setup-1.png" width="300">

## phone3 - 31-setup-2

<img src="phone3/31-setup-2.png" width="300">

## phone3 - 32-setup-3

<img src="phone3/32-setup-3.png" width="300">

## phone3 - 33-setup-4

<img src="phone3/33-setup-4.png" width="300">

## phone3 - 34-setup-5

<img src="phone3/34-setup-5.png" width="300">

## phone3 - 35-setup-6

<img src="phone3/35-setup-6.png" width="300">

## phone3 - 36-setup-7

<img src="phone3/36-setup-7.png" width="300">

## phone3 - 37-setup-8

<img src="phone3/37-setup-8.png" width="300">

## phone3 - 38-setup-9

<img src="phone3/38-setup-9.png" width="300">

## phone3 - 39-setup-10

<img src="phone3/39-setup-10.png" width="300">

## phone3 - 40-setup-11

<img src="phone3/40-setup-11.png" width="300">

## phone3 - 41-setup-12

<img src="phone3/41-setup-12.png" width="300">

## phone3 - 42-setup-final

<img src="phone3/42-setup-final.png" width="300">

## phone3 - 43-home-after-setup

<img src="phone3/43-home-after-setup.png" width="300">

## phone3 - 9-final

<img src="phone3/9-final.png" width="300">

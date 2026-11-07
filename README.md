# DuoBar for iPhone 5s (iOS 12)

Duo-style status bar icon: open battery ring (with percentage to its left), Wi-Fi in the center, four
cellular dots in the ring's opening. Charging = green ring + bolt, Low Power Mode = yellow, <=20% = red.

Targets: iPhone 5s (arm64), iOS 12.x, rootful jailbreak with MobileSubstrate + PreferenceLoader.
Not compiled or tested on a device by the author of this port: see "If something looks wrong".

## Build (no computer needed): GitHub Actions
1. Create a free GitHub repo (public repos get free build minutes).
2. Upload this project, keeping the folder layout (including `.github/workflows/build.yml`).
   Or use the single-file `build-DuoBar-all-in-one.yml` instead (see below).
3. Open the Actions tab, run "Build DuoBar", then download the `DuoBar-iOS12-5s-deb` artifact.
4. Unzip it, install the .deb with Filza (or `dpkg -i`), then respring.

## Build locally
Install Theos, then `make package FINALPACKAGE=1`.

## Settings
Settings > DuoBar: enable switch, show percentage, size 70-140%, icon color (auto / white / black), respring.

## If something looks wrong
DuoBar writes a short log from SpringBoard to `/var/mobile/duobar12.log` (open it in Filza). It lists
which legacy status bar classes exist and the raw signal / Wi-Fi values read from them. Send me that file
plus a screenshot and I can fix the exact selector or ivar that differs on your device.

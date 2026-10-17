#!/bin/bash
# Photographs every screen in light and dark mode on the iOS simulator, using the app's
# screenshot mode (-demo -screen <name>). Output: screenshots/<mode>-<screen>.png
set -euo pipefail

APP="${1:-build/dd/Build/Products/Debug-iphonesimulator/Derin.app}"
OUT="${2:-screenshots}"
SCREENS="home focus active sounds reward constellation sky badges rewards map deepsky event calendar astro-eclipse-lunar-2028-12 journey stars star signin lockscreen"

UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
runtimes = sorted((k for k in devices if "iOS" in k), reverse=True)
for rt in runtimes:
    phones = [d for d in devices[rt] if d["name"].startswith("iPhone")]
    pro = [d for d in phones if "Pro" in d["name"] and "Max" not in d["name"]]
    pick = (pro or phones)
    if pick:
        print(pick[0]["udid"]); break
')
echo "Simulator: $UDID"
xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl install "$UDID" "$APP"
BID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP/Info.plist")
xcrun simctl status_bar "$UDID" override --time "21:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 || true

mkdir -p "$OUT"
for mode in dark light; do
  xcrun simctl ui "$UDID" appearance "$mode"
  for s in $SCREENS; do
    xcrun simctl terminate "$UDID" "$BID" 2>/dev/null || true
    xcrun simctl launch "$UDID" "$BID" -demo -screen "$s" >/dev/null
    sleep 6
    xcrun simctl io "$UDID" screenshot "$OUT/$mode-$s.png" >/dev/null
    echo "shot $mode-$s"
  done
  # Pinned back header: the longest back-header screen, opened scrolled to the bottom.
  for s in deepsky; do
    xcrun simctl terminate "$UDID" "$BID" 2>/dev/null || true
    xcrun simctl launch "$UDID" "$BID" -demo -screen "$s" -scrolled >/dev/null
    sleep 6
    xcrun simctl io "$UDID" screenshot "$OUT/$mode-$s-scrolled.png" >/dev/null
    echo "shot $mode-$s-scrolled"
  done
  # Odak screen scrolled to its toggles, with the Katı mod info popover open.
  xcrun simctl terminate "$UDID" "$BID" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BID" -demo -screen focus -scrolled -info >/dev/null
  sleep 6
  xcrun simctl io "$UDID" screenshot "$OUT/$mode-focus-info.png" >/dev/null
  echo "shot $mode-focus-info"
done

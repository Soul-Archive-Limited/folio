#!/bin/zsh
# App Store screenshots (Batch O): full-size PNG from the Simulator → JPEG without alpha.
# iPhone: run on an iPhone 17 Pro Simulator (1206 × 2622 = Apple's required "iPhone with
# Dynamic Island, medium display" size). iPad: an iPad Pro 13" Simulator in landscape (2752 × 2064).
# Usage: scripts/appstore-shots.sh <device-udid> <iphone|ipad> [out-folder=docs/appstore]
# The DEBUG app must be installed. Seeds sample data (erases the Simulator's Folio store).
set -e
dev="$1"; kind="$2"; out="${3:-docs/appstore}"; mkdir -p "$out"
tmp=$(mktemp -d)
base=(-hasOnboarded YES -FolioSkipGreeting YES -com.apple.TipKit.HideAllTips 1 -FolioNow 2026-10-27T09:30
      -displayName Sam -FolioAvatar folio:01 -AppleLocale en_GB -AppleLanguages "(en-GB)")
shot() { # name wait args...
  local name=$1 wait=$2; shift 2
  xcrun simctl terminate "$dev" com.devilsense.folio 2>/dev/null || true
  xcrun simctl launch "$dev" com.devilsense.folio "$@" >/dev/null
  sleep "$wait"
  xcrun simctl io "$dev" screenshot "$tmp/$name.png" >/dev/null 2>&1
  sips -s format jpeg -s formatOptions 90 "$tmp/$name.png" --out "$out/$kind-$name.jpg" >/dev/null
  echo "$out/$kind-$name.jpg"
}
xcrun simctl ui "$dev" appearance light
xcrun simctl status_bar "$dev" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4
# Fresh sample diary.
shot seed 6 "${base[@]}" -FolioResetData YES -FolioSampleData YES
rm -f "$out/$kind-seed.jpg"
if [[ "$kind" == iphone ]]; then
  shot 01-calendar 5 "${base[@]}" -FolioSelectDay 2026-10-22
  shot 02-composer 6 "${base[@]}" -FolioSelectDay 2026-10-27 -FolioOpen composer
  shot 03-entry-place 7 "${base[@]}" -FolioSelectDay 2026-09-17 -FolioOpen entry
  shot 04-journal 5 "${base[@]}" -FolioTab journal
  shot 05-places 8 "${base[@]}" -FolioTab journal -FolioJournalMode places
  shot 06-todo 5 "${base[@]}" -FolioTab todo
  shot 07-profile 5 "${base[@]}" -FolioTab profile
  xcrun simctl ui "$dev" appearance dark
  shot 08-calendar-dark 5 "${base[@]}" -FolioSelectDay 2026-10-22
  xcrun simctl ui "$dev" appearance light
else
  shot 01-calendar 6 "${base[@]}" -FolioSelectDay 2026-10-22
  shot 02-entry 7 "${base[@]}" -FolioSelectDay 2026-09-17 -FolioOpen entry
  shot 03-journal 6 "${base[@]}" -FolioTab journal
  shot 04-places 8 "${base[@]}" -FolioTab journal -FolioJournalMode places
  shot 05-year 6 "${base[@]}" -FolioTab journal -FolioJournalMode year
  shot 06-todo 6 "${base[@]}" -FolioTab todo
fi
xcrun simctl status_bar "$dev" clear
rm -rf "$tmp"

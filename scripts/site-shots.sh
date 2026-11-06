#!/bin/zsh
# Website app screenshots (web/public/img/app/<screen>-<light|dark>.webp), Batch K.
# Usage: scripts/site-shots.sh <device-udid>   (sample data must be loaded)
set -e
dev="$1"; out=web/public/img/app; tmp=$(mktemp -d)
base=(-hasOnboarded YES -FolioSkipGreeting YES -com.apple.TipKit.HideAllTips 1 -FolioNow 2026-10-27T09:30 -displayName Sam -AppleLocale en_GB -AppleLanguages "(en-GB)")
shot() { # name wait args...
  local name=$1 wait=$2; shift 2
  xcrun simctl terminate "$dev" com.devilsense.folio 2>/dev/null || true
  xcrun simctl launch "$dev" com.devilsense.folio "$@" >/dev/null
  sleep "$wait"
  xcrun simctl io "$dev" screenshot "$tmp/$name.png" >/dev/null 2>&1
  cwebp -quiet -q 80 -resize 720 0 "$tmp/$name.png" -o "$out/$name.webp"
}
# Fresh sample diary (no drafts left by the dictation demo); its dates are relative to today.
reseed() { xcrun simctl terminate "$dev" com.devilsense.folio 2>/dev/null || true; xcrun simctl launch "$dev" com.devilsense.folio -FolioResetAccount YES -FolioResetData YES -FolioSampleData YES -hasOnboarded YES >/dev/null; sleep 6; }
reseed
xcrun simctl status_bar "$dev" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
for mode in light dark; do
  xcrun simctl ui "$dev" appearance "$mode"
  shot calendar-$mode 4 "${base[@]}" -FolioSelectDay 2026-10-25
  shot calendar-today-$mode 4 "${base[@]}"
  shot collapsed-$mode 4 "${base[@]}" -FolioSelectDay 2026-10-25 -FolioCollapsed YES
  shot jump-$mode 4 "${base[@]}" -FolioJumpSheet YES
  shot composer-$mode 5 "${base[@]}" -FolioOpen composer
  shot entry-$mode 5 "${base[@]}" -FolioSelectDay 2026-10-27 -FolioOpen entry
  shot categories-$mode 5 "${base[@]}" -FolioTab profile -FolioOpen categories
  shot journal-$mode 4 "${base[@]}" -FolioTab journal
  shot photos-$mode 4 "${base[@]}" -FolioTab journal -FolioJournalMode photos
  shot year-$mode 4 "${base[@]}" -FolioTab journal -FolioJournalMode year
  shot todo-$mode 4 "${base[@]}" -FolioTab todo
  shot profile-$mode 4 "${base[@]}" -FolioTab profile -FolioAvatar folio:01
  shot search-$mode 5 "${base[@]}" -FolioTab journal -FolioSearch river
  shot onthisday-$mode 4 "${base[@]}" -FolioNow "$(date +%F)T09:30" -FolioSelectDay "$(date +%F)"
  shot dictation-$mode 6 "${base[@]}" -FolioOpen composer -FolioDemo dictation -FolioOpenTool mic
  shot intelligence-$mode 6 "${base[@]}" -FolioSelectDay 2026-10-27 -FolioOpen composerLarge -FolioDemo intelligence -FolioOpenTool titles
  shot lock-$mode 3 "${base[@]}" -lockEnabled YES
  shot greeting-$mode 3 -hasOnboarded YES -com.apple.TipKit.HideAllTips 1 -FolioNow 2026-10-27T09:30 -displayName Sam -FolioScreen greeting -FolioGreetingHold YES
  reseed
  shot scan-$mode 6 "${base[@]}" -FolioOpen scan -FolioScanSample "$PWD/ios/FolioTests/Resources/sample-diary-page.jpg"
done
xcrun simctl ui "$dev" appearance light
xcrun simctl status_bar "$dev" clear
rm -rf "$tmp"

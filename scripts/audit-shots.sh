#!/bin/zsh
# Full-audit screenshot matrix (Batch O): every main screen on one Simulator in one appearance
# and text size. The DEBUG app must be installed. Erases the Simulator's Folio store.
# Usage: scripts/audit-shots.sh <udid> <out-folder> <label> <light|dark> <text-size>
#   text-size: a simctl content size, e.g. large (default) or accessibility-extra-extra-extra-large
set -e
dev="$1"; out="$2"; label="$3"; mode="$4"; size="$5"; mkdir -p "$out"
base=(-hasOnboarded YES -FolioSkipGreeting YES -com.apple.TipKit.HideAllTips 1 -FolioNow 2026-10-27T09:30
      -displayName Sam -FolioAvatar folio:01 -AppleLocale en_GB -AppleLanguages "(en-GB)" -FolioNoTour YES)
shot() { # name wait args...
  local name=$1 wait=$2; shift 2
  xcrun simctl terminate "$dev" com.devilsense.folio 2>/dev/null || true
  xcrun simctl launch "$dev" com.devilsense.folio "$@" >/dev/null
  sleep "$wait"
  xcrun simctl io "$dev" screenshot "$out/$label-$name.png" >/dev/null 2>&1
  sips -Z 900 "$out/$label-$name.png" >/dev/null
}
xcrun simctl ui "$dev" appearance "$mode"
xcrun simctl ui "$dev" content_size "$size"
xcrun simctl status_bar "$dev" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3
# Onboarding for a brand-new user (store erased; no hasOnboarded).
for p in 0 1 2 3 4 5; do
  shot onb$p 4 -hasOnboarded NO -FolioResetData YES -FolioSkipGreeting YES -AppleLocale en_GB -AppleLanguages "(en-GB)" -FolioOnboardingPage $p
done
shot greeting 3 -hasOnboarded YES -com.apple.TipKit.HideAllTips 1 -FolioNow 2026-10-27T09:30 -displayName Sam -FolioScreen greeting -FolioGreetingHold YES
shot seed 6 "${base[@]}" -FolioResetData YES -FolioSampleData YES -FolioTrashSamples YES
shot calendar 4 "${base[@]}" -FolioSelectDay 2026-10-25
shot today 4 "${base[@]}"
shot collapsed 4 "${base[@]}" -FolioSelectDay 2026-10-25 -FolioCollapsed YES
shot jump 4 "${base[@]}" -FolioJumpSheet YES
shot filter 4 "${base[@]}" -FolioFilter Travel
shot composer 5 "${base[@]}" -FolioOpen composer
shot composer-large 5 "${base[@]}" -FolioSelectDay 2026-10-27 -FolioOpen composerLarge
shot dictation 6 "${base[@]}" -FolioOpen composer -FolioDemo dictation -FolioOpenTool mic
shot intelligence 6 "${base[@]}" -FolioSelectDay 2026-10-27 -FolioOpen composerLarge -FolioDemo intelligence -FolioOpenTool titles
shot entry 5 "${base[@]}" -FolioSelectDay 2026-10-27 -FolioOpen entry
shot entry-place 7 "${base[@]}" -FolioSelectDay 2026-09-17 -FolioOpen entry
shot day-place 6 "${base[@]}" -FolioSelectDay 2026-09-17
shot journal 4 "${base[@]}" -FolioTab journal
shot photos 4 "${base[@]}" -FolioTab journal -FolioJournalMode photos
shot year 4 "${base[@]}" -FolioTab journal -FolioJournalMode year
shot places 7 "${base[@]}" -FolioTab journal -FolioJournalMode places
shot search 5 "${base[@]}" -FolioTab journal -FolioSearch river
shot todo 4 "${base[@]}" -FolioTab todo
shot task-composer 5 "${base[@]}" -FolioTab todo -FolioOpen taskComposer
shot edit-task 5 "${base[@]}" -FolioTab todo -FolioOpen editTask
shot profile 4 "${base[@]}" -FolioTab profile
shot profile-search 5 "${base[@]}" -FolioTab profile -FolioProfileSearch lock
for page in account categories appearance writing notifications widgets privacy data help; do
  shot p-$page 4 "${base[@]}" -FolioTab profile -FolioProfilePage $page
done
shot edit-profile 5 "${base[@]}" -FolioTab profile -FolioOpen editProfile
shot avatars 5 "${base[@]}" -FolioTab profile -FolioOpen avatars
shot category-edit 5 "${base[@]}" -FolioTab profile -FolioOpen categoryEdit
shot deleted 5 "${base[@]}" -FolioTab profile -FolioOpen recentlyDeleted
shot onthisday 4 "${base[@]}" -FolioNow "$(date +%F)T09:30" -FolioSelectDay "$(date +%F)"
shot scan 7 "${base[@]}" -FolioOpen scan -FolioScanSample "$PWD/ios/FolioTests/Resources/sample-diary-page.jpg"
rm -f "$out/$label-seed.png"
xcrun simctl ui "$dev" content_size large
xcrun simctl ui "$dev" appearance light
xcrun simctl status_bar "$dev" clear

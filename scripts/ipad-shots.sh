#!/bin/zsh
# iPad screenshots (Batch L): every main screen on one iPad Simulator, in its current orientation.
# Usage: scripts/ipad-shots.sh <device-udid> <out-folder> <label>   (rotate between runs with the
# Simulator; the DEBUG app must be installed)
set -e
dev="$1"; out="$2"; label="$3"; mkdir -p "$out"
base=(-hasOnboarded YES -FolioSkipGreeting YES -com.apple.TipKit.HideAllTips 1 -FolioNow 2026-10-27T09:30 -displayName Sam -FolioAvatar folio:01 -AppleLocale en_GB -AppleLanguages "(en-GB)")
shot() { # name wait args...
  local name=$1 wait=$2; shift 2
  xcrun simctl terminate "$dev" com.devilsense.folio 2>/dev/null || true
  xcrun simctl launch "$dev" com.devilsense.folio "$@" >/dev/null
  sleep "$wait"
  xcrun simctl io "$dev" screenshot "$out/$label-$name.png" >/dev/null 2>&1
}
xcrun simctl status_bar "$dev" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3
shot calendar 5 "${base[@]}" -FolioSelectDay 2026-10-25
shot entry 6 "${base[@]}" -FolioSelectDay 2026-10-27 -FolioOpen entry
shot composer 6 "${base[@]}" -FolioOpen composer
shot journal 5 "${base[@]}" -FolioTab journal
shot year 5 "${base[@]}" -FolioTab journal -FolioJournalMode year
shot todo 5 "${base[@]}" -FolioTab todo
shot profile 5 "${base[@]}" -FolioTab profile
shot search 6 "${base[@]}" -FolioTab journal -FolioSearch river

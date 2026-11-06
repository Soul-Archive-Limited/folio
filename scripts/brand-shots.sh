#!/bin/zsh
# Batch K: the same screens in light and dark, for before/after contact sheets.
# Usage: scripts/brand-shots.sh <device-udid> <out-folder>
set -e
dev="$1"; out="$2"; mkdir -p "$out"
base=(-hasOnboarded YES -FolioSkipGreeting YES -com.apple.TipKit.HideAllTips 1 -FolioNow 2026-10-27T09:30)
for mode in light dark; do
  xcrun simctl ui "$dev" appearance "$mode"
  scripts/sim-shot.sh "$dev" "$out/calendar-$mode.png" 4 "${base[@]}" -FolioSelectDay 2026-10-25
  scripts/sim-shot.sh "$dev" "$out/empty-day-$mode.png" 4 "${base[@]}" -FolioSelectDay 2026-10-28
  scripts/sim-shot.sh "$dev" "$out/journal-$mode.png" 4 "${base[@]}" -FolioTab journal
  scripts/sim-shot.sh "$dev" "$out/todo-$mode.png" 4 "${base[@]}" -FolioTab todo
  scripts/sim-shot.sh "$dev" "$out/profile-$mode.png" 4 "${base[@]}" -FolioTab profile
  scripts/sim-shot.sh "$dev" "$out/composer-$mode.png" 5 "${base[@]}" -FolioOpen composer
  scripts/sim-shot.sh "$dev" "$out/greeting-$mode.png" 1.2 -hasOnboarded YES -com.apple.TipKit.HideAllTips 1 -FolioNow 2026-10-27T09:30
done
xcrun simctl ui "$dev" appearance light

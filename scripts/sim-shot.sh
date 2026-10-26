#!/bin/sh
# DEBUG screenshot helper: relaunch Folio with launch arguments and capture the screen.
# Usage: scripts/sim-shot.sh <device-udid> <output.png> <wait-seconds> [launch args...]
# Screenshots always run in the en_GB region (weeks start on Monday) — owner decision, Batch B.
set -e
dev="$1"; out="$2"; wait="$3"; shift 3
xcrun simctl terminate "$dev" com.devilsense.folio 2>/dev/null || true
xcrun simctl launch "$dev" com.devilsense.folio -AppleLocale en_GB -AppleLanguages "(en-GB)" "$@" >/dev/null
sleep "$wait"
xcrun simctl io "$dev" screenshot "$out" >/dev/null 2>&1
sips -Z 1200 "$out" >/dev/null
echo "$out"

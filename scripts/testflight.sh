#!/bin/sh
# FALLBACK ONLY — normal TestFlight builds come from Xcode Cloud on every push to main that
# changes ios/ (docs/HANDOFF.md). Use this only if Xcode Cloud is unavailable.
#
# Archives a Release build and uploads it to App Store Connect through the Apple Account
# signed into Xcode (Xcode → Settings → Accounts). No API keys, certificates or passwords are
# read from or written to any file. The build number is the git commit count; make sure it's
# higher than the last Xcode Cloud build number, or App Store Connect rejects the upload.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
build="$root/ios/build/testflight"
rm -rf "$build" && mkdir -p "$build"

cd "$root/ios"
xcodegen generate
xcodebuild archive -project Folio.xcodeproj -scheme Folio -configuration Release \
  -destination "generic/platform=iOS" -archivePath "$build/Folio.xcarchive" -allowProvisioningUpdates

cat > "$build/ExportOptions.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>25DH3LUCPC</string>
  <key>signingStyle</key><string>automatic</string>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST

xcodebuild -exportArchive -archivePath "$build/Folio.xcarchive" -exportOptionsPlist "$build/ExportOptions.plist" \
  -exportPath "$build/export" -allowProvisioningUpdates
echo "Uploaded. It appears in App Store Connect → TestFlight after processing (usually 5–15 minutes)."

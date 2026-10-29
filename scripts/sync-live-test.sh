#!/bin/zsh
# Runs one step of the two-Simulator live sync test (ios/FolioUITests/SyncLiveUITests.swift).
#
#   FOLIO_REVIEW_CODE=… scripts/sync-live-test.sh <simulator-udid> <testName> [KEY=VALUE …]
#
# The review code comes from the environment only (never a file). KEY=VALUE pairs reach the
# test as environment variables. Build first:
#   cd ios && xcodebuild build-for-testing -scheme Folio -destination 'generic/platform=iOS Simulator' -derivedDataPath build/sim
set -euo pipefail
cd "$(dirname "$0")/../ios"

udid=$1; test=$2; shift 2
: "${FOLIO_REVIEW_CODE:?set FOLIO_REVIEW_CODE}"
export TEST_RUNNER_FOLIO_REVIEW_CODE=$FOLIO_REVIEW_CODE
export TEST_RUNNER_FOLIO_SHOTS=${FOLIO_SHOTS:-$PWD/../docs/screenshots/batch-e}
for pair in "$@"; do export "TEST_RUNNER_${pair}"; done

# Each Simulator gets its own copy of the products (an APFS clone), so two steps can run at
# once without waiting on each other's derived-data lock.
data=build/sim-$udid
rm -rf $data && cp -cR build/sim $data
# A runner left over from an earlier step can stop the next one from launching.
xcrun simctl terminate "$udid" com.devilsense.folio >/dev/null 2>&1 || true
xcrun simctl terminate "$udid" com.devilsense.folio.uitests.xctrunner >/dev/null 2>&1 || true
bundle=build/live-$test-$(date +%s).xcresult
perl -e 'alarm shift; exec @ARGV' 600 xcodebuild test-without-building -project Folio.xcodeproj -scheme Folio -derivedDataPath $data \
  -destination "platform=iOS Simulator,id=$udid" -resultBundlePath "$bundle" \
  -only-testing:"FolioUITests/SyncLiveUITests/$test" 2>&1 \
  | grep -E "SYNCTIME|error:|Test Case .*(passed|failed)|XCTAssert|Executed" || true

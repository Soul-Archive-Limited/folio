#!/bin/sh
# Xcode Cloud post-clone step. The .xcodeproj is git-ignored (SPEC §0.9), so install XcodeGen
# and generate it here. The build number comes from CI_BUILD_NUMBER (scripts/write-build-number.sh,
# run by XcodeGen's preGenCommand). Apple manages signing; nothing secret is needed or used.
set -eu
set -x

echo "Xcode Cloud build ${CI_BUILD_NUMBER:-?} for ${CI_COMMIT:-unknown commit} (${CI_WORKFLOW:-no workflow})"
sw_vers
xcodebuild -version

export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
brew install xcodegen
xcodegen --version

cd "$CI_PRIMARY_REPOSITORY_PATH/ios"
xcodegen generate
test -d Folio.xcodeproj || { echo "error: Folio.xcodeproj was not generated" >&2; exit 1; }
cat Config/BuildNumber.xcconfig

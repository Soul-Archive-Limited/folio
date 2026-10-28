#!/bin/sh
# Fails if an Xcode result bundle reports any build warnings or errors (Batch E, Step 0).
# Usage: scripts/check-warnings.sh <path/to/result.xcresult>
# Counts what Xcode's Issue navigator counts (compiler, linker, asset catalog, script
# phases, Info.plist). Apple's App Intents processor prints "Metadata extraction skipped"
# on stdout for apps that don't use App Intents; that line isn't a build issue and isn't
# counted by Xcode either.
set -eu
bundle="$1"
xcrun xcresulttool get build-results --path "$bundle" | python3 -c '
import json, sys
d = json.load(sys.stdin)
issues = d.get("warnings", []) + d.get("errors", []) + d.get("analyzerWarnings", [])
for issue in issues:
    print("::warning::" + issue.get("issueType", "") + ": " + issue.get("message", "") + " " + issue.get("sourceURL", ""))
print("warnings:", d.get("warningCount", 0), "errors:", d.get("errorCount", 0), "analyzer:", len(d.get("analyzerWarnings", [])))
sys.exit(1 if issues or d.get("warningCount", 0) or d.get("errorCount", 0) else 0)
'

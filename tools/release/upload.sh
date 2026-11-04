#!/bin/bash
# Builds the app for the App Store and uploads it to App Store Connect,
# where it shows up in TestFlight after a few minutes of processing.
#
# Run on a Mac with Xcode signed in (Settings → Accounts) to an Apple ID
# in the Slow Down Radio s.r.o. team:
#
#   tools/release/upload.sh
#
# The version shown in the App Store is MARKETING_VERSION in project.yml;
# the build number is the time of the build (yymmddHHMM), so every upload
# gets a new, higher one without anything to edit.
set -euo pipefail
cd "$(dirname "$0")/../.."

BUILD_NUMBER=$(date +%y%m%d%H%M)
ARCHIVE=build/SlowDownRadijo.xcarchive

xcodegen generate

echo "▶ Archiving build $BUILD_NUMBER…"
xcodebuild archive \
  -project SlowDownRadijo.xcodeproj \
  -scheme SlowDownRadijo \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  | grep -E "error:|warning: .*signing|\*\* ARCHIVE" || true
test -d "$ARCHIVE" || { echo "✗ Archive failed — run without the grep to see why."; exit 1; }

echo "▶ Uploading to App Store Connect…"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist tools/release/ExportOptions.plist \
  -exportPath build/export \
  -allowProvisioningUpdates

echo "✓ Build $BUILD_NUMBER uploaded. It appears in App Store Connect → TestFlight once processed (usually 5–15 min)."

#!/bin/bash
set -euo pipefail

# Usage: ./scripts/build-dmg.sh
# Prerequisites:
#   - Xcode with command line tools
#   - Developer ID Application certificate in Keychain
#   - notarytool keychain profile stored as 'notarytool-profile':
#     xcrun notarytool store-credentials 'notarytool-profile' \
#       --apple-id <your-apple-id> \
#       --team-id <your-team-id> \
#       --password <app-specific-password>

SCHEME="MyWhisper"
ARCHIVE_PATH="./build/MyWhisper.xcarchive"
EXPORT_PATH="./build/dist"
DMG_PATH="./build/MyWhisper.dmg"

mkdir -p ./build

echo "=== Step 1: Archive ==="
xcodebuild archive -scheme "$SCHEME" -archivePath "$ARCHIVE_PATH"

echo "=== Step 2: Export with Developer ID ==="
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist MyWhisper/ExportOptions.plist

echo "=== Step 3: Verify code signature ==="
codesign --verify --deep --strict "$EXPORT_PATH/MyWhisper.app"

echo "=== Step 4: Create DMG ==="
rm -f "$DMG_PATH"
hdiutil create -volname "MyWhisper" -srcfolder "$EXPORT_PATH/MyWhisper.app" \
  -ov -format UDZO "$DMG_PATH"

echo "=== Step 5: Sign DMG ==="
codesign --force --sign "Developer ID Application" --timestamp "$DMG_PATH"

echo "=== Step 6: Notarize ==="
xcrun notarytool submit "$DMG_PATH" --keychain-profile "notarytool-profile" --wait

echo "=== Step 7: Staple ==="
xcrun stapler staple "$DMG_PATH"

echo "=== Done ==="
echo "DMG ready at: $DMG_PATH"

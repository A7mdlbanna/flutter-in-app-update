#!/bin/bash
# Builds InAppUpdateInfo.swift + ios/Tests into an XCTest bundle and runs it.
# The code under test is Foundation-only, so it runs on the macOS toolchain
# without a simulator or Flutter.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/in_app_update_kit_ios_tests/InAppUpdateTests.xctest"
PLATFORM="$(xcrun --show-sdk-platform-path)"
FRAMEWORKS="$PLATFORM/Developer/Library/Frameworks"
LIBS="$PLATFORM/Developer/usr/lib"

rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS"
cat >"$OUT/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.nameisjayant.in_app_update.tests</string>
  <key>CFBundleExecutable</key><string>InAppUpdateTests</string>
  <key>CFBundlePackageType</key><string>BNDL</string>
</dict></plist>
PLIST

xcrun --sdk macosx swiftc -warnings-as-errors -parse-as-library \
  -module-name InAppUpdateTests \
  -F "$FRAMEWORKS" -I "$LIBS" -L "$LIBS" \
  -Xlinker -bundle -Xlinker -rpath -Xlinker "$FRAMEWORKS" -Xlinker -rpath -Xlinker "$LIBS" \
  "$ROOT/ios/in_app_update_kit/Sources/in_app_update_kit/InAppUpdateInfo.swift" "$ROOT"/ios/Tests/*.swift \
  -o "$OUT/Contents/MacOS/InAppUpdateTests"

xcrun xctest "$OUT"

#!/usr/bin/env bash
# Builds "Jaṭā.app" into ./build (sandboxed, no network access).
# The bundle identifier stays local.passwordgenerator (the app's earlier name): macOS keeps a sandboxed
# app's data under its identifier, so keeping it keeps saved settings and the used-password history.
set -euo pipefail
cd "$(dirname "$0")"
APP="build/Jaṭā.app"
swift build -c release
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/Jata" "$APP/Contents/MacOS/Jata"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Jaṭā</string>
<key>CFBundleDisplayName</key><string>Jaṭā</string>
<key>CFBundleIdentifier</key><string>local.passwordgenerator</string>
<key>CFBundleExecutable</key><string>Jata</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - --entitlements entitlements.plist "$APP"
echo "Built: $PWD/$APP"

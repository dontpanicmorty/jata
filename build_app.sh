#!/usr/bin/env bash
# Builds "Password Generator.app" into ./build (sandboxed, no network access).
set -euo pipefail
cd "$(dirname "$0")"
APP="build/Password Generator.app"
swift build -c release
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/PasswordGenerator" "$APP/Contents/MacOS/PasswordGenerator"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Password Generator</string>
<key>CFBundleDisplayName</key><string>Password Generator</string>
<key>CFBundleIdentifier</key><string>local.passwordgenerator</string>
<key>CFBundleExecutable</key><string>PasswordGenerator</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - --entitlements entitlements.plist "$APP"
echo "Built: $PWD/$APP"

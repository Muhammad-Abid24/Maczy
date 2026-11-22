#!/usr/bin/env bash
# ==============================================================================
# Maczy Dev Runner
# Builds and launches Maczy as a proper macOS .app bundle with full bundle identity.
# ==============================================================================

set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Building Maczy (Apple Silicon arm64)..."
swift build -c debug

APP_DIR=".build/Maczy.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp ".build/arm64-apple-macosx/debug/Maczy" "$MACOS_DIR/Maczy"

cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>Maczy</string>
    <key>CFBundleExecutable</key>
    <string>Maczy</string>
    <key>CFBundleIdentifier</key>
    <string>com.maczy.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Maczy</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSScreenCaptureUsageDescription</key>
    <string>Maczy requires Screen Recording permission to capture screenshots and record screen video.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Maczy requires Microphone access to record system and voice audio during screen recordings.</string>
    <key>NSCameraUsageDescription</key>
    <string>Maczy requires Camera access for smart unlock feasibility checks.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Maczy requires Apple Events permission to interact with system windows.</string>
</dict>
</plist>
EOF

codesign -s - -f --deep "$APP_DIR" > /dev/null 2>&1

USER_APPS="$HOME/Applications"
mkdir -p "$USER_APPS"
rm -rf "$USER_APPS/Maczy.app"
cp -R "$APP_DIR" "$USER_APPS/Maczy.app"
codesign -s - -f --deep "$USER_APPS/Maczy.app" > /dev/null 2>&1

echo "==> Installed to $USER_APPS/Maczy.app and .build/Maczy.app"
echo "==> Launching $USER_APPS/Maczy.app..."
open "$USER_APPS/Maczy.app"
echo "==> Maczy is running!"

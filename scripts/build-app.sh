#!/bin/zsh
# Build AutoClick.app (menu bar app) vào thư mục build/
set -euo pipefail

cd "$(dirname "$0")/.."
APP="build/AutoClick.app"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/AutoClick"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/AutoClick"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>AutoClick</string>
    <key>CFBundleDisplayName</key><string>AutoClick</string>
    <key>CFBundleIdentifier</key><string>com.thuanho.autoclick</string>
    <key>CFBundleExecutable</key><string>AutoClick</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "✅ Đã build: $APP"

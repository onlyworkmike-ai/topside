#!/bin/bash
# Builds Topside.app next to this script and opens it.
# Usage:  bash build.sh            (build and open)
#         bash build.sh --no-open  (build only)
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v swift >/dev/null 2>&1; then
  echo "Swift was not found. Install Xcode from the App Store, or run:  xcode-select --install"
  exit 1
fi

APP="Topside.app"

echo "Building (the first build takes a minute)..."
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Topside" "$APP/Contents/MacOS/Topside"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>Topside</string>
  <key>CFBundleIdentifier</key><string>com.topside.app</string>
  <key>CFBundleName</key><string>Topside</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>Topside shows what is playing in Music and Spotify and sends play, pause and skip commands.</string>
</dict>
</plist>
PLIST

# Ad-hoc signature so macOS runs it and remembers the permission prompts.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "Done: $(pwd)/$APP"

if [ "${1:-}" != "--no-open" ]; then
  # Quit a previous copy first so the new build replaces it.
  pkill -x Topside >/dev/null 2>&1 || true
  sleep 0.5
  open "$APP"
fi

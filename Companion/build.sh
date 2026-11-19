#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD=${STADIUMPAD_COMPANION_BUILD:?Set an external companion build directory}
PYTHON=${STADIUMPAD_COMPANION_PYTHON:?Use a Python environment containing Companion/requirements.txt and PyInstaller}
[[ "$BUILD" != / && "$BUILD" != "$ROOT" ]] || exit 1
mkdir -p "$BUILD"
swift build --package-path "$ROOT" --configuration release --scratch-path "$BUILD/Swift" --product stadium-library
"$PYTHON" -m PyInstaller --noconfirm --clean --onedir --name stadiumpad-companion --distpath "$BUILD/Dist" --workpath "$BUILD/Work" --specpath "$BUILD" --collect-all paramiko --copy-metadata aiohttp --copy-metadata cryptography --copy-metadata paramiko "$ROOT/Companion/companion.py" > "$BUILD/pyinstaller.log" 2>&1
APP="$BUILD/StadiumPad Companion.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Backend"
ditto "$BUILD/Dist/stadiumpad-companion" "$APP/Contents/Resources/Backend/stadiumpad-companion"
cp "$BUILD/Swift/release/stadium-library" "$APP/Contents/Resources/stadium-library"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.privatezero.stadiumpad.companion</string><key>CFBundleName</key><string>StadiumPad Companion</string><key>CFBundleExecutable</key><string>StadiumPad Companion</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleShortVersionString</key><string>0.7.0</string><key>CFBundleVersion</key><string>1</string><key>LSMinimumSystemVersion</key><string>14.0</string><key>NSLocalNetworkUsageDescription</key><string>Connect to your Stadium and let your paired tablet transfer clone files through this Mac.</string><key>NSBonjourServices</key><array><string>_stadiumserver._tcp</string></array>
</dict></plist>
PLIST
"$PYTHON" "$ROOT/Companion/bundle_notices.py" "$APP/Contents/Resources/Notices"
"$PYTHON" "$ROOT/Companion/unique_helper_uuid.py" "$APP/Contents/Resources/Backend/stadiumpad-companion/stadiumpad-companion"
swiftc -target "${STADIUMPAD_COMPANION_ARCH:-$(uname -m)}-apple-macosx14.0" -parse-as-library -O -framework SwiftUI -framework AppKit -framework Network -framework SystemConfiguration "$ROOT/Companion/MacApp.swift" -o "$APP/Contents/MacOS/StadiumPad Companion"
codesign --force --sign "${STADIUMPAD_COMPANION_SIGNING_IDENTITY:--}" "$APP/Contents/Resources/Backend/stadiumpad-companion/stadiumpad-companion"
codesign --verify --strict "$APP/Contents/Resources/Backend/stadiumpad-companion/stadiumpad-companion"
codesign --force --deep --sign "${STADIUMPAD_COMPANION_SIGNING_IDENTITY:--}" "$APP"
codesign --verify --deep --strict "$APP"
echo "Built $APP"

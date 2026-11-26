#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="$HOME/Applications/LeftDesk.app"
BUILD=$(mktemp -d)
trap 'rm -rf "$BUILD"' EXIT
mkdir -p "$BUILD/LeftDesk.app/Contents/MacOS" "$HOME/Applications"
cp Info.plist "$BUILD/LeftDesk.app/Contents/Info.plist"
mkdir -p "$BUILD/LeftDesk.app/Contents/Resources"
cp LeftDesk.icns "$BUILD/LeftDesk.app/Contents/Resources/"
cat Grid.swift LeftDesk.swift > "$BUILD/main.swift"
xcrun swiftc -sdk "$(xcrun --show-sdk-path)" -swift-version 5 -O "$BUILD/main.swift" -o "$BUILD/LeftDesk.app/Contents/MacOS/LeftDesk"
codesign --force --sign - "$BUILD/LeftDesk.app"
if pgrep -x LeftDesk >/dev/null; then echo 'Quit LeftDesk from its menu before reinstalling.'; exit 1; fi
mkdir -p "$APP/Contents/MacOS"
cp -R "$BUILD/LeftDesk.app/Contents/." "$APP/Contents/"
open "$APP"
echo "Installed $APP"

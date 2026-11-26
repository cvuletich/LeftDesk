#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$PWD"
[[ $(uname -s) == Darwin ]] || { echo 'Run this on macOS.' >&2; exit 1; }
MODE=${1:---free}
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" source/Info.plist)
[[ "$MODE" == --local || "$MODE" == --free || "$MODE" == --release ]] || { echo 'Usage: ./build-dmg.sh [--local|--free|--release]'; exit 1; }
if [[ "$MODE" == --release ]]; then
  : "${SIGN_IDENTITY:?Set SIGN_IDENTITY to your Developer ID Application identity}"
  : "${NOTARY_PROFILE:?Set NOTARY_PROFILE to your notarytool keychain profile}"
  [[ "$SIGN_IDENTITY" == 'Developer ID Application:'* ]] || { echo 'Developer ID Application identity required'; exit 1; }
fi
BUILD=$(mktemp -d)
trap 'rm -rf "$BUILD"' EXIT
APP="$BUILD/staging/LeftDesk.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ROOT/dist"
cp source/Info.plist "$APP/Contents/Info.plist"
cp source/LeftDesk.icns "$APP/Contents/Resources/"
cat source/Grid.swift source/LeftDesk.swift > "$BUILD/main.swift"
SDK=$(xcrun --sdk macosx --show-sdk-path)
for ARCH in arm64 x86_64; do
  xcrun --sdk macosx swiftc -sdk "$SDK" -target "$ARCH-apple-macosx13.0" -swift-version 5 -O "$BUILD/main.swift" -o "$BUILD/LeftDesk-$ARCH"
done
xcrun lipo -create "$BUILD/LeftDesk-arm64" "$BUILD/LeftDesk-x86_64" -output "$APP/Contents/MacOS/LeftDesk"
chmod +x "$APP/Contents/MacOS/LeftDesk"
xcrun lipo -info "$APP/Contents/MacOS/LeftDesk"
if [[ "$MODE" == --release ]]; then
  codesign --force --options runtime --timestamp --entitlements source/Entitlements.plist --sign "$SIGN_IDENTITY" "$APP"
else
  codesign --force --sign - "$APP"
fi
codesign --verify --deep --strict --verbose=2 "$APP"
ln -s /Applications "$BUILD/staging/Applications"
hdiutil create -volname 'LeftDesk' -srcfolder "$BUILD/staging" -format UDZO -ov "$BUILD/LeftDesk.dmg"
if [[ "$MODE" == --release ]]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$BUILD/LeftDesk.dmg"
  xcrun notarytool submit "$BUILD/LeftDesk.dmg" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json > "$BUILD/notary.json"
  cat "$BUILD/notary.json"
  [[ $(/usr/bin/plutil -extract status raw -o - "$BUILD/notary.json") == Accepted ]] || { echo 'Notarization was not accepted'; exit 1; }
  xcrun stapler staple "$BUILD/LeftDesk.dmg"
  xcrun stapler validate "$BUILD/LeftDesk.dmg"
  OUT="$ROOT/dist/LeftDesk-${VERSION}.dmg"
elif [[ "$MODE" == --free ]]; then
  OUT="$ROOT/dist/LeftDesk-${VERSION}.dmg"
else
  OUT="$ROOT/dist/LeftDesk-${VERSION}-local-test.dmg"
fi
hdiutil verify "$BUILD/LeftDesk.dmg"
mv -f "$BUILD/LeftDesk.dmg" "$OUT"
(cd "$ROOT/dist"; shasum -a 256 "$(basename "$OUT")" > "$(basename "$OUT").sha256")
echo "Created $OUT"

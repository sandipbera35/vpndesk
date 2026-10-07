#!/usr/bin/env bash
# Build a .dmg on macOS. Run after: flutter build macos --release
# Usage: ./package_mac.sh <x86_64|aarch64>   (arch of the tor bundle to embed; default = this machine)
set -euo pipefail
cd "$(dirname "$0")"
ARCH="${1:-$( [ "$(uname -m)" = arm64 ] && echo aarch64 || echo x86_64)}"
APP="build/macos/Build/Products/Release/oniondesk.app"
[ -d "$APP" ] || { echo "Build first: flutter build macos --release"; exit 1; }
VERSION=$(grep '^version:' pubspec.yaml | cut -d' ' -f2 | cut -d+ -f1)
rm -rf "$APP/Contents/Resources/tor"
./fetch_tor.sh macos "$ARCH" "$APP/Contents/Resources/tor"
# i2pd for the I2P tab (x86_64 binary; Apple Silicon runs it through Rosetta 2). Optional: if the download fails the
# DMG ships without it and the app falls back to an i2pd the user installed.
rm -rf "$APP/Contents/Resources/i2pd"
./fetch_i2pd.sh macos "$APP/Contents/Resources/i2pd" || { echo "WARNING: shipping without i2pd" >&2; rm -rf "$APP/Contents/Resources/i2pd"; }
# Ad-hoc sign everything so Apple Silicon will run it (replace "-" with a Developer ID to notarize).
IDENTITY="${CODESIGN_IDENTITY:--}"
find "$APP/Contents/Resources/tor" -type f \( -name tor -o -name '*.dylib' \) -exec codesign --force -s "$IDENTITY" {} \;
[ -f "$APP/Contents/Resources/i2pd/i2pd" ] && codesign --force -s "$IDENTITY" "$APP/Contents/Resources/i2pd/i2pd"
codesign --force --deep -s "$IDENTITY" "$APP"
mkdir -p dist
STAGE="$(mktemp -d)"; cp -R "$APP" "$STAGE/OnionDesk.app"; ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "OnionDesk" -srcfolder "$STAGE" -ov -format UDZO "dist/OnionDesk-$VERSION-macos-$ARCH.dmg"

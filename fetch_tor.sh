#!/usr/bin/env bash
# Download the official Tor Expert Bundle and lay it out as: <dest>/tor[.exe], libs, geoip, geoip6
# Usage: ./fetch_tor.sh <linux|macos|windows> <x86_64|aarch64> <dest-dir>
set -euo pipefail
OS="$1"; ARCH="$2"; DEST="$3"
VER="${TOR_BUNDLE_VERSION:-15.0.24}"
BASE="https://dist.torproject.org/torbrowser/$VER"
NAME="tor-expert-bundle-$OS-$ARCH-$VER.tar.gz"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
curl -fsSL "$BASE/$NAME" -o "$TMP/$NAME"
# Verify against the published checksum list.
curl -fsSL "$BASE/sha256sums-unsigned-build.txt" -o "$TMP/sums"
WANT="$(awk -v n="$NAME" '$2==n {print $1}' "$TMP/sums")"
GOT="$( (sha256sum "$TMP/$NAME" 2>/dev/null || shasum -a 256 "$TMP/$NAME") | awk '{print $1}')"
[ -n "$WANT" ] && [ "$WANT" = "$GOT" ] || { echo "Checksum mismatch for $NAME"; exit 1; }
tar -xzf "$TMP/$NAME" -C "$TMP"
mkdir -p "$DEST"
cp -R "$TMP"/tor/. "$DEST"/
cp "$TMP"/data/geoip "$TMP"/data/geoip6 "$DEST"/
chmod +x "$DEST"/tor 2>/dev/null || true
echo "Tor $VER ($OS/$ARCH) -> $DEST"

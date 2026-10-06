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
# Verify the download. The checksum list is itself GPG-signed by the Tor Browser Developers; the signing key is
# pinned by fingerprint, so a tampered mirror cannot swap both the file and its checksum.
TOR_SIGNING_FPR="EF6E286DDA85EA2A4BA7DE684E2C6E8793298290"
SUMS_FILE="sha256sums-signed-build.txt"
verified=0
if command -v gpg >/dev/null 2>&1; then
  GNUPGHOME="$TMP/gnupg"; export GNUPGHOME; mkdir -p "$GNUPGHOME"; chmod 700 "$GNUPGHOME" 2>/dev/null || true
  if curl -fsSL "$BASE/$SUMS_FILE" -o "$TMP/sums" && curl -fsSL "$BASE/$SUMS_FILE.asc" -o "$TMP/sums.asc" \
     && gpg --batch --quiet --auto-key-locate clear,wkd --locate-keys torbrowser@torproject.org >/dev/null 2>&1; then
    # VALIDSIG's last field is the fingerprint of the signer's primary key: it must be the pinned one.
    if gpg --batch --status-fd 1 --verify "$TMP/sums.asc" "$TMP/sums" 2>/dev/null | awk -v f="$TOR_SIGNING_FPR" '$2=="VALIDSIG" && $NF==f {ok=1} END {exit !ok}'; then
      verified=1; echo "Signature OK (Tor Browser Developers, $TOR_SIGNING_FPR)"
    else
      echo "SIGNATURE VERIFICATION FAILED for $SUMS_FILE: refusing to use this download" >&2; exit 1
    fi
  fi
fi
if [ "$verified" != 1 ]; then
  [ "${REQUIRE_SIGNATURE:-0}" = 1 ] && { echo "Could not verify the GPG signature and REQUIRE_SIGNATURE=1" >&2; exit 1; }
  echo "WARNING: GPG signature not checked (gpg or the signing key unavailable); falling back to the unsigned checksum list." >&2
  curl -fsSL "$BASE/sha256sums-unsigned-build.txt" -o "$TMP/sums"
fi
WANT="$(awk -v n="$NAME" '$2==n {print $1}' "$TMP/sums")"
GOT="$( (sha256sum "$TMP/$NAME" 2>/dev/null || shasum -a 256 "$TMP/$NAME") | awk '{print $1}')"
[ -n "$WANT" ] && [ "$WANT" = "$GOT" ] || { echo "Checksum mismatch for $NAME"; exit 1; }
tar -xzf "$TMP/$NAME" -C "$TMP"
mkdir -p "$DEST"
cp -R "$TMP"/tor/. "$DEST"/
cp "$TMP"/data/geoip "$TMP"/data/geoip6 "$DEST"/
chmod -R u+rwX,go+rX,go-w "$DEST"
chmod +x "$DEST"/tor 2>/dev/null || true
echo "Tor $VER ($OS/$ARCH) -> $DEST"

#!/usr/bin/env bash
# Download the official i2pd release for Windows / macOS and lay it out as: <dest>/i2pd[.exe] and <dest>/certificates
# (Linux has no portable official binary: use build_i2pd_linux.sh).
# Usage: ./fetch_i2pd.sh <windows|macos> <dest-dir>
#   windows: i2pd_<v>_win64_mingw.zip (arm64 Windows runs it under x64 emulation, like tor.exe)
#   macos:   i2pd_<v>_osx.tar.gz is an x86_64 binary; Apple Silicon runs it through Rosetta 2
set -euo pipefail
OS="$1"; DEST="$2"
VER="${I2PD_VERSION:-2.61.0}"
BASE="https://github.com/PurpleI2P/i2pd/releases/download/$VER"
SRC_SHA256="409cd3c0257491286611ab6aaf690940c7248fb898377c13fadb65a836e2a0ab"   # source tarball of 2.61.0 (certificates)
SIGNING_FPR="951928BB317024EFD053D73C66F6C87B98EBCFE2"                          # R4SAS, signs SHA512SUMS (first seen 2026-10-07)
case "$OS" in
  windows) NAME="i2pd_${VER}_win64_mingw.zip" ;;
  macos)   NAME="i2pd_${VER}_osx.tar.gz" ;;
  *) echo "Usage: $0 <windows|macos> <dest>" >&2; exit 1 ;;
esac
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
curl -fsSL "$BASE/$NAME" -o "$TMP/$NAME"
curl -fsSL "$BASE/SHA512SUMS" -o "$TMP/SHA512SUMS"
curl -fsSL "$BASE/SHA512SUMS.asc" -o "$TMP/SHA512SUMS.asc"
verified=0
if command -v gpg >/dev/null 2>&1; then
  GNUPGHOME="$TMP/gnupg"; export GNUPGHOME; mkdir -p "$GNUPGHOME"; chmod 700 "$GNUPGHOME" 2>/dev/null || true
  if gpg --batch --quiet --keyserver hkps://keys.openpgp.org --recv-keys "$SIGNING_FPR" >/dev/null 2>&1 \
     || gpg --batch --quiet --keyserver hkps://keyserver.ubuntu.com --recv-keys "$SIGNING_FPR" >/dev/null 2>&1; then
    if gpg --batch --status-fd 1 --verify "$TMP/SHA512SUMS.asc" "$TMP/SHA512SUMS" 2>/dev/null | awk -v f="$SIGNING_FPR" '$2=="VALIDSIG" && $NF==f {ok=1} END {exit !ok}'; then
      verified=1; echo "Signature OK (R4SAS, $SIGNING_FPR)"
    else
      echo "SIGNATURE VERIFICATION FAILED for SHA512SUMS: refusing to use this download" >&2; exit 1
    fi
  fi
fi
if [ "$verified" != 1 ]; then
  [ "${REQUIRE_SIGNATURE:-0}" = 1 ] && { echo "Could not verify the GPG signature and REQUIRE_SIGNATURE=1" >&2; exit 1; }
  echo "WARNING: GPG signature not checked (gpg or the key server unavailable); falling back to the checksum list from the same release." >&2
fi
WANT="$(awk -v n="*$NAME" '$2==n {print $1}' "$TMP/SHA512SUMS")"
GOT="$( (sha512sum "$TMP/$NAME" 2>/dev/null || shasum -a 512 "$TMP/$NAME") | awk '{print $1}')"
[ -n "$WANT" ] && [ "$WANT" = "$GOT" ] || { echo "Checksum mismatch for $NAME" >&2; exit 1; }
mkdir -p "$DEST"
if [ "$OS" = windows ]; then
  # `unzip` is not on every Windows runner; python is.
  python3 -c 'import sys,zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$TMP/$NAME" "$TMP/x" 2>/dev/null \
    || python -c 'import sys,zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$TMP/$NAME" "$TMP/x"
  cp "$TMP/x/i2pd.exe" "$DEST/i2pd.exe"
  rm -rf "$DEST/certificates"; cp -R "$TMP/x/contrib/certificates" "$DEST/certificates"
else
  mkdir -p "$TMP/x" && tar -xzf "$TMP/$NAME" -C "$TMP/x"
  install -m 755 "$TMP/x/i2pd" "$DEST/i2pd"
  # The macOS archive ships only the binary; the certificates come from the (pinned) source tarball.
  curl -fsSL "https://github.com/PurpleI2P/i2pd/archive/refs/tags/$VER.tar.gz" -o "$TMP/src.tgz"
  echo "$SRC_SHA256  $TMP/src.tgz" | (sha256sum -c - 2>/dev/null || shasum -a 256 -c -)
  tar -xzf "$TMP/src.tgz" -C "$TMP" "i2pd-$VER/contrib/certificates"
  rm -rf "$DEST/certificates"; cp -R "$TMP/i2pd-$VER/contrib/certificates" "$DEST/certificates"
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
[ -f "$HERE/packaging/i2p/hosts.txt" ] && install -m 644 "$HERE/packaging/i2p/hosts.txt" "$DEST/hosts.txt"   # seed address book
chmod -R u+rwX,go+rX,go-w "$DEST"
echo "i2pd $VER ($OS) -> $DEST"

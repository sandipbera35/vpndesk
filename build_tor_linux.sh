#!/usr/bin/env bash
# Build tor from source and bundle it with its shared libs + GeoIP data (used where the
# official Tor Expert Bundle has no build, i.e. Linux arm64). Needs: gcc make libevent-dev libssl-dev zlib1g-dev.
# Usage: ./build_tor_linux.sh <dest-dir>
set -euo pipefail
DEST="$(mkdir -p "$1" && cd "$1" && pwd)"
VER=0.4.9.13
SHA=5e748d3272cdf44a7d7741173f371c8def3d96eecb77e93c89c50663ce9cc792
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cd "$TMP"
curl -fsSL "https://dist.torproject.org/tor-$VER.tar.gz" -o tor.tgz
echo "$SHA  tor.tgz" | sha256sum -c -
tar xzf tor.tgz && cd "tor-$VER"
./configure --disable-asciidoc --disable-manpage --disable-html-manual --disable-unittests --disable-systemd --disable-seccomp --disable-lzma --disable-zstd --prefix="$TMP/inst" >/dev/null
make -j"$(nproc)" >/dev/null
make install >/dev/null
cp "$TMP/inst/bin/tor" "$DEST/tor"
cp "$TMP/inst/share/tor/geoip" "$TMP/inst/share/tor/geoip6" "$DEST/"
mkdir -p "$DEST"
for l in $(ldd "$DEST/tor" | awk '/=> \// {print $3}' | grep -vE '/(libc|libm|libdl|libpthread|librt|libgcc_s)\.so|ld-linux'); do cp -L "$l" "$DEST/"; done
echo "Built tor $VER -> $DEST"

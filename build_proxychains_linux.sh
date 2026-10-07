#!/usr/bin/env bash
# Build libproxychains4.so (proxychains-ng, GPL-2.0+) from source. It is an LD_PRELOAD shim that forces a program's
# TCP connections and name lookups through a SOCKS5 proxy, used by the I2P tab's split tunneling so apps that ignore
# proxy settings still go through I2P. Only the library is shipped (we set LD_PRELOAD ourselves), unmodified.
# Needs: gcc make. Usage: ./build_proxychains_linux.sh <dest-dir>   -> <dest>/libproxychains4.so
set -euo pipefail
DEST="$(mkdir -p "$1" && cd "$1" && pwd)"
VER=4.17
SHA256="1a2dc68fcbcb2546a07a915343c1ffc75845f5d9cc3ea5eb3bf0b62a66c0196f"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cd "$TMP"
curl -fsSL "https://github.com/rofl0r/proxychains-ng/archive/refs/tags/v$VER.tar.gz" -o pc.tgz
echo "$SHA256  pc.tgz" | sha256sum -c -
tar xzf pc.tgz && cd "proxychains-ng-$VER"
./configure >/dev/null
make -j"$(nproc)" libproxychains4.so >/dev/null 2>&1 || make -j"$(nproc)" >/dev/null
LIB="$(find . -name 'libproxychains4.so' | head -1)"
[ -n "$LIB" ] || { echo "libproxychains4.so was not built" >&2; exit 1; }
strip --strip-unneeded "$LIB"
install -m 644 "$LIB" "$DEST/libproxychains4.so"
echo "Built proxychains-ng $VER -> $DEST/libproxychains4.so"

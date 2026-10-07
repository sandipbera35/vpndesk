#!/usr/bin/env bash
# Build i2pd from source with boost/OpenSSL/zlib linked statically (only glibc stays dynamic), plus its certificates.
# The official release has no portable Linux binary, and distro packages differ in boost/OpenSSL versions, so the
# same trick as build_tor_linux.sh is used: build once in CI, ship one self-contained binary.
# Needs (Debian/Ubuntu): g++ make libboost-program-options-dev libssl-dev zlib1g-dev
# Usage: ./build_i2pd_linux.sh <dest-dir>      -> <dest>/i2pd and <dest>/certificates/{reseed,family}
set -euo pipefail
DEST="$(mkdir -p "$1" && cd "$1" && pwd)"
HERE="$(cd "$(dirname "$0")" && pwd)"
VER="${I2PD_VERSION:-2.61.0}"
SHA256="409cd3c0257491286611ab6aaf690940c7248fb898377c13fadb65a836e2a0ab"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cd "$TMP"
curl -fsSL "https://github.com/PurpleI2P/i2pd/archive/refs/tags/$VER.tar.gz" -o i2pd.tgz
echo "$SHA256  i2pd.tgz" | sha256sum -c -
tar xzf i2pd.tgz && cd "i2pd-$VER"
# USE_UPNP=no: no miniupnpc dependency. The C++ runtime is linked statically too so the binary needs only glibc.
make -j"$(nproc)" USE_STATIC=yes USE_UPNP=no LDFLAGS="-static-libstdc++ -static-libgcc" >/dev/null
STAGE="$TMP/stage"; mkdir -p "$STAGE"
install -m 755 i2pd "$STAGE/i2pd"
strip --strip-unneeded "$STAGE/i2pd"   # the unstripped static binary is ~120 MB
cp -R contrib/certificates "$STAGE/certificates"
# Seed address book (see lib/i2p.dart seedAddressBook): next to the binary, copied to the data folder on first start.
[ -f "$HERE/packaging/i2p/hosts.txt" ] && install -m 644 "$HERE/packaging/i2p/hosts.txt" "$STAGE/hosts.txt"
chmod -R u+rwX,go+rX,go-w "$STAGE"
# Fail the build (not the user) if the result is not self-contained or does not run; nothing reaches $DEST then.
if ldd "$STAGE/i2pd" | grep -E "libboost|libssl|libcrypto|libz\.|libstdc|libminiupnpc" ; then echo "i2pd is not self-contained" >&2; exit 1; fi
"$STAGE/i2pd" --version | head -1
rm -rf "$DEST/i2pd" "$DEST/certificates"
cp -R "$STAGE/." "$DEST/"
echo "Built i2pd $VER -> $DEST"

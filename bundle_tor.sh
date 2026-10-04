#!/usr/bin/env bash
# Put the official Tor Expert Bundle into the Linux release bundle (portable across distros).
# aarch64 has no official bundle, so tor is compiled from source (build_tor_linux.sh).
set -euo pipefail
cd "$(dirname "$0")"
for d in build/linux/x64/release/bundle build/linux/arm64/release/bundle; do
  [ -d "$d" ] && install -m 755 packaging/linux/vpndesk-net "$d/vpndesk-net"
done
case "$(uname -m)" in
  x86_64) A=x86_64; B=x64 ;;
  aarch64|arm64) rm -rf build/linux/arm64/release/bundle/tor; ./build_tor_linux.sh build/linux/arm64/release/bundle/tor; exit 0 ;;
  *) echo "Unsupported arch $(uname -m)"; exit 1 ;;
esac
rm -rf "build/linux/$B/release/bundle/tor"
./fetch_tor.sh linux "$A" "build/linux/$B/release/bundle/tor"


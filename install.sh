#!/usr/bin/env bash
# Developer install: copies the local build to ~/.local/share/vpn_desk with a "VPN Desk (dev)" menu entry.
# If you installed the .deb/.rpm package, you do NOT need this; use FORCE=1 to run it anyway.
# Remove again with: ./install.sh --uninstall
set -euo pipefail
case "$(uname -m)" in aarch64) ARCH=arm64 ;; *) ARCH=x64 ;; esac
SRC="$(cd "$(dirname "$0")" && pwd)/build/linux/$ARCH/release/bundle"
ICON_SRC="$(cd "$(dirname "$0")" && pwd)/packaging/icon.png"
DEST="$HOME/.local/share/vpn_desk"
APPS="$HOME/.local/share/applications"
ICONS="$HOME/.local/share/icons/hicolor/512x512/apps"
ENTRY="$APPS/vpn_desk-dev.desktop"

if [ "${1:-}" = "--uninstall" ]; then
  rm -rf "$DEST" "$ENTRY" "$APPS/vpn_desk.desktop"
  update-desktop-database "$APPS" 2>/dev/null || true
  echo "Removed the developer install."; exit 0
fi

if [ -x /opt/vpn_desk/vpn_desk ] && [ "${FORCE:-}" != "1" ]; then
  echo "VPN Desk is already installed from a package (/opt/vpn_desk)."
  echo "A second copy would shadow it and launch an outdated build. Re-run with FORCE=1 to install anyway."
  exit 1
fi
[ -x "$SRC/vpn_desk" ] || { echo "Build first: flutter build linux --release && ./bundle_tor.sh"; exit 1; }

rm -rf "$DEST"; mkdir -p "$DEST" "$APPS" "$ICONS"
cp -r "$SRC/." "$DEST/"
# Remove the old entry name used by earlier versions of this script.
rm -f "$APPS/vpn_desk.desktop"
cat > "$ENTRY" <<DESK
[Desktop Entry]
Name=VPN Desk (dev)
Exec=$DEST/vpn_desk
Icon=vpn_desk
Type=Application
Categories=Network;
Terminal=false
DESK
[ -f "$ICON_SRC" ] && cp "$ICON_SRC" "$ICONS/vpn_desk.png" || true
update-desktop-database "$APPS" 2>/dev/null || true
echo "Installed. Find 'VPN Desk (dev)' in your app menu, or run: $DEST/vpn_desk"

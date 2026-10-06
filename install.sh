#!/usr/bin/env bash
# Developer install: copies the local build to ~/.local/share/oniondesk with a "OnionDesk (dev)" menu entry.
# If you installed the .deb/.rpm package, you do NOT need this; use FORCE=1 to run it anyway.
# Remove again with: ./install.sh --uninstall
set -euo pipefail
case "$(uname -m)" in aarch64) ARCH=arm64 ;; *) ARCH=x64 ;; esac
SRC="$(cd "$(dirname "$0")" && pwd)/build/linux/$ARCH/release/bundle"
ICON_SRC="$(cd "$(dirname "$0")" && pwd)/packaging/icon.png"
DEST="$HOME/.local/share/oniondesk"
APPS="$HOME/.local/share/applications"
ICONS="$HOME/.local/share/icons/hicolor/512x512/apps"
ENTRY="$APPS/oniondesk-dev.desktop"

if [ "${1:-}" = "--uninstall" ]; then
  rm -rf "$DEST" "$ENTRY" "$APPS/oniondesk.desktop"
  update-desktop-database "$APPS" 2>/dev/null || true
  echo "Removed the developer install."; exit 0
fi

if [ -x /opt/oniondesk/oniondesk ] && [ "${FORCE:-}" != "1" ]; then
  echo "OnionDesk is already installed from a package (/opt/oniondesk)."
  echo "A second copy would shadow it and launch an outdated build. Re-run with FORCE=1 to install anyway."
  exit 1
fi
[ -x "$SRC/oniondesk" ] || { echo "Build first: flutter build linux --release && ./bundle_tor.sh"; exit 1; }

rm -rf "$DEST"; mkdir -p "$DEST" "$APPS" "$ICONS"
cp -r "$SRC/." "$DEST/"
# Remove the old entry name used by earlier versions of this script.
rm -f "$APPS/oniondesk.desktop"
cat > "$ENTRY" <<DESK
[Desktop Entry]
Name=OnionDesk (dev)
Exec=$DEST/oniondesk
Icon=oniondesk
Type=Application
Categories=Network;
Terminal=false
DESK
[ -f "$ICON_SRC" ] && cp "$ICON_SRC" "$ICONS/oniondesk.png" || true
update-desktop-database "$APPS" 2>/dev/null || true
echo "Installed. Find 'OnionDesk (dev)' in your app menu, or run: $DEST/oniondesk"

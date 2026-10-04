#!/usr/bin/env bash
# Install VPN Desk as a proper desktop app (menu entry, launcher, no root needed).
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)/build/linux/x64/release/bundle"
DEST="$HOME/.local/share/vpn_desk"
APPS="$HOME/.local/share/applications"
ICONS="$HOME/.local/share/icons/hicolor/512x512/apps"

mkdir -p "$DEST"
cp -r "$SRC/." "$DEST/"
rm -rf "$DEST/bundle"
mkdir -p "$APPS" "$ICONS"
cat > "$APPS/vpn_desk.desktop" <<EOF
[Desktop Entry]
Name=VPN Desk
Exec=$DEST/vpn_desk
Icon=vpn_desk
Type=Application
Categories=Network;
Terminal=false
EOF
[ -f "$SRC/data/flutter_assets/assets/icon.png" ] && cp "$SRC/data/flutter_assets/assets/icon.png" "$ICONS/vpn_desk.png" || true
update-desktop-database "$APPS" 2>/dev/null || true
echo "Installed. Find 'VPN Desk' in your app menu, or run: $DEST/vpn_desk"

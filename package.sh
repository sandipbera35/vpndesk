#!/usr/bin/env bash
# Build .deb and .rpm packages from the Flutter release bundle.
# Usage: ./package.sh   (run after: flutter build linux --release && ./bundle_tor.sh)
set -euo pipefail
APP="$(cd "$(dirname "$0")" && pwd)"
case "$(uname -m)" in
  x86_64) FA=x64; DEBARCH=amd64; RPMARCH=x86_64; EXTRA_DEB=""; EXTRA_RPM="" ;;
  aarch64) FA=arm64; DEBARCH=arm64; RPMARCH=aarch64; EXTRA_DEB=""; EXTRA_RPM="" ;;
  *) echo "Unsupported arch"; exit 1 ;;
esac
BUNDLE="$APP/build/linux/$FA/release/bundle"
[ -x "$BUNDLE/vpn_desk" ] || { echo "Missing bundle: run flutter build linux --release && ./bundle_tor.sh"; exit 1; }
VERSION=$(grep '^version:' "$APP/pubspec.yaml" | cut -d' ' -f2 | cut -d+ -f1)
DIST="$APP/dist"
rm -rf "$DIST" "$APP/.pkg"

# ---- common staging ----
STAGE="$APP/.pkg/root"
mkdir -p "$STAGE/opt/vpn_desk" "$STAGE/usr/share/polkit-1/actions" \
         "$STAGE/usr/share/applications" \
         "$STAGE/usr/share/icons/hicolor/512x512/apps"
cp -r "$BUNDLE/"* "$STAGE/opt/vpn_desk/"
install -m 644 "$APP/packaging/linux/io.vpndesk.net.policy" "$STAGE/usr/share/polkit-1/actions/io.vpndesk.net.policy"
cat > "$STAGE/usr/share/applications/vpn_desk.desktop" <<EOF
[Desktop Entry]
Name=VPN Desk
Exec=/opt/vpn_desk/vpn_desk
Icon=vpn_desk
Type=Application
Categories=Network;
Terminal=false
EOF
# simple icon: reuse Flutter's asset if present, else skip
ICON_SRC="$APP/packaging/icon.png"
[ -f "$ICON_SRC" ] && cp "$ICON_SRC" "$STAGE/usr/share/icons/hicolor/512x512/apps/vpn_desk.png" || true

# ---- .deb ----
mkdir -p "$STAGE/DEBIAN"
cat > "$STAGE/DEBIAN/control" <<EOF
Package: vpn-desk
Version: $VERSION
Section: net
Priority: optional
Architecture: $DEBARCH
Depends: libgtk-3-0, libc6 (>= 2.34), nftables$EXTRA_DEB
Recommends: policykit-1 | polkitd, pkexec | policykit-1
Maintainer: vpn-desk developers
Description: Desktop GUI for Tor country simulation and VPN management
EOF
mkdir -p "$DIST"
dpkg-deb --root-owner-group --build "$STAGE" "$DIST/vpn-desk_${VERSION}_${DEBARCH}.deb" 2>/dev/null || \
  python3 -c "print('dpkg-deb not available - install: sudo dnf install dpkg')"

# ---- .rpm ----
TOPDIR="$APP/.pkg/rpmbuild"
mkdir -p "$TOPDIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
cd "$STAGE" && tar czf "$TOPDIR/SOURCES/vpn_desk-${VERSION}-bundle.tar.gz" opt usr
cat > "$TOPDIR/SPECS/vpn-desk.spec" <<EOF
Name: vpn-desk
Version: $VERSION
Release: 1
Summary: Desktop GUI for Tor country simulation
License: MIT
BuildArch: $RPMARCH
Requires: gtk3, nftables$EXTRA_RPM
Recommends: polkit
AutoReqProv: no
Source0: vpn_desk-${VERSION}-bundle.tar.gz

%description
Desktop app to start/stop Tor with a chosen country exit node.

%install
mkdir -p %{buildroot}
tar xzf %{SOURCE0} -C %{buildroot}

%files
%defattr(-,root,root,-)
/opt/vpn_desk
/usr/share/applications/vpn_desk.desktop
/usr/share/polkit-1/actions/io.vpndesk.net.policy
/usr/share/icons/hicolor/512x512/apps/vpn_desk.png
EOF
rpmbuild -bb --define "_topdir $TOPDIR" "$TOPDIR/SPECS/vpn-desk.spec" && \
  cp "$TOPDIR"/RPMS/$RPMARCH/*.rpm "$DIST/" || echo "rpmbuild unavailable - install: sudo dnf install rpm-build"

echo "Artifacts:"; ls -la "$DIST"

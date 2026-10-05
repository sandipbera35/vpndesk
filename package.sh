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
mkdir -p "$STAGE/opt/vpn_desk" "$STAGE/usr/bin" "$STAGE/usr/share/polkit-1/actions" \
         "$STAGE/usr/share/applications" "$STAGE/usr/share/metainfo" \
         "$STAGE/usr/share/icons/hicolor/512x512/apps"
cp -r "$BUNDLE/"* "$STAGE/opt/vpn_desk/"
# The Tor Expert Bundle ships 700/600 files; normal users must be able to read and run everything.
chmod -R u+rwX,go+rX,go-w "$STAGE/opt/vpn_desk"
# `vpndesk-restore` on PATH: the display-less "no internet after a crash" command
ln -s /opt/vpn_desk/vpndesk-restore "$STAGE/usr/bin/vpndesk-restore"
install -m 644 "$APP/packaging/linux/io.vpndesk.net.policy" "$STAGE/usr/share/polkit-1/actions/io.vpndesk.net.policy"
cat > "$STAGE/usr/share/applications/io.vpndesk.VPNDesk.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=VPN Desk
GenericName=Tor country exit manager
Comment=Browse through Tor from a country you choose
Exec=/opt/vpn_desk/vpn_desk
Icon=vpn_desk
Terminal=false
Categories=Network;Security;
Keywords=VPN;Tor;Proxy;Privacy;
StartupWMClass=vpn_desk
EOF
# AppStream metadata (what software centers show), with this build's version and date
sed -e "s/@VERSION@/$VERSION/" -e "s/@DATE@/$(date +%F)/" "$APP/packaging/linux/io.vpndesk.VPNDesk.metainfo.xml" \
  > "$STAGE/usr/share/metainfo/io.vpndesk.VPNDesk.metainfo.xml"
if command -v appstreamcli >/dev/null; then appstreamcli validate --no-net "$STAGE/usr/share/metainfo/io.vpndesk.VPNDesk.metainfo.xml"; fi
if command -v desktop-file-validate >/dev/null; then desktop-file-validate "$STAGE/usr/share/applications/io.vpndesk.VPNDesk.desktop"; fi
# simple icon: reuse Flutter's asset if present, else skip
ICON_SRC="$APP/packaging/icon.png"
[ -f "$ICON_SRC" ] && cp "$ICON_SRC" "$STAGE/usr/share/icons/hicolor/512x512/apps/vpn_desk.png" || true
for SZ in 256 128 64; do
  if [ -f "$ICON_SRC" ] && command -v convert >/dev/null; then
    mkdir -p "$STAGE/usr/share/icons/hicolor/${SZ}x${SZ}/apps"
    convert "$ICON_SRC" -resize ${SZ}x${SZ} "$STAGE/usr/share/icons/hicolor/${SZ}x${SZ}/apps/vpn_desk.png"
  fi
done

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
Maintainer: Sandip Bera <sandipbera35@gmail.com>
Homepage: https://github.com/sandipbera35/vpndesk
Description: Browse through Tor from a country you choose
 VPN Desk starts a bundled Tor client with a strict exit relay in the country
 you pick, shows your real and exit locations on a live map and ranks countries
 by live speed estimates. An optional system-wide mode routes all TCP and DNS
 traffic through Tor.
EOF
mkdir -p "$DIST"
dpkg-deb --root-owner-group --build "$STAGE" "$DIST/vpn-desk_${VERSION}_${DEBARCH}.deb" 2>/dev/null || \
  python3 -c "print('dpkg-deb not available - install: sudo dnf install dpkg')"

# ---- .rpm ----
TOPDIR="$APP/.pkg/rpmbuild"
mkdir -p "$TOPDIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
cd "$STAGE" && tar czf "$TOPDIR/SOURCES/vpn_desk-${VERSION}-bundle.tar.gz" opt usr
cat > "$TOPDIR/SPECS/vpn-desk.spec" <<EOF
# The Flutter plugin .so carries the build machine's RUNPATH; Fedora's rpmbuild rejects it, so skip that check.
%global __brp_check_rpaths %{nil}
%global debug_package %{nil}
Name: vpn-desk
Version: $VERSION
Release: 1
Summary: Browse through Tor from a country you choose
License: Apache-2.0
URL: https://github.com/sandipbera35/vpndesk
BuildArch: $RPMARCH
Requires: gtk3, nftables$EXTRA_RPM
Recommends: polkit
AutoReqProv: no
Source0: vpn_desk-${VERSION}-bundle.tar.gz

%description
VPN Desk starts a bundled Tor client with a strict exit relay in the country you pick,
shows your real and exit locations on a live map and ranks countries by live speed
estimates. An optional system-wide mode routes all TCP and DNS traffic through Tor.

%install
mkdir -p %{buildroot}
tar xzf %{SOURCE0} -C %{buildroot}

%files
%defattr(-,root,root,-)
/opt/vpn_desk
/usr/bin/vpndesk-restore
/usr/share/applications/io.vpndesk.VPNDesk.desktop
/usr/share/metainfo/io.vpndesk.VPNDesk.metainfo.xml
/usr/share/polkit-1/actions/io.vpndesk.net.policy
/usr/share/icons/hicolor/*/apps/vpn_desk.png
EOF
rpmbuild -bb --define "_topdir $TOPDIR" "$TOPDIR/SPECS/vpn-desk.spec" && \
  cp "$TOPDIR"/RPMS/$RPMARCH/*.rpm "$DIST/" || echo "rpmbuild unavailable - install: sudo dnf install rpm-build"

echo "Artifacts:"; ls -la "$DIST"

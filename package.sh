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
[ -x "$BUNDLE/oniondesk" ] || { echo "Missing bundle: run flutter build linux --release && ./bundle_tor.sh"; exit 1; }
VERSION=$(grep '^version:' "$APP/pubspec.yaml" | cut -d' ' -f2 | cut -d+ -f1)
DIST="$APP/dist"
rm -rf "$DIST" "$APP/.pkg"

# ---- common staging ----
STAGE="$APP/.pkg/root"
mkdir -p "$STAGE/opt/oniondesk" "$STAGE/usr/bin" "$STAGE/usr/share/polkit-1/actions" \
         "$STAGE/usr/share/applications" "$STAGE/usr/share/metainfo" \
         "$STAGE/usr/share/icons/hicolor/512x512/apps"
cp -r "$BUNDLE/"* "$STAGE/opt/oniondesk/"
# OnionDesk Browser engine (CEF): the unstripped libcef.so is ~1.3 GB, stripped ~250 MB; keep only the locales the app is translated into.
if [ -f "$STAGE/opt/oniondesk/lib/libcef.so" ]; then
  strip --strip-unneeded "$STAGE/opt/oniondesk/lib/libcef.so"
  ( cd "$STAGE/opt/oniondesk/lib/locales" && ls | grep -vE '^(en-US|en-GB|hi|bn|es|es-419|ar|ru)\.pak$' | xargs -r rm -f )
  # CEF / Chromium licenses must travel with the binary.
  mkdir -p "$STAGE/opt/oniondesk/licenses"
  [ -f "$APP/third_party/webview_cef/third/cef/LICENSE.txt" ] && install -m 644 "$APP/third_party/webview_cef/third/cef/LICENSE.txt" "$STAGE/opt/oniondesk/licenses/CEF-LICENSE.txt"
  install -m 644 "$APP/THIRD_PARTY_NOTICES.md" "$STAGE/opt/oniondesk/licenses/THIRD_PARTY_NOTICES.md"
fi
# The Tor Expert Bundle ships 700/600 files; normal users must be able to read and run everything.
chmod -R u+rwX,go+rX,go-w "$STAGE/opt/oniondesk"
# `oniondesk-restore` on PATH: the display-less "no internet after a crash" command
ln -s /opt/oniondesk/oniondesk-restore "$STAGE/usr/bin/oniondesk-restore"
install -m 644 "$APP/packaging/linux/io.github.sandipbera35.OnionDesk.net.policy" "$STAGE/usr/share/polkit-1/actions/io.github.sandipbera35.OnionDesk.net.policy"
cat > "$STAGE/usr/share/applications/io.github.sandipbera35.OnionDesk.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=OnionDesk
GenericName=Tor VPN alternative
Comment=Browse through Tor from a country you choose
Exec=/opt/oniondesk/oniondesk
Icon=oniondesk
Terminal=false
Categories=Network;Security;
Keywords=Tor;VPN;Onion;Proxy;SOCKS5;Privacy;Anonymity;Security;Censorship;
StartupWMClass=oniondesk
EOF
# AppStream metadata (what software centers show), with this build's version and date
sed -e "s/@VERSION@/$VERSION/" -e "s/@DATE@/$(date +%F)/" "$APP/packaging/linux/io.github.sandipbera35.OnionDesk.metainfo.xml" \
  > "$STAGE/usr/share/metainfo/io.github.sandipbera35.OnionDesk.metainfo.xml"
if command -v appstreamcli >/dev/null; then appstreamcli validate --no-net "$STAGE/usr/share/metainfo/io.github.sandipbera35.OnionDesk.metainfo.xml"; fi
if command -v desktop-file-validate >/dev/null; then desktop-file-validate "$STAGE/usr/share/applications/io.github.sandipbera35.OnionDesk.desktop"; fi
# simple icon: reuse Flutter's asset if present, else skip
ICON_SRC="$APP/packaging/icon.png"
[ -f "$ICON_SRC" ] && cp "$ICON_SRC" "$STAGE/usr/share/icons/hicolor/512x512/apps/oniondesk.png" || true
for SZ in 256 128 64; do
  if [ -f "$ICON_SRC" ] && command -v convert >/dev/null; then
    mkdir -p "$STAGE/usr/share/icons/hicolor/${SZ}x${SZ}/apps"
    convert "$ICON_SRC" -resize ${SZ}x${SZ} "$STAGE/usr/share/icons/hicolor/${SZ}x${SZ}/apps/oniondesk.png"
  fi
done

# ---- .deb ----
mkdir -p "$STAGE/DEBIAN"
cat > "$STAGE/DEBIAN/control" <<EOF
Package: oniondesk
Version: $VERSION
Section: net
Replaces: vpn-desk
Conflicts: vpn-desk
Priority: optional
Architecture: $DEBARCH
Depends: libgtk-3-0, libc6 (>= 2.34), nftables, libnss3, libnspr4, libasound2 | libasound2t64, libatk1.0-0 | libatk1.0-0t64, libatk-bridge2.0-0 | libatk-bridge2.0-0t64, libcups2 | libcups2t64, libdrm2, libgbm1, libxkbcommon0, libxcomposite1, libxdamage1, libxfixes3, libxrandr2, libx11-6, libxext6, libxcb1, libpango-1.0-0, libcairo2, libdbus-1-3, libexpat1$EXTRA_DEB
Recommends: policykit-1 | polkitd, pkexec | policykit-1
Suggests: torsocks
Maintainer: Sandip Bera <sandipbera35@gmail.com>
Homepage: https://github.com/sandipbera35/vpndesk
Description: Free Tor VPN alternative: pick your exit country
 OnionDesk is a free, open-source Tor client with a modern interface. It
 starts a bundled Tor client with a strict exit relay in the country
 you pick, shows your real and exit locations on a live map and ranks countries
 by live speed estimates. An optional system-wide mode routes all TCP and DNS
 traffic through Tor.
EOF
mkdir -p "$DIST"
dpkg-deb --root-owner-group --build "$STAGE" "$DIST/oniondesk_${VERSION}_${DEBARCH}.deb" 2>/dev/null || \
  python3 -c "print('dpkg-deb not available - install: sudo dnf install dpkg')"

# ---- .rpm ----
TOPDIR="$APP/.pkg/rpmbuild"
mkdir -p "$TOPDIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
cd "$STAGE" && tar czf "$TOPDIR/SOURCES/oniondesk-${VERSION}-bundle.tar.gz" opt usr
cat > "$TOPDIR/SPECS/oniondesk.spec" <<EOF
# The Flutter plugin .so carries the build machine's RUNPATH; Fedora's rpmbuild rejects it, so skip that check.
%global __brp_check_rpaths %{nil}
%global debug_package %{nil}
Name: oniondesk
Version: $VERSION
Release: 1
Summary: Free Tor VPN alternative: pick your exit country
Obsoletes: vpn-desk < 99
License: Apache-2.0
URL: https://github.com/sandipbera35/vpndesk
BuildArch: $RPMARCH
Requires: gtk3, nftables, nss, nspr, alsa-lib, atk, at-spi2-atk, cups-libs, libdrm, mesa-libgbm, libxkbcommon, libXcomposite, libXdamage, libXfixes, libXrandr, libX11, libXext, libxcb, pango, cairo, dbus-libs, expat$EXTRA_RPM
Recommends: polkit
Suggests: torsocks
AutoReqProv: no
Source0: oniondesk-${VERSION}-bundle.tar.gz

%description
OnionDesk starts a bundled Tor client with a strict exit relay in the country you pick,
shows your real and exit locations on a live map and ranks countries by live speed
estimates. An optional system-wide mode routes all TCP and DNS traffic through Tor.

%install
mkdir -p %{buildroot}
tar xzf %{SOURCE0} -C %{buildroot}

%files
%defattr(-,root,root,-)
/opt/oniondesk
/usr/bin/oniondesk-restore
/usr/share/applications/io.github.sandipbera35.OnionDesk.desktop
/usr/share/metainfo/io.github.sandipbera35.OnionDesk.metainfo.xml
/usr/share/polkit-1/actions/io.github.sandipbera35.OnionDesk.net.policy
/usr/share/icons/hicolor/*/apps/oniondesk.png
EOF
rpmbuild -bb --define "_topdir $TOPDIR" "$TOPDIR/SPECS/oniondesk.spec" && \
  cp "$TOPDIR"/RPMS/$RPMARCH/*.rpm "$DIST/" || echo "rpmbuild unavailable - install: sudo dnf install rpm-build"

# portable bundle (used by the AUR -bin package and the Flatpak)
tar czf "$DIST/oniondesk-${VERSION}-linux-${FA}.tar.gz" --transform "s,^\.,oniondesk," -C "$STAGE/opt/oniondesk" .

echo "Artifacts:"; ls -la "$DIST"

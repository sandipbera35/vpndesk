#!/usr/bin/env bash
# Build signed apt + dnf/yum repositories from dist/*.deb and dist/*.rpm into site/ (published to GitHub Pages by CI).
# Needs: dpkg-dev apt-utils createrepo-c gnupg; GPG_KEY_ID = a secret key in the keyring (CI imports GPG_PRIVATE_KEY).
# Users then run:  sudo apt install oniondesk   /   sudo dnf install oniondesk   (see README "Install from the repository").
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${GPG_KEY_ID:?set GPG_KEY_ID}"
BASE_URL="${BASE_URL:-https://sandipbera35.github.io/vpndesk}"
OUT=site
rm -rf "$OUT" signed-rpm; mkdir -p "$OUT"
gpg --armor --export "$GPG_KEY_ID" > "$OUT/oniondesk.asc"
gpg --export "$GPG_KEY_ID" > "$OUT/oniondesk.gpg"

# GitHub Pages refuses files over 100 MB and our packages are 130-160 MB (the browser engine), so the packages stay on
# GitHub Releases and only metadata goes to Pages:
#  - apt: a *flat* repository whose files (Release, InRelease, Packages, the .debs) are uploaded to the release tagged "apt"
#    (output dir aptflat/, published by the workflow); users add  deb [signed-by=...] $APT_URL ./
#  - dnf: repodata on Pages; each package's location points (xml:base) at the versioned release download. The metadata
#    records the checksum of the *signed* rpm, so the workflow re-uploads signed-rpm/* over the unsigned release assets.
: "${RELEASE_TAG:?set RELEASE_TAG (e.g. v1.4.0)}"
APT_URL="${APT_URL:-https://github.com/sandipbera35/vpndesk/releases/download/apt}"
RPM_BASE="${RPM_BASE:-https://github.com/sandipbera35/vpndesk/releases/download/$RELEASE_TAG}"

# ---- apt (flat repository) ----
APT=aptflat; rm -rf "$APT"; mkdir -p "$APT"
cp dist/*.deb "$APT/"
(cd "$APT" && dpkg-scanpackages --multiversion . > Packages && gzip -9kf Packages)
(cd "$APT" && apt-ftparchive -o APT::FTPArchive::Release::Origin=OnionDesk -o APT::FTPArchive::Release::Label=OnionDesk \
   -o APT::FTPArchive::Release::Suite=stable -o APT::FTPArchive::Release::Architectures="amd64 arm64" \
   release . > Release)
gpg --batch --yes --default-key "$GPG_KEY_ID" -abs -o "$APT/Release.gpg" "$APT/Release"
gpg --batch --yes --default-key "$GPG_KEY_ID" --clearsign -o "$APT/InRelease" "$APT/Release"

# ---- dnf / yum / zypper ----
for A in x86_64 aarch64; do
  mkdir -p "$OUT/rpm/$A" "$OUT/.rpmwork/$A"
  cp dist/*."$A".rpm "$OUT/.rpmwork/$A/" 2>/dev/null || true
  # sign the packages themselves so dnf can check them (gpgcheck=1) as well as the repo metadata
  rpmsign --define "_gpg_name $GPG_KEY_ID" --define "__gpg /usr/bin/gpg" --addsign "$OUT"/.rpmwork/$A/*.rpm
  # repodata only; the .rpm files are fetched from the release (xml:base), never published on Pages
  createrepo_c --baseurl "$RPM_BASE" --outputdir "$OUT/rpm/$A" "$OUT/.rpmwork/$A"
  gpg --batch --yes --default-key "$GPG_KEY_ID" --detach-sign --armor "$OUT/rpm/$A/repodata/repomd.xml"
  mkdir -p signed-rpm && cp "$OUT"/.rpmwork/$A/*.rpm signed-rpm/
done
cat > "$OUT/oniondesk.repo" <<REPO
[oniondesk]
name=OnionDesk
baseurl=$BASE_URL/rpm/\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=$BASE_URL/oniondesk.asc
REPO

cat > "$OUT/index.html" <<HTML
<!doctype html><meta charset="utf-8"><title>OnionDesk package repository</title>
<h1>OnionDesk package repository</h1>
<p>Free, open-source Tor client with a live circuit visualizer. <a href="https://github.com/sandipbera35/vpndesk">Project page</a>.</p>
<pre>
# Debian / Ubuntu / Mint
curl -fsSL $BASE_URL/oniondesk.gpg | sudo tee /usr/share/keyrings/oniondesk.gpg &gt;/dev/null
echo "deb [signed-by=/usr/share/keyrings/oniondesk.gpg] $APT_URL ./" | sudo tee /etc/apt/sources.list.d/oniondesk.list
sudo apt update &amp;&amp; sudo apt install oniondesk

# Fedora / RHEL
sudo curl -fsSL -o /etc/yum.repos.d/oniondesk.repo $BASE_URL/oniondesk.repo
sudo dnf install oniondesk
</pre>
HTML
rm -rf "$OUT/.rpmwork"
touch "$OUT/.nojekyll"
echo "repo built in $OUT"

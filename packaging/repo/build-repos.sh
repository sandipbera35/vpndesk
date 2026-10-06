#!/usr/bin/env bash
# Build signed apt + dnf/yum repositories from dist/*.deb and dist/*.rpm into site/ (published to GitHub Pages by CI).
# Needs: dpkg-dev apt-utils createrepo-c gnupg; GPG_KEY_ID = a secret key in the keyring (CI imports GPG_PRIVATE_KEY).
# Users then run:  sudo apt install oniondesk   /   sudo dnf install oniondesk   (see README "Install from the repository").
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${GPG_KEY_ID:?set GPG_KEY_ID}"
BASE_URL="${BASE_URL:-https://sandipbera35.github.io/vpndesk}"
OUT=site
rm -rf "$OUT"; mkdir -p "$OUT"
gpg --armor --export "$GPG_KEY_ID" > "$OUT/oniondesk.asc"
gpg --export "$GPG_KEY_ID" > "$OUT/oniondesk.gpg"

# ---- apt (flat "stable main" layout) ----
APT="$OUT/apt"; mkdir -p "$APT/pool/main"
cp dist/*.deb "$APT/pool/main/"
for A in amd64 arm64; do
  mkdir -p "$APT/dists/stable/main/binary-$A"
  (cd "$APT" && dpkg-scanpackages --arch "$A" pool/main > "dists/stable/main/binary-$A/Packages")
  gzip -9kf "$APT/dists/stable/main/binary-$A/Packages"
done
(cd "$APT" && apt-ftparchive -o APT::FTPArchive::Release::Origin=OnionDesk -o APT::FTPArchive::Release::Label=OnionDesk \
   -o APT::FTPArchive::Release::Suite=stable -o APT::FTPArchive::Release::Codename=stable \
   -o APT::FTPArchive::Release::Architectures="amd64 arm64" -o APT::FTPArchive::Release::Components=main \
   release dists/stable > dists/stable/Release)
gpg --batch --yes --default-key "$GPG_KEY_ID" -abs -o "$APT/dists/stable/Release.gpg" "$APT/dists/stable/Release"
gpg --batch --yes --default-key "$GPG_KEY_ID" --clearsign -o "$APT/dists/stable/InRelease" "$APT/dists/stable/Release"

# ---- dnf / yum / zypper ----
for A in x86_64 aarch64; do
  mkdir -p "$OUT/rpm/$A"
  cp dist/*."$A".rpm "$OUT/rpm/$A/" 2>/dev/null || true
  createrepo_c "$OUT/rpm/$A"
  gpg --batch --yes --default-key "$GPG_KEY_ID" --detach-sign --armor "$OUT/rpm/$A/repodata/repomd.xml"
done
cat > "$OUT/oniondesk.repo" <<REPO
[oniondesk]
name=OnionDesk
baseurl=$BASE_URL/rpm/\$basearch
enabled=1
gpgcheck=0
repo_gpgcheck=1
gpgkey=$BASE_URL/oniondesk.asc
REPO

cat > "$OUT/index.html" <<HTML
<!doctype html><meta charset="utf-8"><title>OnionDesk package repository</title>
<h1>OnionDesk package repository</h1>
<p>Free, open-source Tor VPN alternative. <a href="https://github.com/sandipbera35/vpndesk">Project page</a>.</p>
<pre>
# Debian / Ubuntu / Mint
curl -fsSL $BASE_URL/oniondesk.gpg | sudo tee /usr/share/keyrings/oniondesk.gpg &gt;/dev/null
echo "deb [signed-by=/usr/share/keyrings/oniondesk.gpg] $BASE_URL/apt stable main" | sudo tee /etc/apt/sources.list.d/oniondesk.list
sudo apt update &amp;&amp; sudo apt install oniondesk

# Fedora / RHEL
sudo curl -fsSL -o /etc/yum.repos.d/oniondesk.repo $BASE_URL/oniondesk.repo
sudo dnf install oniondesk
</pre>
HTML
touch "$OUT/.nojekyll"
echo "repo built in $OUT"

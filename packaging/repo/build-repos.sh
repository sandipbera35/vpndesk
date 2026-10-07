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
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>OnionDesk: Tor client with a live circuit visualizer, I2P and a private browser</title>
<meta name="description" content="OnionDesk is a free, open-source Tor client for Linux, Windows and macOS: pick an exit country, watch your circuit on a live world map, use I2P, and browse through a built-in private browser. Install with apt or dnf.">
<meta name="keywords" content="Tor client, Tor visualizer, Tor circuit visualizer, Tor exit country, I2P, private browser, privacy, censorship circumvention, SOCKS5, bridges, obfs4, Snowflake, Linux">
<link rel="canonical" href="$BASE_URL/">
<meta property="og:type" content="website">
<meta property="og:title" content="OnionDesk: Tor client with a live circuit visualizer">
<meta property="og:description" content="Free, open-source. Pick an exit country, watch your Tor circuit on a world map, use I2P, and browse with a built-in private browser.">
<meta property="og:url" content="$BASE_URL/">
<style>
:root{color-scheme:light dark;--bg:#0b1220;--fg:#e6edf7;--mut:#9fb0c8;--teal:#2de2c4;--card:#121b2e;--line:#22304a}
@media (prefers-color-scheme:light){:root{--bg:#f6f8fb;--fg:#0f1b2d;--mut:#51627c;--teal:#0f766e;--card:#fff;--line:#d9e1ec}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.6 system-ui,-apple-system,Segoe UI,Roboto,sans-serif}
main{max-width:860px;margin:0 auto;padding:40px 20px 60px}h1{font-size:2rem;margin:.2em 0}h2{margin-top:2em;font-size:1.25rem;color:var(--teal)}
p,li{color:var(--mut)}a{color:var(--teal)}code,pre{font:13px/1.5 ui-monospace,Menlo,Consolas,monospace}
pre{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:14px;overflow:auto;color:var(--fg)}
.card{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:16px 18px;margin:12px 0}
.links a{display:inline-block;margin:4px 12px 4px 0}.small{font-size:.85rem}
</style>
</head>
<body><main>
<h1>OnionDesk</h1>
<p><strong>A free, open-source Tor client with a live circuit visualizer.</strong> Pick an exit country, watch your path (guard, middle, exit) on a world map, use I2P, and open sites in a built-in private browser that reaches the web only through Tor and .i2p sites only through I2P. No account, no subscription, no server run by the author. For Linux (x64 and arm64), Windows and macOS.</p>
<p class="links"><a href="https://github.com/sandipbera35/vpndesk">Source code</a><a href="https://github.com/sandipbera35/vpndesk/releases">Downloads</a><a href="https://github.com/sandipbera35/vpndesk#readme">Documentation</a><a href="https://github.com/sandipbera35/vpndesk/issues">Report a bug or idea</a></p>

<h2>Install on Debian, Ubuntu, Mint</h2>
<pre>curl -fsSL $BASE_URL/oniondesk.gpg | sudo tee /usr/share/keyrings/oniondesk.gpg &gt;/dev/null
echo "deb [signed-by=/usr/share/keyrings/oniondesk.gpg] $APT_URL ./" | sudo tee /etc/apt/sources.list.d/oniondesk.list
sudo apt update &amp;&amp; sudo apt install oniondesk</pre>
<h2>Install on Fedora, RHEL, openSUSE</h2>
<pre>sudo curl -fsSL -o /etc/yum.repos.d/oniondesk.repo $BASE_URL/oniondesk.repo
sudo dnf install oniondesk</pre>
<p class="small">Packages and repository metadata are signed (<a href="oniondesk.asc">public key</a>, fingerprint 8E74 963F 517F A733 7917 6AD0 F870 C80D 58F2 E15B). The packages are about 130 to 160 MB because they include Tor, the I2P router and the browser engine.</p>

<h2>What it does</h2>
<div class="card"><ul>
<li>Tor with a strict exit relay in the country you choose, with live speed estimates per country</li>
<li>Live circuit visualizer and world map, leak test, bridges (obfs4, Snowflake, meek), ad blocker</li>
<li>I2P tab (beta) with a bundled i2pd router and per-app split tunneling</li>
<li>OnionDesk Browser (beta): tabs and full view inside the app, no direct connection</li>
<li>Optional system-wide mode on Linux that is designed to send all TCP and DNS traffic through Tor</li>
</ul></div>

<h2>Important</h2>
<div class="card"><p>OnionDesk is an independent project, <strong>not affiliated</strong> with the Tor Project, the I2P projects or Google. It is not a VPN service and <strong>does not guarantee anonymity</strong>; Tor and I2P are volunteer networks, and the browser, I2P tab and system-wide mode are beta and not independently audited. Provided "as is" under the Apache License 2.0, without warranty. You are responsible for following the laws that apply to you. "Tor" and the onion logo are trademarks of The Tor Project, Inc.</p>
<p class="links"><a href="https://github.com/sandipbera35/vpndesk/blob/main/PRIVACY.md">Privacy policy</a><a href="https://github.com/sandipbera35/vpndesk/blob/main/LEGAL.md">Legal notices</a><a href="https://github.com/sandipbera35/vpndesk/blob/main/SECURITY.md">Security policy</a><a href="https://github.com/sandipbera35/vpndesk/blob/main/THIRD_PARTY_NOTICES.md">Third-party notices</a><a href="https://github.com/sandipbera35/vpndesk/blob/main/LICENSE">License</a></p></div>

<p class="small">Testers welcome: please report what works and what does not on your distribution. Contact: <a href="mailto:sandipbera35@outlook.com">sandipbera35@outlook.com</a>. &copy; Sandip Bera.</p>
</main></body></html>
HTML
rm -rf "$OUT/.rpmwork"
touch "$OUT/.nojekyll"
echo "repo built in $OUT"

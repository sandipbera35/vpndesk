<div align="center">

# 🛡️ OnionDesk

**A free, open-source Tor VPN alternative: pick an exit country and browse anonymously. No account, no subscription.**

A modern desktop app that starts a bundled [Tor](https://www.torproject.org) client with a **strict exit in the country you choose**, shows your real and exit locations on a live map, ranks countries by **live speed estimates**, and can optionally route **every app on your computer** through Tor.

[![Release](https://img.shields.io/github/v/release/sandipbera35/vpndesk?color=2DE2C4&label=release)](https://github.com/sandipbera35/vpndesk/releases)
[![License](https://img.shields.io/badge/license-Apache--2.0-7C9CFF)](LICENSE)
![Flutter](https://img.shields.io/badge/built%20with-Flutter-02569B?logo=flutter&logoColor=white)
![Platform](https://img.shields.io/badge/Linux-x64%20%7C%20arm64-FFC857?logo=linux&logoColor=black)
![Tor](https://img.shields.io/badge/powered%20by-Tor-7D4698?logo=torproject&logoColor=white)

[Download](https://github.com/sandipbera35/vpndesk/releases) · [Features](#-features) · [How it works](#-how-it-works) · [System-wide mode](#-system-wide-mode-linux) · [Build from source](#-build-from-source) · [FAQ](#-faq--limitations)

</div>

---

## ✨ Features

| | |
|---|---|
| 🌍 **Country exits** | Choose from 178 countries (the ~50 that currently have Tor exit relays are selectable; the rest are dimmed). Tor is configured with `ExitNodes` pinned to the fastest relay there and `StrictNodes 1`, so you never silently fall back to another country. |
| ⚡ **Live speed estimates** | Every minute the app measures real round-trip time to relays in each country, caps it by relay bandwidth, and calibrates against speeds you have actually measured through Tor. The sidebar shows `~Mbps · ms` per country, always up to date. |
| 🤖 **Auto (fastest) mode** | One click and OnionDesk always uses the highest-speed location, switching only when another is **≥ 25 % faster** and at most every **5 minutes**, so it never flaps. |
| 🔁 **Leak-free location switching** | Changing country edits the live Tor config instead of restarting it, then closes the old circuits (through Tor's loopback-only, cookie-protected control port) so open browser connections move to the new exit too. The proxy never drops, so your real IP is not exposed mid-switch. |
| 🗺️ **Live world map** | Highlights the selected country and pins your **real IP** and **exit IP** at their locations with animated pins, ripples and a flowing link between them. Works fully offline (bundled Natural Earth data). |
| 🛡️ **System-wide mode** *(optional, Linux)* | Redirects **all** TCP and DNS from **every app** into Tor with an `nftables` transparent proxy, on GNOME, KDE or any desktop. Asks for administrator permission once, in the app. |
| 📦 **Nothing else to install** | Tor is bundled inside every package. Install the app and it works. |
| 🎨 **Polished, responsive UI** | Glass-style dark interface that adapts from a small window to a large one, with no scroll bars, mac-style window controls and an animated About page. |
| 🆕 **New identity & auto-rotate** | One click (or every 5–60 minutes) switches to a different relay in the same country and moves your open browser connections to it. The proxy never drops, so nothing goes direct. |
| 🧪 **Built-in leak test** | Checks that sites see a Tor exit and not your real IP, that names are resolved inside Tor, and whether apps that ignore the proxy are covered. WebRTC needs a browser setting (the app tells you which). |
| 🚫 **Exclude countries** | Never exit from countries you choose (presets: Five/Nine/Fourteen Eyes). Auto skips them and they cannot be selected. |
| 🧭 **Circuit visualizer** | Draws the guard → middle → exit path on the map and lists your active circuits (relay countries, and which sites ride each one; click one to highlight it). Everything comes from Tor's own control port, so it works offline and where Tor Project web services are blocked. Zoom with the wheel or +/− and drag to pan to follow the route. Countries only, never a street address. |
| 🌉 **Bridges** | obfs4, Snowflake, meek or your own bridge lines for networks that block Tor. Uses the `lyrebird` transport bundled with Tor (Linux x64, Windows, macOS). Not available on Linux arm64 yet, and not combinable with System-wide mode. |
| 🚀 **Start at login / connect on launch** | Optional, off by default (Linux, Windows, macOS). |
| 🧩 **Run an app through OnionDesk** | Pick an installed app (Linux `.desktop` files incl. Flatpak/Snap, macOS `/Applications`, Windows Start Menu) and start it with the proxy set; browsers get a private profile with remote DNS and WebRTC off. On Linux, `torsocks` (if installed) forces apps that ignore proxy settings. Windows/macOS cannot force such apps; use System-wide mode (Linux) for full coverage. True per-app kernel routing (WFP, network namespaces, Network Extensions) is not implemented. |
| ⭐ **Everyday comfort** | Favorite countries, copy buttons for the IPs and the SOCKS5 address, shortcuts (Ctrl/Cmd+K search, Ctrl/Cmd+Enter connect, Ctrl/Cmd+N new identity), a session timer with data counters, a "Reconnect to …" chip, desktop notifications when the connection drops or your exit changes, settings export/import and a Light theme. |
| 🧅 **I2P tab** (beta) | A second tab runs the bundled [`i2pd`](https://i2pd.website) router (an installed one is used if a build lacks it) for `.i2p` sites and I2P apps: Start/Stop, live status, copyable proxy addresses, and **split tunneling**: add the apps you want and launch them with the I2P proxy set. Changes no system setting, never touches an I2P router it did not start. It is a separate network: no country exits and no speed-up for normal sites (use the Tor tab for that). |
| 🌐 **OnionDesk Browser** (beta) | A browser inside the app, on the Chromium Embedded Framework: modern sites, JavaScript, VP8/VP9/AV1 video, tabs and a full view. It uses whatever is connected (Tor for the web, I2P for `.i2p`, both together) through one local proxy and refuses everything else, so it cannot leak a direct connection. Adds ~250 MB; no H.264/AAC (open-source Chromium build); not on Windows arm64. |
| 🧹 **Clean exit** | Closing OnionDesk (even a hard kill) stops everything it started: Tor, i2pd and the browser helpers. A small detached guard reaps an orphaned `i2pd` on the next start. |
| 🔔 **Update notice** | Checks GitHub releases (can be turned off in More). Nothing is installed automatically. |
| 🌐 **6 languages** | English, हिन्दी, বাংলা, Español, العربية (right-to-left), Русский. First-draft translations; corrections welcome. |
| 🔒 **No accounts, no telemetry** | The app only talks to the Tor network, the Tor Project relay directory, IP-lookup and speed-test services. |

---

## 📥 Install

### Install from the repository (recommended: updates arrive with your system updates)

```bash
# Debian / Ubuntu / Mint
curl -fsSL https://sandipbera35.github.io/vpndesk/oniondesk.gpg | sudo tee /usr/share/keyrings/oniondesk.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/oniondesk.gpg] https://sandipbera35.github.io/vpndesk/apt stable main" | sudo tee /etc/apt/sources.list.d/oniondesk.list
sudo apt update && sudo apt install oniondesk

# Fedora / RHEL / openSUSE
sudo curl -fsSL -o /etc/yum.repos.d/oniondesk.repo https://sandipbera35.github.io/vpndesk/oniondesk.repo
sudo dnf install oniondesk

# Arch / Manjaro (AUR)
yay -S oniondesk-bin
```

Package names are lowercase (`oniondesk`). After the one-time repository setup, `sudo apt install oniondesk` / `sudo dnf install oniondesk` work directly.

### Or download a package manually

Download the package for your machine (Linux `.deb`/`.rpm`/`.tar.gz`, macOS `.dmg`, Windows `-setup.exe`) from the [**Releases**](https://github.com/sandipbera35/vpndesk/releases) page:

| Your system | Package |
|---|---|
| Debian / Ubuntu / Mint, Intel/AMD | `oniondesk_<version>_amd64.deb` |
| Debian / Ubuntu / Mint, ARM64 | `oniondesk_<version>_arm64.deb` |
| Fedora / RHEL / openSUSE, Intel/AMD | `oniondesk-<version>-1.x86_64.rpm` |
| Fedora / RHEL / openSUSE, ARM64 | `oniondesk-<version>-1.aarch64.rpm` |

```bash
# Debian / Ubuntu  (use the file name you downloaded)
sudo apt install ./oniondesk_<version>_amd64.deb

# Fedora / RHEL / openSUSE
sudo dnf install ./oniondesk-<version>-1.x86_64.rpm
```

GNOME Software / Discover may label a locally downloaded package "third party" (it isn't from a signed repository); that is expected.

Always take the **latest** release. (`v1.0.1` installed files with the wrong owner and `v1.0.2`–`v1.0.5` shipped Tor's files unreadable by normal users, so Connect failed; use `v1.0.6` or newer.)

Then launch **OnionDesk** from your application menu (or run `/opt/oniondesk/oniondesk`).

> **Requirements:** a desktop Linux with GTK 3. `nftables` and `polkit` are only needed for the optional [system-wide mode](#-system-wide-mode-linux); the packages declare them.

### Platform status

| Platform | Status |
|---|---|
| 🐧 Linux x86_64 | ✅ Built and tested |
| 🐧 Linux arm64 | ✅ Built by CI (Tor compiled from source); not yet run on real hardware |
| 🍎 macOS (Apple Silicon + Intel) | 🧪 `.dmg` built by CI; not yet run on real hardware. Not notarized: open **System Settings → Privacy & Security → Open Anyway**, or run `xattr -cr /Applications/OnionDesk.app` |
| 🪟 Windows x64 + arm64 | 🧪 Setup `.exe` built by CI; not yet run on real hardware. Windows may show a SmartScreen warning (unsigned): **More info → Run anyway**. arm64 bundles the x64 `tor.exe`, which runs under Windows' emulation |

Windows and macOS use the app's local SOCKS5 proxy mode (it sets the OS proxy and restores your previous one, also after a crash on the next start). System-wide mode is Linux-only. The in-app uninstaller (About > Uninstall) is available on Linux and Windows; on macOS drag the app to the Trash.

---

## 🧭 How it works

```mermaid
flowchart LR
    A[You pick a country<br/>or enable Auto] --> B[Onionoo directory:<br/>fastest exit relay<br/>+ guard relays]
    B --> C[torrc written:<br/>ExitNodes = that relay<br/>StrictNodes 1]
    C --> D[Bundled tor starts<br/>guard → middle → exit]
    D --> E{Mode}
    E -->|Default| F[SOCKS5 proxy<br/>127.0.0.1:9050<br/>+ system proxy]
    E -->|System-wide| G[nftables redirects<br/>all TCP + DNS to Tor]
    F --> H[Your traffic leaves<br/>from the exit country]
    G --> H
```

1. **Choose a location.** Type a country, click one in the sidebar, or turn on **Auto**.
2. **Find the best relays.** The app asks the Tor Project's Onionoo directory for the highest-bandwidth exit in that country and a set of fast guards, so the single shared circuit is as quick as Tor allows.
3. **Start Tor.** It writes a `torrc` that pins that exit with `StrictNodes 1` and launches the bundled `tor`. Tor builds a three-hop circuit: *guard → middle → exit*. If you close the app, Tor exits with it (`__OwningControllerProcess`).
4. **Route your traffic.** Tor opens a local **SOCKS5** proxy on `127.0.0.1:9050`. The app also points your desktop's system proxy at it (GNOME) so proxy-aware apps use it automatically. In [system-wide mode](#-system-wide-mode-linux) a firewall rule covers every app.
5. **Verify.** The exit IP is looked up *through Tor* and shown beside your real IP, with both pinned on the map.
6. **Stay fast.** Estimates refresh every minute; with Auto on, the app moves to a clearly faster location without ever dropping the proxy.
7. **Disconnect.** Tor stops and your proxy / firewall settings are restored.

### Speed estimation

Tor throughput is dominated by round-trip distance to the exit region and capped by the exit relay's bandwidth. Rather than hard-coding a number, the app:

- probes the **real TCP round-trip time** to each country's top exit relays, live,
- caps the result by the relay's observed bandwidth,
- derives its calibration constant **from speeds you have really measured through Tor** (median of *speed × RTT*), so the estimates adapt to *your* connection,
- replaces an estimate with your measured value as soon as you connect to that country.

---

## 🛡️ System-wide mode (Linux)

By default OnionDesk is a **local SOCKS5 proxy**: only apps that honour the system proxy go through Tor. Many tools (CLI programs, games, torrent clients) ignore it. **System-wide mode** closes that gap.

Turn it on with the **System-wide** switch in the main card. The app explains the change, and when you press **Connect** your system shows one standard administrator-password prompt.

| What it does | How |
|---|---|
| Sends **all TCP** to Tor | `nftables` NAT rule redirects outgoing TCP to Tor's `TransPort` (9040) |
| Sends **all DNS** to Tor | UDP port 53 redirected to Tor's `DNSPort` (5353): no DNS leaks |
| Keeps Tor itself reachable | Tor runs as a dedicated `oniondesk` system user that is excluded from the redirect |
| Blocks what Tor can't carry | Other UDP (QUIC/HTTP3, games, VoIP) and **IPv6** are dropped, so nothing leaks around Tor |
| Leaves your LAN alone | `192.168.x.x`, `10.x.x.x`, `172.16/12`, link-local and DHCP stay direct |
| **Fail-closed** | If Tor crashes, traffic stays **blocked** and a red **Restore** banner appears; nothing leaks. Closing the app or pressing Disconnect restores normal networking automatically |

It works the same on GNOME, KDE and any other Linux desktop because it uses the firewall, not a desktop-specific proxy setting.

**Security design**
- The privileged part is a tiny shell helper, `oniondesk-net`, launched through **polkit (`pkexec`)**. It is installed root-owned at `/opt/oniondesk/oniondesk-net`.
- It takes **no file paths from the caller**: it finds Tor next to itself and accepts only an **allowlist of `torrc` directives** from the unprivileged app.
- Tor itself never runs as root; the app talks to it over a password-protected control port bound to `127.0.0.1`.

> ⚠️ Running `sudo systemctl restart nftables` (which flushes the whole ruleset) while connected removes the firewall table and will leak. Press **Disconnect** first.

---

## 🗑️ Uninstall

Open **About** and press **Uninstall…** (Linux). OnionDesk asks you to confirm, disconnects and restores your network, then removes itself: the app and menu entry, the system-wide helper with its firewall table and the `oniondesk` system user, and (if you leave the box ticked) your settings in `~/.config/oniondesk`. You are asked for administrator permission once; if you decline, nothing is removed. Tor Browser and other Tor installs are never touched.

- Installed from a `.deb`/`.rpm`: fully removed. Developer install (`install.sh`): removed without an admin prompt. Running from a build folder: only your settings are removed, the folder is left alone.
- Preview the whole flow without removing anything: `ONIONDESK_UNINSTALL_DRYRUN=1 oniondesk`.
- Without the app: `sudo apt remove oniondesk` / `sudo dnf remove oniondesk`.

## 🩹 Troubleshooting: no internet after a crash

OnionDesk records what it changes in `~/.local/state/oniondesk/session.json` *before* changing it, and undoes it exactly
(your previous proxy settings are put back, not just "none") in every case:

| What happened | What puts things back |
|---|---|
| Disconnect, close button, `SIGTERM` / `SIGINT` / `SIGHUP`, window closed | The app itself, then deletes the journal |
| App force-quit / `kill -9` / crash | A small detached guard (`oniondesk-restore --watch`) notices within about a second and restores everything; Tor also exits on its own because the app owns it |
| Whole session killed, power cut, guard also gone | Next launch runs the same recovery first and shows "Recovered from an unclean exit" |

A tor process is only stopped if its pid, executable and start time match what the app recorded. Your own Tor Browser
or `tor` service is never touched.

**No internet and the app won't open?** Run this in a terminal (it needs no window and no display):

```bash
oniondesk-restore            # installed by the .deb/.rpm; from a source build: packaging/linux/oniondesk-restore
oniondesk-restore --net      # also force-remove the system-wide firewall table (asks for administrator permission)
```

Manual fallbacks, if the script itself is unavailable:

```bash
# proxy (GNOME)
gsettings set org.gnome.system.proxy mode 'none'
# stuck system-wide firewall table (the table is called "oniondesk", family "inet")
sudo nft list tables
sudo nft delete table inet oniondesk
# orphaned tor owned by you (look, then kill only the PID you recognise as OnionDesk's)
pgrep -a tor
```

> Speed expectations: Tor is slower than a commercial VPN by design (three hops run by volunteers). On the author's connection (Germany exit, Linux) measured throughput is a few Mbps on one stream and roughly 10 to 15 Mbps across several streams, and it varies a lot from one circuit to the next. Measured results of every tuning experiment, including the rejected ones, are in `docs/bench/DECISIONS.md`.

## 🧱 Tech stack (all open source)

| Component | Purpose | License |
|---|---|---|
| [Tor](https://www.torproject.org) | Anonymity network and the `tor` client (official Tor Expert Bundle; compiled from source on arm64) | BSD-3-Clause |
| [Flutter](https://flutter.dev) / Dart | UI toolkit and language | BSD-3-Clause |
| [libevent](https://libevent.org), [OpenSSL](https://www.openssl.org), [zlib](https://zlib.net) | Libraries bundled with Tor | BSD-3 / Apache-2.0 / zlib |
| [bitsdojo_window](https://pub.dev/packages/bitsdojo_window) | Frameless window with custom controls | MIT |
| [socks5_proxy](https://pub.dev/packages/socks5_proxy) | Sends the app's own requests through Tor | MIT |
| [i2pd](https://i2pd.website) | The I2P router bundled for the I2P tab (run as a separate program) | BSD-3-Clause |
| [Chromium Embedded Framework](https://bitbucket.org/chromiumembedded/cef) via [webview_cef](https://github.com/hlwhl/webview_cef) | Engine of OnionDesk Browser (patched plugin in `third_party/`) | BSD-3-Clause / Apache-2.0 |
| [proxychains-ng](https://github.com/rofl0r/proxychains-ng) | Forces apps through I2P on Linux (separate preload library) | GPL-2.0+ |
| [Natural Earth](https://www.naturalearthdata.com) | Country outlines for the offline map | Public domain |
| [Onionoo](https://metrics.torproject.org/onionoo.html) | Tor Project relay directory API | Public service |
| [nftables](https://netfilter.org/projects/nftables/) | Firewall used by system-wide mode | GPL-2.0 (system package) |

---

## 🗂️ Project layout

```
lib/
  main.dart          UI, connection logic, speed estimation, auto mode
  platform.dart      All OS-specific code (paths, tor lookup, proxy, control port, helper)
  world_map.dart     Offline animated world map (CustomPainter)
  about_page.dart    Animated About page
  i2p.dart, i2p_page.dart, launch_via_i2p.dart   I2P tab: bundled i2pd router, status, split tunneling
  browser_page.dart, browser_mux.dart, browser_nav.dart   OnionDesk Browser (CEF) and its Tor/I2P-only proxy
  process_guard.dart Stops i2pd when the app closes or dies (no orphans)
third_party/webview_cef/   Patched CEF plugin (see ONIONDESK_PATCHES.md)
assets/              world.json (country shapes), profile.jpg
packaging/
  linux/             oniondesk-net helper + polkit policy
  flatpak/ snap/     Manifests (experimental)
fetch_tor.sh         Download + verify the official Tor Expert Bundle
build_tor_linux.sh   Build Tor from source (Linux arm64)
bundle_tor.sh        Put Tor + helper into the Linux release bundle
package.sh           Build .deb and .rpm
package_mac.sh       Build a .dmg (macOS, untested)
windows_installer.iss  Inno Setup script (Windows, untested)
.github/workflows/   CI: builds Linux x64 + arm64 packages on every v* tag
```

---

## 🔧 Build from source

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install/linux) (stable) and the GTK 3 development files (`libgtk-3-dev` / `gtk3-devel`), plus `clang`, `cmake` and `ninja`.

```bash
git clone https://github.com/sandipbera35/vpndesk.git
cd oniondesk

flutter pub get
flutter build linux --release

./bundle_tor.sh                # bundle Tor + the system-wide helper
build/linux/x64/release/bundle/oniondesk   # run it

./package.sh                   # optional: build .deb and .rpm into dist/
```

`./install.sh` installs the local build as a **OnionDesk (dev)** menu entry for development; it refuses to run if you installed the package (a second copy would shadow it). `./install.sh --uninstall` removes it.

On **arm64**, `bundle_tor.sh` compiles Tor from source, which needs `libevent-dev`, `libssl-dev` and `zlib1g-dev`.

### Releases

Pushing a tag such as `v1.0.0` runs the GitHub Actions workflow, which builds the Linux x64 and arm64 packages and attaches them to the release.

---

## ❓ FAQ & limitations

**Is this a real VPN?**
Not by default. It is a Tor-based proxy with country-pinned exits. With **System-wide mode** on Linux it routes the whole machine, which behaves like a VPN for TCP and DNS.

**Why is it slower than a commercial VPN?**
Traffic goes through three volunteer-run Tor relays, which trades speed for anonymity. The speed numbers shown are estimates until you connect and measure.

**Why do some apps, games or video calls stop working in system-wide mode?**
Tor carries TCP only. UDP (QUIC/HTTP3, many games, VoIP) is blocked on purpose so it can't leak. Browsers fall back to HTTPS automatically.

**Can the exit relay see my traffic?**
The exit operator can see unencrypted traffic, exactly as with any Tor exit. Prefer HTTPS.

**A country shows "no exits".**
Tor currently has no usable exit relays there. Pick another location.

**Does it collect data?**
No accounts, no analytics, no telemetry.

**Honest status:** Linux x86_64 has been built and exercised end to end, including system-wide mode (verified live on Fedora: traffic goes through Tor, DNS and the LAN behave, QUIC/IPv6 are blocked, and after a hard kill of the helper and Tor the stuck firewall table is removed by `oniondesk-restore --net`). Linux arm64 builds in CI but hasn't been run on hardware; macOS and Windows are scaffolded but untested. Keep `oniondesk-restore` in mind if anything ever misbehaves.

---

<sub>🤖 Built with AI assistance ([Claude Code](https://claude.com/claude-code), [OpenCode](https://opencode.ai)); directed, reviewed and tested by the author.</sub>

---

## 👤 Author

<img src="assets/profile.jpg" width="96" align="left" style="border-radius:50%" alt="Sandip Bera">

**Sandip Bera**<br><br>

[![GitHub](https://img.shields.io/badge/GitHub-sandipbera35-181717?logo=github)](https://github.com/sandipbera35)
[![Website](https://img.shields.io/badge/Website-sandipbera.in-2DE2C4)](https://sandipbera.in)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-sandipbera-0A66C2?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/sandipbera)

## 📄 License

Licensed under the [Apache License 2.0](LICENSE). Tor and the other bundled components keep their own licenses (see the table above).

<div align="center">

⭐ If you find this useful, consider starring the repo.

</div>

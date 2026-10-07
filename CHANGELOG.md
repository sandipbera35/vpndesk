# Changelog

## Highlights
- **Uninstall from the app** (Linux): About > Uninstall. Asks to confirm, then removes the app, its system helper and (optionally) your settings, with an animated progress page. Administrator permission is asked once; cancelling removes nothing. Set `VPNDESK_UNINSTALL_DRYRUN=1` to preview the flow without removing anything.

## 1.4.1 (2026-10-07)

Privacy and legal documents, in the app and in the repository; Linux package repositories (apt, dnf).

- **Package repositories:** signed apt and dnf repositories (setup on https://sandipbera35.github.io/vpndesk/). The packages stay on GitHub Releases (over Pages' size limit); the page and repository metadata are on GitHub Pages.
- **Privacy & legal inside the app:** About > Legal & privacy and Settings > Privacy & legal open a reader with the Privacy policy, Legal notices (terms of use), Security policy and Licenses, loaded from the same files as the repository (`PRIVACY.md`, `LEGAL.md`, `SECURITY.md`, `THIRD_PARTY_NOTICES.md`, `LICENSE`), so they work offline and cannot drift. English only. New `LEGAL.md`.
- **Legal and privacy pass:** new `PRIVACY.md` (every outside service the app contacts and what it can see, what is stored locally) and `SECURITY.md` (reporting, limits of the protection); About page has a Legal & privacy section; README has legal notices (no affiliation, no warranty or anonymity guarantee, lawful use, trademarks) and no longer shows the "powered by Tor" badge (it used the Tor logo); absolute claims ("nothing leaks", "never drops", "always restored") were rewritten as design intent; package texts say it is not a VPN service. The system-wide confirmation dialog lost its non-English translation (its English text changed).

## 1.4.0 (2026-10-07)

I2P tab (BETA, bundled i2pd, split tunneling), OnionDesk Browser (BETA, CEF), clean exit, redesigned About page.

- **About page:** new cards for OnionDesk Browser, I2P and I2P split tunneling; the modes grid is now equal-height rows (no more uneven cards); the AI note is a single small line; licences list i2pd, CEF, webview_cef and proxychains-ng.
- **Browser tabs:** typing and tooltips no longer break after opening a site in another tab (the plugin's hidden pages kept the keyboard/IME and stale tooltips).

- **Close cleanup:** closing OnionDesk (even a hard kill) now leaves nothing running. A small detached guard (`lib/process_guard.dart`) stops `i2pd` once the app is gone, and on the next start any `i2pd` using OnionDesk's data directory is reaped. Verified on Linux with SIGKILL and SIGTERM; the Windows guard is unverified.
- **Browser, slimmer strips:** the tab strip (30 px), toolbar (34 px) and address bar (30 px) are smaller, with the "via I2P / Tor" label at the far right and an "Opening <site>" overlay while a page has not painted yet.
- **Browser, light theme:** web pages are no longer colour-inverted in light mode (the page area gets the light filter a second time, which cancels it). Written, not yet built or verified.

- **About: contact and contribute.** The About page now has `sandipbera35@outlook.com` with one-click mails for a bug report, an idea, a suggestion, or joining as a contributor (subject filled in), and a copy button.

- **OnionDesk Browser (BETA, new tab)**: a real browser inside the app, on the Chromium Embedded Framework (CEF 149): modern sites, JavaScript, HTML5 video (VP8/VP9/AV1, no H.264/AAC: the open-source CEF build has no proprietary codecs). Tabs (new tab, close, switch; Ctrl+T / Ctrl+W), a full view that makes the page fill the app window (F11 / Esc), zoom (Ctrl +/-/0), back / forward / reload / stop, and an address bar that opens `name.i2p` directly and never searches Google (DuckDuckGo through Tor, or an I2P search engine when only I2P is connected). It uses whatever is connected, automatically: all its traffic goes through one local HTTP proxy inside the app that sends `.i2p` to I2P (through i2pd's own proxy: I2P user agent, jump pages, helpful errors) and everything else to Tor, and refuses anything else (fail closed: no direct connection, no local DNS, WebRTC without direct UDP, no Google background traffic). The engine's insecure defaults (web security off, no sandbox) were removed in a patched copy of the `webview_cef` plugin (`third_party/webview_cef`); the Chromium sandbox is on, and the browser warns when a system cannot run it. Cost: about +250 MB per platform (Linux packages grow to ~135 MB; the first build downloads ~650 MB); not available on Windows arm64 (the x64 installer runs there under emulation); Linux x64 built and exercised, Windows/macOS configured but unverified. A pure-Flutter renderer without Chromium was built and tested first and replaced by CEF at the user's request (it had no JavaScript or video).
- **I2P tab** (next to Tor in the title bar): start and stop your own private `i2pd` router, see status (routers known, network state, tunnels built, bandwidth) and copy the HTTP (`127.0.0.1:4444`) and SOCKS5 (`127.0.0.1:4447`) proxy addresses. It uses an `i2pd` you install yourself (not bundled); OnionDesk never touches the system service or an I2P router it did not start, changes no OS proxy or firewall setting, and stops i2pd when the app closes (an orphan after a kill is reaped on the next start). Relaying other people's traffic is off by default. **Split tunneling for I2P:** add the programs you want (picked from your installed apps or typed), then press Launch: each starts with I2P already set up, so you never configure a proxy (browsers get a private profile preconfigured for I2P). On Linux the app is also **forced** through I2P with a bundled preload shim (proxychains-ng's `libproxychains4.so`), so even programs that ignore proxy settings use I2P; Flatpak/Snap, statically linked and Go programs are not covered. Windows and macOS have no equivalent, so there only apps that honour proxy settings are covered. The rest of the computer is untouched. There is deliberately no system-wide I2P mode (I2P reaches only .i2p sites).
- **I2P, round two:** the I2P tab is marked **BETA / Experimental** (a small, slow network; many sites are offline). The status is **green** once fully connected, and while joining it shows a spinning progress ring with a percentage (same style as Tor's). A fresh router now starts with ~1500 known `.i2p` names (merged from the I2P project seed and the inr.i2p / notbob.i2p / stats.i2p public lists) instead of 69, keeps its address book growing from those lists, and no longer caps itself at i2pd's default 32 KB/s. Measured on 4 routers x 3 sites x 2 rounds: once warm, popular sites answer in 1 to 6 seconds, and tunnel length / bandwidth changes made no consistent difference, so tunnels stay at the default (3 hops, for privacy). Of 69 well-known sites only ~25 were reachable at all in a 5-minute-old router: most slowness is sites being offline and a young router, not the app. The tab says "warming up" for the first 5 minutes.
- **First-start fix:** a fresh i2pd knows no .i2p names for many minutes ("host not found" for stats.i2p, i2pforum.i2p...). A seed address book from the I2P project is now bundled and copied in on first start, so well-known sites work at once.
- **i2pd is bundled** (nothing to install): official release on Windows/macOS, built from source with static libraries on Linux, with the reseed certificates. If a bundle is missing the tab falls back to an installed i2pd. The Tor tab and everything in it are unchanged. I2P has no country exits and does not speed up normal websites.

## 1.3.0 (2026-10-07)

- **Favorites:** star a country to pin it to the top of the list.
- **Copy buttons** on the Real IP / Exit IP cards and a one-click copy of the SOCKS5 address (`127.0.0.1:9050`, with a Firefox/curl hint).
- **Keyboard shortcuts:** Ctrl/Cmd+K focus the country search, Ctrl/Cmd+Enter connect or disconnect, Ctrl/Cmd+N new identity.
- **Reconnect chip:** after disconnecting, one tap returns to the location you used last.
- **Session chip:** time connected and data down/up through Tor (read from Tor's control port once a minute; the clock repaints only its own label).
- **Desktop notifications** (on by default, Settings): connection dropped, auto-rotate or Auto-fastest changed your exit. A deliberate disconnect or quit never notifies.
- **Backup:** export/import settings as a `.json` file you choose in a file dialog. Bridge lines are never exported; an import only applies known options of the right type and is refused while connected.
- **Uninstall** moved from About to Settings. About no longer shows a profile picture; it has a short professional bio instead.
- **Windows uninstall fix (untested on Windows):** the in-app uninstaller is now started through a small batch script that waits for the app to exit and logs to `%TEMP%\oniondesk-uninstall.log` (a hidden PowerShell was dying with the app, so nothing was uninstalled).
- **About:** shows the app version, the bundled Tor version and the bridge mode.
- **Light theme** (Settings > Light theme, a toggle). It is the dark design run through a colour filter, so every screen follows; it costs a little extra GPU work while it is on.

## 1.2.0 (2026-10-06)

Every feature below was run end to end on the real app (clean config, real Tor): new identity and auto-rotate (19 exit changes in 4 min with a 15 s test interval, real IP never seen), bridges obfs4/Snowflake/meek/custom (connected; injected torrc lines refused), exclude countries (refused when selected, avoided by Auto), ad blocker (blocked domains refused, normal sites work), split tunneling (launcher and `torsocks` verified against a control).

- **New identity** button and **auto-rotate** (5/10/30/60 min): new relay in the same country, open connections move too.
- **Leak test** dialog; **exclude countries** (with Five/Nine/Fourteen Eyes presets); **circuit view** on the map (guard, middle, exit by country).
- **Start at login** and **connect on launch** (opt-in); **update notice** (opt-out); **Run an app through OnionDesk** (Linux/macOS); optional download of the full ad-block list (StevenBlack, MIT; see THIRD_PARTY_NOTICES.md).
- **Bridges** (obfs4, Snowflake, meek, custom) via the bundled `lyrebird`; **circuit visualizer** with a list of active circuits and their sites; **installed-apps picker** for "Run an app through OnionDesk".
- **Map:** zoom with the mouse wheel, drag to pan, double-click to zoom in, +/−/reset buttons (vector map, stays sharp); the expand button makes it fill the window. **Connecting** now shows an animated progress ring with the bootstrap percentage and phase, and a completion burst when the circuit is ready.
- **Languages:** हिन्दी, বাংলা, Español, العربية (RTL), Русский (first drafts; country names stay English).
- **Fix:** split tunneling with `torsocks` installed no longer also sets the proxy variables (torsocks refuses localhost, so programs that read them failed).
- Not included yet: tray icon (needs an indicator library on Linux), per-app exclusion in System-wide mode.

## 1.1.4 (2026-10-06)

- **Windows: in-app Uninstall** (About > Uninstall): confirm, then it restores your proxy, optionally deletes `%APPDATA%\oniondesk`, and runs the Inno Setup uninstaller after the app exits.
- **Windows installer:** closes a running OnionDesk, stops only its own bundled Tor (never Tor Browser's) and clears a leftover OnionDesk proxy when uninstalled from Settings > Apps.
- Linux and macOS are unchanged.

## 1.1.3 (2026-10-06)

- **Fix:** switching country now also moves connections a browser already has open (they kept using the old exit, so sites like iplocation.io showed the old IP). Old circuits are closed through Tor's loopback-only control port (cookie auth, now on all platforms); the proxy stays up, so nothing goes direct.
- **Fix:** the map exit pin follows Tor's country when IP-geolocation databases disagree, with a note on the Exit IP card; Singapore, Hong Kong and Taiwan (no outline in the map data) now get a pin.
- **New:** all 178 countries are listed; countries without exit relays are dimmed and say so when clicked.

## 1.1.2 (2026-10-06)

- **Fix:** the per-country speed estimates and ping were missing (sidebar stuck on "loading…") in 1.1.0 and 1.1.1. The background relay-list decode could not hand its result back; it is now a standalone function, and failures are logged.

## 1.1.1 (2026-10-06)

- **Windows installers** (x64 + arm64, Inno Setup, Tor bundled) and **macOS DMGs** (Apple Silicon + Intel) are now built by CI and attached to each release.
- Windows: the system proxy you had before is remembered and put back on disconnect, and a leftover OnionDesk proxy from a killed session is cleared on the next start.
- Linux packages are unchanged.

## 1.1.0 (2026-10-06)

### Renamed to OnionDesk
- VPN Desk is now **OnionDesk**: package/binary `oniondesk`, helpers `oniondesk-net`/`-restore`/`-uninstall`, app id `io.github.sandipbera35.OnionDesk`, env vars `ONIONDESK_*`. Settings and any open crash journal are carried over from the old name; the new `.deb`/`.rpm` replace `vpn-desk`.
- Store metadata for search: Network + Security categories, Tor/VPN/Onion/Proxy/Privacy keywords.
- New: signed apt/dnf repository build (needs signing key secrets), AUR `oniondesk-bin` recipe, portable `.tar.gz` per architecture.

### Smoothness
- Relay-list JSON (~1 MB) is decoded off the UI thread; it stalled a frame (up to ~90 ms) every minute.

## 1.0.7 (2026-10-05)

### Reliability (force-quit can no longer leave the machine without internet)
- Crash journal `~/.local/state/vpndesk/session.json`, written atomically before the system is touched.
- GNOME proxy: the previous values are recorded and restored exactly (was a blind `none`, and was only reset on a clean exit).
- `vpndesk-restore`: display-less recovery command (proxy, orphaned tor, system-wide firewall table). Also run on app start
  ("Recovered from an unclean exit") and as a detached guard that recovers within about a second of a `kill -9`.
- Every exit path (Disconnect, red close dot, `SIGTERM`/`SIGINT`/`SIGHUP`, dispose) now shares one idempotent, awaited teardown.
- Orphaned tor cleanup verifies pid + executable + start time; it can no longer signal an unrelated process.
- `vpndesk-net`: the state marker is written before the firewall rules, never after.
- Tests: recovery script (fake gsettings/pkexec), journal, stale-tor safety; `tool/test_nft_netns.sh` loads the real rules in a
  throw-away network namespace; `tool/crash_check.sh` drives the real app through kill/term/hup/close/disconnect.

### Speed and responsiveness (measured results in docs/bench/DECISIONS.md)
- Connecting no longer waits for Onionoo: cached relay choice (or the whole country, still `StrictNodes 1`), refreshed in the
  background through a live config edit (no tor restart).
- Onionoo answers cached on disk (30 min TTL, `If-Modified-Since`/`ETag` revalidation, offline fallback).
- The connecting screen shows real Tor bootstrap progress.
- One keep-alive HTTP client for the app's own requests through Tor.
- Speed estimates: time-stamped EWMA samples, dropped after an hour; RTT probes only for the selected country and the top
  few every minute (the rest every 10 minutes) instead of every country every minute.
- Auto-fastest compares like with like (smoothed measurements, or estimates for both), never a live measurement against an estimate.
- Benchmark harness `tool/bench/bench.dart` (cold/warm bootstrap, TTFB, 1- and N-stream throughput, interleaved A/B, optional local telemetry file).
- `IsolateDestAddr` in default mode: about +4 Mbps aggregate when browsing/downloading from several hosts (20 interleaved pairs), at +0.17 s first-request latency to a new host.
- Connect uses `ExitNodes {cc}` (strict) and pins the observed exit; last used country is remembered.
- Tor's GPG-signed checksum list is now verified against the pinned Tor Browser signing key in `fetch_tor.sh`.
- Tried and rejected for speed: pinning the top-3 exits; re-rolling slow circuits (worse, +50 s); padding off (no effect); Tor's default circuit lifetime (slower).

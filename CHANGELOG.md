# Changelog

## Highlights
- **Uninstall from the app** (Linux): About > Uninstall. Asks to confirm, then removes the app, its system helper and (optionally) your settings, with an animated progress page. Administrator permission is asked once; cancelling removes nothing. Set `VPNDESK_UNINSTALL_DRYRUN=1` to preview the flow without removing anything.

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

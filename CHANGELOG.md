# Changelog

## Highlights
- **Uninstall from the app** (Linux): About > Uninstall. Asks to confirm, then removes the app, its system helper and (optionally) your settings, with an animated progress page. Administrator permission is asked once; cancelling removes nothing. Set `VPNDESK_UNINSTALL_DRYRUN=1` to preview the flow without removing anything.

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

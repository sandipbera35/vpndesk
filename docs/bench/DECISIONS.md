# Benchmark decisions (Linux x86_64, Tor 0.4.9.13, exit country DE, 2026-10-05)

Method: `tool/bench/bench.dart ab`, 10 interleaved pairs (order alternates A,B / B,A), a fresh tor per session with a
warm DataDirectory, per session 6 TTFB (small HTTPS GET), 3 single-stream 3 MB downloads, 3 runs of 4 parallel 3 MB
downloads, all via `curl --socks5-hostname` (remote DNS). Pooled N = 60 / 30 / 30 per variant. Verdicts use the paired
per-session medians (mean difference, 95% CI). Single day, single time window, single country: treat as indicative.

Baseline (current app behaviour, single pinned exit): bootstrap cold 34.5 s, warm 4.0 s; TTFB median ~1.3-1.6 s;
1 stream ~4.5 Mbps; 4 streams ~12 Mbps. Between-session sd of the 1-stream median is ~1.4 Mbps (circuit luck),
larger than any config effect measured below.

| Experiment (B vs A) | TTFB diff | 1-stream Mbps diff | parallel Mbps diff | Decision |
|---|---|---|---|---|
| 2.2 top-3 exits vs single pinned exit (A) | +0.06 ± 0.19 s | +0.23 ± 1.73 | -2.30 ± 3.53 (B higher 2/10) | **Rejected**: no consistent gain |
| 2.2 `ExitNodes {de}` vs single pinned exit (A) | +0.02 ± 0.23 s | +0.51 ± 1.00 | -0.37 ± 3.81 | **Adopted for robustness, not speed**: same speed; no relay convergence, no stale-relay failure, connecting no longer needs Onionoo |
| H1 re-roll slow circuit (`NEWNYM`, up to 3x) vs `{de}` (A) | +0.06 ± 0.33 s (p90 4.1 vs 2.6 s) | -1.41 ± 1.65 (B higher 2/10) | -2.60 ± 3.38 | **Rejected**: worse and ~50 s of overhead. Caveat: a 1.5 MB probe on a fresh circuit always read below the 5 Mbps threshold, so every session re-rolled 3x (this tested "use a fresh circuit", not a calibrated threshold) |
| 2.3 `IsolateDestAddr` vs shared circuit (A), 4 different destinations in the parallel test | +0.19 ± 0.30 s | +0.85 ± 1.15 | **+3.35 ± 2.67** (B higher 8/10; median 10.2 -> 13.8) | **Adopted** (default mode only), see below |
| 2.5 `ConnectionPadding 0` + `CircuitPadding 0` vs baseline (A) | +0.05 ± 0.11 s | +0.09 ± 0.68 | +0.02 ± 2.48 | **Rejected**: no effect, so the privacy cost buys nothing |
| 2.6 Tor default circuit lifetime (`MaxCircuitDirtiness 600`, default `NewCircuitPeriod`) vs the app's 86400 s (A) | **+0.30 ± 0.20 s (slower)** | -0.55 ± 0.73 | **-2.05 ± 1.90 (slower)** | **Rejected**: the app's long-lived circuit is faster. Keep 86400 |

Note (2.2): `{cc}` costs nothing in speed and avoids sending every user to one volunteer relay and the stale-relay failure
mode, and it would let connecting skip Onionoo entirely. That is a robustness/load argument, not a speed one, and it
changes behaviour (the app currently pins one relay so every app shows one exit IP) - **maintainer decision**.

## 2.3 IsolateDestAddr (adopted)
Two interleaved runs of 10 pairs each, a different time of day (11:49 and 12:57), 4 different destinations (Cloudflare, two
Hetzner sites, thinkbroadband) in the parallel test. Pooled 20 pairs: parallel throughput **+3.97 ± 1.99 Mbps** (B higher in
17/20), single stream +0.36 ± 0.90 (n.s.), TTFB +0.17 ± 0.16 s (a first request to a new host builds a circuit). Shipped for
default mode (`SocksPort ... IsolateDestAddr`). System-wide mode (`TransPort`) is unmeasured and left unchanged.
Privacy: streams to different destinations no longer share one circuit, which lowers cross-destination linkability at
the guard/middle; the exit relay is still the one the app pinned, and the guard set is unchanged. Cost: more circuits.

## Verified, no change needed
- 2.1 Persistent DataDirectory: already `~/.config/vpn_desk/data` (system-wide: `/var/lib/vpn_desk/data`), not wiped on
  start. Cold 34.5 s vs warm 4.0 s bootstrap, so the cache is already doing its job.
- 2.7 Adaptive circuit timeouts: no `CircuitBuildTimeout` is set.
- 2.8 Bundled Tor: 15.0.24 (Tor 0.4.9.13) is the newest stable on dist.torproject.org (16.0a13 is an alpha); congestion
  control is present. Caveat: `fetch_tor.sh` checks a sha256 list fetched from the same server, which is a checksum,
  not a signature check.
- 2.4 Guards: the app already uses a set of 12 (`flag=Guard`, which implies Fast+Stable), none of the forbidden
  `NumEntryGuards`/`GuardLifetime` options. Not yet done: ranking by measured RTT (benchmark variant still to write).

## Not run (need maintainer approval before benchmarking or shipping)
- 2.3 `IsolateDestAddr` / circuit spreading, 2.5 padding options, 2.6 `MaxCircuitDirtiness`.
- Hypothesis H1 (from the data above): sessions on the same exit differ by circuit luck (3.5-7.7 Mbps). Re-rolling a slow
  circuit (control-port `SIGNAL NEWNYM` after a slow first probe) might raise the typical speed (expected best-of-2 ~ +25%
  on this tiny sample, not a result). Needs a control port in default mode and touches circuit lifetime -> approval first.

# Plan (2026-10-05)

Source brief: `../instruction.md`. Hard rule from the maintainer: the app must never leave the machine without
internet, whatever happens to it (SIGKILL included).

## Order of work
1. **Phase 0 (reliability)** - done first, fully, before any speed work.
   - `docs/state-inventory.md` (0.1)
   - `lib/session.dart`: atomic crash journal (0.2)
   - `packaging/linux/vpndesk-restore`: GUI-less recovery, also used on app start and by a detached watchdog (0.3, 0.4)
   - `lib/main.dart`: idempotent teardown, signals, window close, awaited cleanup (0.5)
   - `lib/platform.dart`: previous-proxy capture/restore, safe stale-tor kill
   - verify `__OwningControllerProcess` (0.6) empirically
   - tests: shell-script tests with fake `gsettings`/`pkexec`, journal unit tests; nft rules checked in a throwaway netns
2. Phase 1 benchmark harness (`tool/bench/`) + baseline.
3. Phase 2/3 only with benchmark evidence.

## Files touched in Phase 0
`lib/session.dart` (new), `lib/platform.dart`, `lib/main.dart`, `packaging/linux/vpndesk-restore` (new),
`packaging/linux/vpndesk-net` (state file written before rules), `bundle_tor.sh` (ship the script), `package.sh`
(ship + symlink the script; no new units), README, CHANGELOG, tests.

## Design decisions
- **One recovery implementation**: the bash script. The Flutter Linux runner needs GTK/a display before Dart `main`
  runs, so `vpn_desk --restore` cannot be display-less; the script can. The app calls the same script on start.
- Journal is flat JSON (one key per line) so the script can read it without `jq`/python.
- A tor is only killed if pid **and** `/proc/<pid>/exe` **and** start time match what the app recorded. Never `killall tor`.
- Proxy is restored to the *recorded previous values*; a previous value that is itself the stale `manual 127.0.0.1:9050` becomes `none`.
- **Watchdog**: a detached `vpndesk-restore --watch` waits for the app to die and then recovers, so a SIGKILL is fixed
  immediately, not only at next launch. User-level steps always; the root step (nft) only if the helper did not clean up
  by itself within a grace period.

## Open questions for the maintainer
- 0.7 boot-time systemd unit (needs packaging approval): not implemented.

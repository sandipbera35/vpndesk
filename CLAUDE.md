# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

VPN Desk: a Flutter Linux desktop GUI that starts/stops a local `tor` process with `ExitNodes {cc}` + `StrictNodes 1` to simulate a country. It is a SOCKS5 proxy on `127.0.0.1:9050`, not a system-wide VPN. Part of the larger `../` toolkit (see `../README.md`); the older web GUI is `../vpn-gui` and is legacy.

## Commands

Flutter is not on PATH; the SDK is at `/opt/flutter`.

```bash
export PATH=/opt/flutter/bin:$PATH
flutter pub get
flutter analyze                      # lints: flutter_lints
flutter build linux --release        # -> build/linux/x64/release/bundle/vpn_desk
./bundle_tor.sh                      # copy system tor + libs into the bundle (needs `tor` installed)
./install.sh                         # install bundle to ~/.local/share/vpn_desk + .desktop entry
./package.sh                         # build .deb/.rpm into dist/ (needs dpkg-deb, rpmbuild)
flutter test test/widget_test.dart   # single test file
```

- Always `pkill -x vpn_desk` before relaunching so changes are actually visible (user preference).
- `test/widget_test.dart` is the unmodified template and references a nonexistent `MyApp`; it does not compile. Replace it before relying on `flutter test`.
- `bundle_tor.sh` must run after every `flutter build linux`, since the build wipes the bundle. Order: build, bundle_tor, install/package.

## Architecture

Everything lives in `lib/main.dart` (`VpnDeskApp` -> `HomePage` / `_HomePageState`). There is no state-management layer or service split. The app shells out for everything:

- **Tor lifecycle:** `_start` writes `~/.config/vpn_desk/torrc` and runs `Process.start`. The tor binary is `<exe dir>/tor/tor` if bundled (with `LD_LIBRARY_PATH=<exe dir>/tor/lib`), otherwise `tor` from PATH. Connected state is set when stdout contains `Bootstrapped 100%`.
- **Status:** a 5s timer runs `pgrep -x tor`, so any tor on the machine counts as "running". `_stop` uses `pkill -x tor`, which kills all tor processes, not only the app's child.
- **IP/speed cards:** `curl` subprocesses, with the exit IP and speed tests going through `--socks5-hostname 127.0.0.1:9050`. Speed tests download from `speed.hetzner.de`.
- **Browser button:** runs the hardcoded absolute path `/home/sandipbera/opencode/vpn/tor/browser-launcher.sh`, which breaks in installed/packaged builds.
- **Window chrome:** `bitsdojo_window` frameless window. The red/yellow/green mac-style dots (close/minimize/maximize) are a user requirement; keep them.

## Packaging notes

- `packaging/` has the icon, desktop file, and flatpak/snap manifests. `package.sh` reads `packaging/icon.png`; `install.sh` looks for `assets/icon.png`, which the pubspec doesn't declare, so the installed icon is silently skipped.
- Version comes from `pubspec.yaml` (`version:` line is parsed by `package.sh`).
- `build/`, `dist/`, `.pkg/` are generated output. The directory is not a git repo.


## Cross-platform release (added 2026-10-04)

- OS-specific code is isolated in `lib/platform.dart` (`Plat`): config dir, bundled tor lookup, system proxy (gsettings / networksetup / registry), stale-tor kill via pid file, reload via SIGHUP or control port 9061 (Windows).
- tor now comes from the official Tor Expert Bundle via `fetch_tor.sh <os> <arch> <dest>` (sha256-checked), not the system tor. Layout: `<bundle>/tor/{tor,libs,geoip,geoip6}`; macOS puts it in `Contents/Resources/tor`.
- `bundle_tor.sh` (Linux), `package.sh` (deb/rpm, x64+arm64; arm64 tor compiled by `build_tor_linux.sh`), `package_mac.sh` (dmg), `windows_installer.iss` (Inno Setup), `.github/workflows/release.yml` (CI builds all; Flutter cannot cross-compile desktop).
- macOS/Windows folders were generated on Linux and never built or run here; Windows ARM runs the x64 build under emulation.
- Torrc has `__OwningControllerProcess <app pid>` so tor dies with the app.

## System-wide mode (Linux, optional, added 2026-10-04)

- Off by default; pill in the hero card. Enabling shows a confirm dialog; connecting triggers one `pkexec` prompt.
- `packaging/linux/vpndesk-net` (root helper, bundled by `bundle_tor.sh`, polkit policy `packaging/linux/io.vpndesk.net.policy`): creates user `vpndesk`, copies tor to `/var/lib/vpn_desk/runtime`, loads an nftables table `inet vpndesk` (TCP -> TransPort 9040, UDP 53 -> DNSPort 5353, everything else except loopback/LAN/DHCP/tor uid dropped, IPv6 blocked), runs tor as `vpndesk`. Only an allowlist of torrc directives is taken from stdin; no paths from the caller.
- Tor then runs as another uid, so the app controls it via the control port (127.0.0.1:9061, random password, `SETCONF ExitNodes`, `SIGNAL HALT`) — see `Plat.controlSend`, `_applyExit`. Clean tor exit (code 0, incl. app closing via `__OwningControllerProcess`) removes the rules; a crash leaves a block-all table and `/run/vpn_desk/state=blocked`, and the app shows a Restore banner (`pkexec vpndesk-net stop`).
- While system-wide, the app's own direct requests are also tunnelled: `_loadRealIp` is skipped (it would return the exit IP) and relay RTT probes are skipped when running.
- Verified here: bash syntax + `nft -c` on both rulesets. NOT verified: a live connect (it re-routes the machine's traffic), non-Fedora distros, `systemctl restart nftables` / `firewall-cmd --reload` (the former flushes our table = leak).

- Packaging gotchas: the Tor Expert Bundle ships 700/600 files, so `package.sh`/`fetch_tor.sh` chmod them readable (else tor can't start for normal users); files must be root-owned (`--root-owner-group`, `%defattr`); AppStream metainfo + `io.vpndesk.VPNDesk.desktop` are validated in `package.sh`; spec sets `__brp_check_rpaths` to nil because Fedora rejects the Flutter plugin's RUNPATH.

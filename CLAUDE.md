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

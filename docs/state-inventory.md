# System state VPN Desk mutates (Linux)

Verified against the code on 2026-10-05. Anything in this list must be undone by a clean
disconnect **and** by crash recovery (`vpndesk-restore`).

| # | State | Mode | Where it is changed | Undone by |
|---|-------|------|---------------------|-----------|
| 1 | GNOME proxy: `org.gnome.system.proxy mode`, `.socks host`, `.socks port` set to `manual` / `127.0.0.1` / `9050` | default + system-wide-off | `Plat.setSystemProxy(true)` after `Bootstrapped 100%` | disconnect; recovery restores the **previous** values (journal) |
| 2 | `tor` child process (user's uid) | default | `_start` -> `Process.start` | disconnect / `__OwningControllerProcess` / recovery (pid + exe + start time) |
| 3 | `~/.config/vpn_desk/{torrc,tor.pid,data/}` | default | `_writeTorrc`, `rememberTor` | persistent on purpose (DataDirectory = cached consensus); harmless |
| 4 | nftables table `inet vpndesk` (nat_out + filter_out hooks on output) | system-wide | `vpndesk-net start` (root) | helper cleanup on tor exit 0 / `vpndesk-net stop` |
| 5 | `tor` running as user `vpndesk` | system-wide | `vpndesk-net start` | `vpndesk-net stop` (`pkill -u vpndesk -x tor`) |
| 6 | `/run/vpn_desk/state` (`active` / `blocked`) | system-wide | helper | helper `stop`/cleanup |
| 7 | `/var/lib/vpn_desk/{torrc,runtime/,data/}`, system user `vpndesk` | system-wide | helper | persistent on purpose |
| 8 | `~/.local/state/vpndesk/session.json` (NEW, crash journal) | both | `Session` | deleted after a clean disconnect |

Ports: SOCKS `127.0.0.1:9050`; system-wide adds TransPort `9040`, DNSPort `5353`, ControlPort `9061` (password).

## Failure modes found in the code (before this work)

1. **Proxy left at `manual 127.0.0.1:9050` after a force-quit.** Only a clean exit reset it, and it reset to a
   blind `none` (clobbering any proxy the user had configured). Every proxy-aware app then has no internet.
2. `dispose()` fired `_setSystemProxy(false)` without awaiting it, so the process could exit first.
3. Red close dot / SIGTERM / SIGINT / SIGHUP did not run the disconnect path.
4. `killStaleTor` called `Process.killPid` on whatever PID was in `tor.pid`, without checking it was tor
   (PID reuse could kill an unrelated process).
5. SIGKILL of the helper (or `pkexec`) while system-wide leaves table `inet vpndesk` redirecting to a dead port.
   Normal app death is handled (`__OwningControllerProcess` -> tor exits 0 -> helper cleans up), a killed helper is not.

## After this work
Failure modes 1-4 are fixed (journal + awaited teardown + `vpndesk-restore` + guard + verified tor identity).
Mode 5 (helper itself SIGKILLed) is recovered by `vpndesk-restore` (guard after a grace period, or next start); a
boot-time unit (brief task 0.7) would additionally cover a reboot-less hard failure and needs maintainer approval.

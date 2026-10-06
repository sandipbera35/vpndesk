import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'session.dart';

/// Everything that differs between Linux, macOS and Windows lives here.
class Plat {
  static final bool win = Platform.isWindows, mac = Platform.isMacOS, linux = Platform.isLinux;

  /// Per-user config/data dir (torrc, tor DataDirectory, pid file, measurements).
  static Directory? configDirOverride; // tests

  /// Set while uninstalling: nothing may re-create the settings folder after it was deleted.
  static bool frozen = false;

  static Directory configDir() {
    if (configDirOverride != null) return configDirOverride!..createSync(recursive: true);
    final env = Platform.environment;
    final String base;
    if (win) {
      base = env['APPDATA'] ?? env['USERPROFILE'] ?? Directory.systemTemp.path;
    } else if (mac) {
      base = '${env['HOME'] ?? Directory.systemTemp.path}/Library/Application Support';
    } else {
      base = env['XDG_CONFIG_HOME'] ?? '${env['HOME'] ?? '/tmp'}/.config';
    }
    final d = Directory('$base/oniondesk');
    if (!frozen) {
      // Renamed from VPN Desk: carry the old settings/measurements over once.
      final old = Directory('$base/vpndesk');
      if (!d.existsSync() && old.existsSync()) { try { old.renameSync(d.path); } catch (_) {} }
      d.createSync(recursive: true);
    }
    return d;
  }

  /// Forward slashes are valid in torrc on every OS and avoid backslash escaping.
  static String torPath(String p) => p.replaceAll('\\', '/');

  /// Directory holding the bundled tor, or null if none was shipped.
  static Directory? bundledTorDir() {
    final exeDir = File(Platform.resolvedExecutable).parent;
    final d = mac ? Directory('${exeDir.parent.path}/Resources/tor') : Directory('${exeDir.path}/tor');
    return d.existsSync() ? d : null;
  }

  /// Bundled tor if present, otherwise `tor` from PATH (e.g. distro package).
  static String torExecutable() {
    final d = bundledTorDir();
    if (d != null) {
      final f = File('${d.path}/${win ? 'tor.exe' : 'tor'}');
      if (f.existsSync()) return f.path;
    }
    return win ? 'tor.exe' : 'tor';
  }

  static Map<String, String>? torEnv() {
    final d = bundledTorDir();
    if (d == null) return null;
    if (linux) return {'LD_LIBRARY_PATH': d.path};
    if (mac) return {'DYLD_LIBRARY_PATH': d.path};
    return null; // Windows loads DLLs from tor.exe's own folder
  }

  /// torrc lines pointing at the bundled GeoIP files (needed for ExitNodes {cc}).
  static String geoipLines() {
    final d = bundledTorDir();
    if (d == null) return '';
    final g4 = File('${d.path}/geoip'), g6 = File('${d.path}/geoip6');
    return '${g4.existsSync() ? 'GeoIPFile ${torPath(g4.path)}\n' : ''}'
        '${g6.existsSync() ? 'GeoIPv6File ${torPath(g6.path)}\n' : ''}';
  }

  /// Open a link in the user's default browser.
  static Future<void> openUrl(String url) async {
    try {
      if (win) {
        await Process.run('cmd', ['/c', 'start', '', url]);
      } else {
        await Process.run(mac ? 'open' : 'xdg-open', [url]);
      }
    } catch (_) {}
  }

  static File get _pidFile => File('${configDir().path}/tor.pid');

  static void rememberTor(int pid) {
    try { _pidFile.writeAsStringSync('$pid'); } catch (_) {}
    if (linux) Session.recordTor(pid, torExecutable());
  }

  /// Stop a tor left behind by a previous run of this app (it would hold the SOCKS port).
  /// On Linux the pid is only signalled if /proc/PID/exe is the tor we launch, so a recycled pid
  /// (or the user's own Tor Browser) is never touched.
  static Future<void> killStaleTor() async {
    try {
      final pid = int.tryParse(_pidFile.readAsStringSync().trim());
      if (pid != null && pid > 1) {
        if (win) {
          await Process.run('taskkill', ['/F', '/PID', '$pid']);
        } else if (_isOurTor(pid)) {
          Process.killPid(pid);
          await Future.delayed(const Duration(milliseconds: 600));
        }
      }
      _pidFile.deleteSync();
    } catch (_) {}
  }

  static bool _isOurTor(int pid) {
    if (!linux) return true; // macOS has no /proc; unchanged behaviour, untested here
    try {
      final exe = Link('/proc/$pid/exe').resolveSymbolicLinksSync();
      final ours = File(torExecutable()).existsSync() ? File(torExecutable()).resolveSymbolicLinksSync() : null;
      return ours != null && exe == ours;
    } catch (_) {
      return false; // gone, or not ours to inspect
    }
  }

  /// Ask tor to re-read its torrc (SIGHUP is unavailable on Windows, so use the control port).
  static Future<void> reloadTor(Process tor, String dataDir) async {
    if (!win) {
      tor.kill(ProcessSignal.sighup);
      return;
    }
    try {
      final cookie = await File('$dataDir/control_auth_cookie').readAsBytes();
      final hex = cookie.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final s = await Socket.connect('127.0.0.1', 9061, timeout: const Duration(seconds: 3));
      s.write('AUTHENTICATE $hex\r\nSIGNAL RELOAD\r\nQUIT\r\n');
      await s.flush();
      await s.drain().timeout(const Duration(seconds: 3), onTimeout: () {});
      s.destroy();
    } catch (_) {}
  }

  /// Loopback control port with cookie auth (the cookie sits in the 0700 tor data dir): used to reload and to close
  /// stale circuits when the exit country changes.
  static String controlLines(String dataDir) => 'ControlPort 127.0.0.1:9061\nCookieAuthentication 1\n';

  static Future<String?> _control(String auth, List<String> commands) async {
    try {
      final s = await Socket.connect('127.0.0.1', 9061, timeout: const Duration(seconds: 3));
      s.write('$auth\r\n${commands.join('\r\n')}\r\nQUIT\r\n');
      await s.flush();
      final out = await s.cast<List<int>>().transform(utf8.decoder).join().timeout(const Duration(seconds: 5), onTimeout: () => '');
      s.destroy();
      return out;
    } catch (_) {
      return null;
    }
  }

  /// Close every circuit so streams that are already open (a browser's keep-alive connection) cannot keep
  /// using the previous exit: they die and are re-opened on a circuit that satisfies the new ExitNodes.
  /// [password] is for system-wide mode's tor; otherwise the cookie in [dataDir] is used.
  static Future<int> closeAllCircuits({String? password, String? dataDir}) async {
    String auth;
    try {
      if (password != null) {
        auth = 'AUTHENTICATE "$password"';
      } else {
        final cookie = await File('$dataDir/control_auth_cookie').readAsBytes();
        auth = 'AUTHENTICATE ${cookie.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
      }
    } catch (_) {
      return 0;
    }
    final status = await _control(auth, ['GETINFO circuit-status']);
    if (status == null) return 0;
    final ids = [
      for (final m in RegExp(r'^(\d+) (?:BUILT|EXTENDED|LAUNCHED)\b', multiLine: true).allMatches(status)) m.group(1)!
    ];
    if (ids.isEmpty) return 0;
    await _control(auth, [for (final id in ids) 'CLOSECIRCUIT $id']);
    return ids.length;
  }

  /// `gsettings` binary; tests point this at a fake so the real desktop settings are never touched.
  static String gsettingsCmd = 'gsettings';
  static const _proxySchema = 'org.gnome.system.proxy';

  static String _unquote(String v) => v.trim().replaceAll("'", '');

  /// Current GNOME proxy mode/host/port, or null when gsettings is unavailable.
  static Future<({String mode, String host, int port})?> _readGnomeProxy() async {
    try {
      Future<String> get(String schema, String key) async {
        final r = await Process.run(gsettingsCmd, ['get', schema, key]);
        if (r.exitCode != 0) throw StateError('gsettings get failed');
        return (r.stdout as String).trim();
      }
      return (
        mode: _unquote(await get(_proxySchema, 'mode')),
        host: _unquote(await get('$_proxySchema.socks', 'host')),
        port: int.tryParse(await get('$_proxySchema.socks', 'port')) ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// Route apps that honour the OS proxy settings through Tor's SOCKS port.
  /// Linux: the previous GNOME values are journaled *before* they are changed and put back on `false`
  /// (never a blind "none"), so a crash can be undone exactly and a user's own proxy survives.
  static Future<void> setSystemProxy(bool on) async {
    Future<ProcessResult?> run(String cmd, List<String> a) async {
      try { return await Process.run(cmd, a); } catch (_) { return null; }
    }
    if (linux) {
      Future<void> gs(List<String> a) => run(gsettingsCmd, ['set', ...a]);
      if (on) {
        if (Session.get('proxy_changed') != true) {
          final prev = await _readGnomeProxy();
          if (prev == null) return; // no gsettings: nothing to change, so nothing to undo
          Session.set({
            'proxy_changed': true,
            'prev_proxy_mode': prev.mode,
            'prev_proxy_host': prev.host,
            'prev_proxy_port': prev.port,
          });
        }
        await gs(['$_proxySchema.socks', 'host', '127.0.0.1']);
        await gs(['$_proxySchema.socks', 'port', '9050']);
        await gs([_proxySchema, 'mode', 'manual']);
      } else if (Session.get('proxy_changed') == true) {
        var mode = '${Session.get('prev_proxy_mode') ?? 'none'}';
        var host = '${Session.get('prev_proxy_host') ?? ''}';
        var port = Session.get('prev_proxy_port') ?? 0;
        // A "previous" value that is itself our leftover would re-create the dead-proxy problem.
        if (mode == 'manual' && host == '127.0.0.1' && port == 9050) { mode = 'none'; host = ''; }
        if (mode.isEmpty) mode = 'none';
        if (host.isNotEmpty && port != 0) {
          await gs(['$_proxySchema.socks', 'host', host]);
          await gs(['$_proxySchema.socks', 'port', '$port']);
        }
        await gs([_proxySchema, 'mode', mode]);
        Session.set({'proxy_changed': false});
      }
    } else if (mac) {
      final r = await run('networksetup', ['-listallnetworkservices']);
      if (r == null) return;
      final services = (r.stdout as String).split('\n').skip(1).map((e) => e.trim()).where((e) => e.isNotEmpty && !e.startsWith('*'));
      for (final s in services) {
        if (on) await run('networksetup', ['-setsocksfirewallproxy', s, '127.0.0.1', '9050']);
        await run('networksetup', ['-setsocksfirewallproxystate', s, on ? 'on' : 'off']);
      }
    } else if (win) {
      const key = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';
      final prevFile = File('${configDir().path}/win_proxy_prev.json');
      if (on) {
        // Remember what the user had (once) so turning it off puts exactly that back, even after a crash.
        if (!prevFile.existsSync()) {
          final cur = await _readWinProxy();
          if (cur != null && cur.server != _winOurProxy) {
            try { prevFile.writeAsStringSync(jsonEncode({'enable': cur.enable, 'server': cur.server})); } catch (_) {}
          }
        }
        await run('reg', ['add', key, '/v', 'ProxyServer', '/t', 'REG_SZ', '/d', _winOurProxy, '/f']);
        await run('reg', ['add', key, '/v', 'ProxyEnable', '/t', 'REG_DWORD', '/d', '1', '/f']);
      } else {
        var enable = 0;
        var server = '';
        try {
          final m = jsonDecode(prevFile.readAsStringSync()) as Map;
          enable = (m['enable'] as num?)?.toInt() ?? 0;
          server = '${m['server'] ?? ''}';
        } catch (_) {}
        if (server == _winOurProxy) { server = ''; enable = 0; } // never restore our own leftover
        if (server.isNotEmpty) await run('reg', ['add', key, '/v', 'ProxyServer', '/t', 'REG_SZ', '/d', server, '/f']);
        await run('reg', ['add', key, '/v', 'ProxyEnable', '/t', 'REG_DWORD', '/d', '$enable', '/f']);
        try { prevFile.deleteSync(); } catch (_) {}
      }
    }
  }

  static const _winOurProxy = 'socks=127.0.0.1:9050';

  static Future<({int enable, String server})?> _readWinProxy() async {
    try {
      final r = await Process.run('reg', ['query', r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings', '/v', 'ProxyEnable']);
      final r2 = await Process.run('reg', ['query', r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings', '/v', 'ProxyServer']);
      final en = RegExp(r'ProxyEnable\s+REG_DWORD\s+0x([0-9a-fA-F]+)').firstMatch('${r.stdout}');
      final sv = RegExp(r'ProxyServer\s+REG_SZ\s+(.+)').firstMatch('${r2.stdout}');
      return (enable: en == null ? 0 : int.parse(en.group(1)!, radix: 16), server: sv?.group(1)?.trim() ?? '');
    } catch (_) {
      return null;
    }
  }

  /// Windows has no crash journal: on start, if a killed run left our dead SOCKS proxy enabled, put the user's proxy back.
  static Future<bool> recoverWindowsProxy() async {
    if (!win) return false;
    final cur = await _readWinProxy();
    if (cur == null || cur.enable != 1 || cur.server != _winOurProxy) return false;
    await setSystemProxy(false);
    return true;
  }

  // ---- Optional system-wide mode (Linux: nftables transparent proxy via a pkexec helper) ----

  static bool _has(String bin) {
    final dirs = [...(Platform.environment['PATH'] ?? '').split(':'), '/usr/sbin', '/sbin', '/usr/bin', '/bin'];
    return dirs.any((d) => d.isNotEmpty && File('$d/$bin').existsSync());
  }

  static String? get helperPath {
    final f = File('${File(Platform.resolvedExecutable).parent.path}/oniondesk-net');
    return f.existsSync() ? f.path : null;
  }

  /// Why system-wide mode can't be used here, or null if it can.
  static String? systemWideProblem() {
    if (!linux) return 'System-wide mode is only available on Linux for now.';
    if (helperPath == null) return 'The OnionDesk network helper is missing from this install.';
    if (!_has('pkexec')) return 'Needs polkit (pkexec) to ask for administrator permission. Install the "polkit" package.';
    if (!_has('nft')) return 'Needs nftables. Install the "nftables" package.';
    return null;
  }

  /// `oniondesk-restore` next to the executable (or in the source tree when run from a dev build).
  static String? get restoreScript {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    for (final c in ['$exeDir/oniondesk-restore', '$exeDir/../../../../../packaging/linux/oniondesk-restore']) {
      if (File(c).existsSync()) return c;
    }
    return null;
  }

  /// Recover from an unclean exit. Returns the script's exit code (0 nothing, 10 recovered, 1 failed) or null.
  static Future<int?> runRestore() async {
    final s = restoreScript;
    if (s == null) return null;
    try {
      final r = await Process.run(s, ['--auto']).timeout(const Duration(minutes: 3));
      return r.exitCode;
    } catch (_) {
      return null;
    }
  }

  /// Detached guard: when this app dies uncleanly (SIGKILL included) it restores proxy/tor/firewall at once.
  static Future<void> startWatchdog() async {
    final s = restoreScript;
    if (s == null) return;
    try {
      await Process.start(s, ['--watch'], mode: ProcessStartMode.detached);
    } catch (_) {}
  }

  static String randomHex(int bytes) {
    final r = Random.secure();
    return List.generate(bytes, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  /// `HashedControlPassword` value for [password], computed by the bundled tor.
  static Future<String?> hashPassword(String password) async {
    try {
      final r = await Process.run(torExecutable(), ['--hash-password', password], environment: torEnv());
      for (final l in (r.stdout as String).split('\n').reversed) {
        if (l.trim().startsWith('16:')) return l.trim();
      }
    } catch (_) {}
    return null;
  }

  /// Run [commands] on tor's control port (password auth). Returns tor's raw reply or null on failure.
  static Future<String?> controlSend(String password, List<String> commands) async {
    try {
      final s = await Socket.connect('127.0.0.1', 9061, timeout: const Duration(seconds: 3));
      s.write('AUTHENTICATE "$password"\r\n${commands.join('\r\n')}\r\nQUIT\r\n');
      await s.flush();
      final out = await s.cast<List<int>>().transform(utf8.decoder).join().timeout(const Duration(seconds: 5), onTimeout: () => '');
      s.destroy();
      return out;
    } catch (_) {
      return null;
    }
  }

  /// none | active | blocked, as recorded by the helper.
  static String netState() {
    try { return File('/run/oniondesk/state').readAsStringSync().trim(); } catch (_) { return 'none'; }
  }

  /// Start the helper (admin prompt via pkexec) and feed it the torrc on stdin.
  static Future<Process> startSystemWide(String torrc) async {
    final p = await Process.start('pkexec', [helperPath!, 'start']);
    p.stdin.write(torrc);
    await p.stdin.close();
    return p;
  }

  /// Remove the firewall rules and restore normal networking (admin prompt).
  static Future<bool> restoreNetwork() async {
    try {
      final r = await Process.run('pkexec', [helperPath!, 'stop']);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}

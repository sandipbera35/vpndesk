import 'dart:async';
import 'dart:io';

/// Everything that differs between Linux, macOS and Windows lives here.
class Plat {
  static final bool win = Platform.isWindows, mac = Platform.isMacOS, linux = Platform.isLinux;

  /// Per-user config/data dir (torrc, tor DataDirectory, pid file, measurements).
  static Directory configDir() {
    final env = Platform.environment;
    final String base;
    if (win) {
      base = env['APPDATA'] ?? env['USERPROFILE'] ?? Directory.systemTemp.path;
    } else if (mac) {
      base = '${env['HOME'] ?? Directory.systemTemp.path}/Library/Application Support';
    } else {
      base = env['XDG_CONFIG_HOME'] ?? '${env['HOME'] ?? '/tmp'}/.config';
    }
    final d = Directory('$base/vpn_desk');
    d.createSync(recursive: true);
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

  static File get _pidFile => File('${configDir().path}/tor.pid');

  static void rememberTor(int pid) {
    try { _pidFile.writeAsStringSync('$pid'); } catch (_) {}
  }

  /// Kill a tor left behind by a previous run of this app (it would hold the SOCKS port).
  static Future<void> killStaleTor() async {
    try {
      final pid = int.tryParse(_pidFile.readAsStringSync().trim());
      if (pid != null) {
        if (win) {
          await Process.run('taskkill', ['/F', '/PID', '$pid']);
        } else {
          Process.killPid(pid);
        }
        await Future.delayed(const Duration(milliseconds: 600));
      }
      _pidFile.deleteSync();
    } catch (_) {}
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

  static String controlLines(String dataDir) =>
      win ? 'ControlPort 127.0.0.1:9061\nCookieAuthentication 1\n' : '';

  /// Route apps that honour the OS proxy settings through Tor's SOCKS port.
  static Future<void> setSystemProxy(bool on) async {
    Future<ProcessResult?> run(String cmd, List<String> a) async {
      try { return await Process.run(cmd, a); } catch (_) { return null; }
    }
    if (linux) {
      Future<void> gs(List<String> a) => run('gsettings', ['set', ...a]);
      if (on) {
        await gs(['org.gnome.system.proxy.socks', 'host', '127.0.0.1']);
        await gs(['org.gnome.system.proxy.socks', 'port', '9050']);
        await gs(['org.gnome.system.proxy', 'mode', 'manual']);
      } else {
        await gs(['org.gnome.system.proxy', 'mode', 'none']);
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
      if (on) await run('reg', ['add', key, '/v', 'ProxyServer', '/t', 'REG_SZ', '/d', 'socks=127.0.0.1:9050', '/f']);
      await run('reg', ['add', key, '/v', 'ProxyEnable', '/t', 'REG_DWORD', '/d', on ? '1' : '0', '/f']);
    }
  }
}

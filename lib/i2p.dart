import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'platform.dart';
import 'process_guard.dart';

/// I2P support: runs the user's own installed `i2pd` as a private child of this app (never the system service) and
/// reports its status. Nothing about the machine's network is changed: no OS proxy, no firewall, no service. The
/// only thing that could be left behind is the i2pd process itself, which is stopped with the app and, after a
/// kill, reaped on the next start through a pid file (and only if it is really our i2pd).

const kI2pHttpPort = 4444, kI2pSocksPort = 4447, kI2pConsolePort = 7070;
const _kPorts = [kI2pHttpPort, kI2pSocksPort, kI2pConsolePort];

enum I2pState { notInstalled, stopped, starting, running, failed, external }

/// What the router's web console reported. Every field is optional: i2pd versions word things differently.
class I2pStatus {
  const I2pStatus({this.version, this.netText, this.routers, this.floodfills, this.clientTunnels, this.successRate, this.bwIn, this.bwOut});
  final String? version, netText;
  final int? routers, floodfills, clientTunnels;
  final double? successRate; // 0..100
  final double? bwIn, bwOut; // bytes per second

  /// Integrated enough to browse: knows other routers and has built several client tunnels that mostly succeed.
  /// (Measured on a real i2pd 2.61: it reports a 10% success rate in the first seconds and 60-90% a minute later.)
  bool get integrated => (routers ?? 0) > 0 && (clientTunnels ?? 0) >= 4 && (successRate ?? 0) >= 40;
}

/// Read the main page of the i2pd web console (plain HTTP on 127.0.0.1). The real i2pd 2.61 page has lines like
/// `Uptime: 22 seconds`, `Network status: Firewalled - Symmetric NAT`, `Tunnel creation success rate: 100%`,
/// `Received: 27.90 KiB (1.14 KiB/s)`, `Routers: 170`, `Client Tunnels: 5`, `Version: 2.61.0`. Anything not found is null.
I2pStatus parseConsole(String html) {
  final text = html
      .replaceAll(RegExp(r'<style.*?</style>', dotAll: true), ' ')
      .replaceAll(RegExp(r'<[^>]*>'), '\n')
      .replaceAll('&nbsp;', ' ');
  final lines = [for (final l in text.split('\n')) if (l.trim().isNotEmpty) l.trim()];
  String? after(String label) {
    final i = lines.indexWhere((l) => l == label || l == '$label:');
    return i >= 0 && i + 1 < lines.length ? lines[i + 1] : null;
  }

  int? intOf(String? v) => v == null ? null : int.tryParse(RegExp(r'\d+').firstMatch(v)?.group(0) ?? '');
  double? rate(String? v) {
    // "27.90 KiB (1.14 KiB/s)" -> bytes per second of the part in brackets.
    final m = v == null ? null : RegExp(r'\(([\d.]+)\s*([KMG]?i?B)/s\)').firstMatch(v);
    if (m == null) return null;
    final n = double.tryParse(m.group(1)!);
    if (n == null) return null;
    const mult = {'B': 1.0, 'KiB': 1024.0, 'MiB': 1048576.0, 'GiB': 1073741824.0, 'KB': 1000.0, 'MB': 1e6, 'GB': 1e9};
    return n * (mult[m.group(2)] ?? 1.0);
  }

  final succ = after('Tunnel creation success rate');
  return I2pStatus(
    version: after('Version'),
    netText: after('Network status'),
    routers: intOf(after('Routers')),
    floodfills: intOf(after('Floodfills')),
    clientTunnels: intOf(after('Client Tunnels')),
    successRate: succ == null ? null : double.tryParse(RegExp(r'[\d.]+').firstMatch(succ)?.group(0) ?? ''),
    bwIn: rate(after('Received')),
    bwOut: rate(after('Sent')),
  );
}

/// The i2pd config OnionDesk runs with. Pure so it can be tested. [share] = relay traffic for the network
/// (off by default: it uses the user's bandwidth).
String buildI2pConf({required bool share, String? logFile}) => '''
# Written by OnionDesk. Overwritten on every start; edit nothing here.
ipv6 = false
notransit = ${share ? 'false' : 'true'}
# i2pd's default cap is 32 KB/s; a client-only router (notransit) shares nothing, so the cap would only throttle our own pages.
bandwidth = 4096
${logFile == null ? 'log = stdout' : 'log = file\nlogfile = $logFile'}
loglevel = warn
daemon = false
[http]
enabled = true
address = 127.0.0.1
port = $kI2pConsolePort
[httpproxy]
enabled = true
address = 127.0.0.1
port = $kI2pHttpPort
[socksproxy]
enabled = true
address = 127.0.0.1
port = $kI2pSocksPort
[addressbook]
# Besides the bundled seed: keep the address book growing from the lists most I2P users subscribe to.
subscriptions = http://notbob.i2p/hosts.txt,http://inr.i2p/export/alive-hosts.txt,http://stats.i2p/cgi-bin/newhosts.txt,http://i2p-projekt.i2p/hosts.txt,http://reg.i2p/hosts.txt,http://identiguy.i2p/hosts.txt
[i2pcontrol]
enabled = false
[upnp]
enabled = false
''';

/// Where i2pd may be: [custom] (the user's choice) wins, then the copy shipped inside the app ([bundled]), then an installed one. Pure: the file check is injected.
String? findI2pd({String? custom, String? bundled, required bool Function(String) exists, required Map<String, String> env, required bool win, required bool mac}) {
  if (custom != null && custom.isNotEmpty && exists(custom)) return custom;
  if (bundled != null && exists(bundled)) return bundled; // shipped with the app: preferred over whatever is installed
  final name = win ? 'i2pd.exe' : 'i2pd';
  final sep = win ? ';' : ':';
  final dirs = <String>[
    for (final p in (env['PATH'] ?? '').split(sep)) if (p.isNotEmpty) p,
    if (win) ...[
      for (final base in [env['ProgramFiles'], env['ProgramFiles(x86)'], env['LOCALAPPDATA']]) if (base != null) '$base\\i2pd',
    ] else ...[
      '/usr/bin', '/usr/sbin', '/usr/local/bin', '/usr/local/sbin',
      if (mac) ...['/opt/homebrew/bin', '/opt/homebrew/sbin'],
    ],
  ];
  for (final d in dirs) {
    final f = win ? '$d\\$name' : '$d/$name';
    if (exists(f)) return f;
  }
  return null;
}

/// The i2pd shipped with the app (`<app>/i2pd/i2pd`, macOS `Contents/Resources/i2pd/i2pd`), or null if this build has none.
String bundledI2pdPath() {
  final exeDir = File(Platform.resolvedExecutable).parent;
  final dir = Plat.mac ? '${exeDir.parent.path}/Resources/i2pd' : '${exeDir.path}${Platform.pathSeparator}i2pd';
  return '$dir${Platform.pathSeparator}${Plat.win ? 'i2pd.exe' : 'i2pd'}';
}

/// libproxychains4.so shipped next to the bundled i2pd (Linux only), or null: the shim that forces apps through I2P.
String? bundledForceLib() {
  if (!Plat.linux) return null;
  final f = File('${File(Platform.resolvedExecutable).parent.path}/i2pd/force/libproxychains4.so');
  return f.existsSync() ? f.path : null;
}

/// A fresh i2pd knows no .i2p names (it downloads an address book in the background, which can take many minutes), so
/// `stats.i2p`, `i2pforum.i2p` ... fail with "host not found". The bundled seed `hosts.txt` (from the I2P project) is
/// copied into the data folder, where i2pd loads it when its own address book is empty. Never overwrites an existing file.
bool seedAddressBook(Directory bundleDir, Directory dataDir) {
  try {
    final seed = File('${bundleDir.path}${Platform.pathSeparator}hosts.txt');
    final target = File('${dataDir.path}${Platform.pathSeparator}hosts.txt');
    if (!seed.existsSync() || target.existsSync()) return false;
    dataDir.createSync(recursive: true);
    seed.copySync(target.path);
    return true;
  } catch (_) {
    return false;
  }
}

/// Ports of ours that something else already listens on.
Future<List<int>> busyI2pPorts() async {
  final busy = <int>[];
  for (final p in _kPorts) {
    try {
      final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, p);
      await s.close();
    } catch (_) {
      busy.add(p);
    }
  }
  return busy;
}

class I2pRouter extends ChangeNotifier {
  I2pRouter({this.dirOverride});

  /// Tests: use this folder instead of `<config>/i2p`.
  final Directory? dirOverride;

  /// True when [exe] is the copy shipped with the app.
  bool get bundled => exe != null && exe == bundledI2pdPath();

  I2pState state = I2pState.stopped;
  I2pStatus status = const I2pStatus();
  String? exe; // resolved i2pd
  String? customPath; // user's choice, persisted by the home page
  bool share = false;
  DateTime? startedAt;
  String log = '';
  String? error;
  List<int> busyPorts = const [];

  Process? _proc;
  Timer? _poll;
  bool _polling = false;
  bool _stopping = false;
  bool _wasRunning = false; // reached "running" during this start

  Directory get dir => dirOverride ?? Directory('${Plat.configDir().path}/i2p');
  File get _pidFile => File('${dir.path}/i2pd.pid');
  bool get active => state == I2pState.starting || state == I2pState.running;

  /// 0..1 while joining the network (for the progress ring): routers known, tunnels built, success rate. 1 when connected.
  double get progress {
    if (state == I2pState.running) return 1;
    if (state != I2pState.starting) return 0;
    final s = status;
    final p = ((s.routers ?? 0) > 0 ? 0.2 : 0.05) + ((s.clientTunnels ?? 0) / 8).clamp(0.0, 1.0) * 0.45 + ((s.successRate ?? 0) / 40).clamp(0.0, 1.0) * 0.3;
    return p.clamp(0.05, 0.97);
  }

  void _set(I2pState s, {String? err}) {
    state = s;
    error = err;
    notifyListeners();
  }

  /// Look for i2pd again (after the user installs it or picks a path).
  void detect() {
    exe = findI2pd(custom: customPath, bundled: bundledI2pdPath(), exists: (p) => File(p).existsSync(), env: Platform.environment, win: Plat.win, mac: Plat.mac);
    if (active) return;
    if (exe == null) {
      _set(I2pState.notInstalled);
    } else if (state == I2pState.notInstalled || state == I2pState.external) {
      _set(I2pState.stopped);
    } else {
      notifyListeners();
    }
  }

  Future<void> start() async {
    if (active || _stopping) return;
    detect();
    final bin = exe;
    if (bin == null) return;
    await killStale();
    busyPorts = await busyI2pPorts();
    if (busyPorts.isNotEmpty) {
      _set(I2pState.external, err: 'Port ${busyPorts.join(', ')} is already in use: another I2P router is probably running.');
      return;
    }
    try {
      dir.createSync(recursive: true);
      final conf = File('${dir.path}/i2pd.conf')..writeAsStringSync(buildI2pConf(share: share, logFile: Plat.win ? '${dir.path}\\i2pd.log' : null));
      log = '';
      status = const I2pStatus();
      startedAt = DateTime.now();
      _wasRunning = false;
      _set(I2pState.starting);
      seedAddressBook(File(bin).parent, dir);
      // A shipped i2pd comes with the reseed/family certificates next to it: use them (the datadir is ours, so it has none).
      final certs = Directory('${File(bin).parent.path}${Platform.pathSeparator}certificates');
      final p = await Process.start(bin, ['--datadir', dir.path, '--conf', conf.path, if (certs.existsSync()) ...['--certsdir', certs.path]]);
      _proc = p;
      try { _pidFile.writeAsStringSync('${p.pid}\n$bin'); } catch (_) {}
      guardProcess(owner: pid, target: p.pid, exe: bin); // dies with the app even if the app is killed or crashes
      void sink(String s) {
        log += s;
        if (log.length > 12000) log = log.substring(log.length - 12000);
        notifyListeners();
      }

      p.stdout.transform(SystemEncoding().decoder).listen(sink, onError: (_) {});
      p.stderr.transform(SystemEncoding().decoder).listen(sink, onError: (_) {});
      p.exitCode.then((code) {
        if (!identical(_proc, p)) return;
        _proc = null;
        if (Plat.win) { try { log = File('${dir.path}\\i2pd.log').readAsStringSync(); } catch (_) {} } // the Windows build has no console: it logs to a file
        _poll?.cancel();
        try { _pidFile.deleteSync(); } catch (_) {}
        if (!_stopping) _set(I2pState.failed, err: 'i2pd stopped unexpectedly (exit code $code).');
      });
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 4), (_) => refresh());
      Future.delayed(const Duration(seconds: 2), refresh);
    } catch (e) {
      _proc = null;
      _set(I2pState.failed, err: 'Could not start i2pd: $e');
    }
  }

  /// SIGTERM (i2pd then shuts its tunnels down gracefully), SIGKILL after [grace].
  Future<void> stop({Duration grace = const Duration(seconds: 5)}) async {
    final p = _proc;
    if (p == null) {
      if (state != I2pState.notInstalled && state != I2pState.external) _set(I2pState.stopped);
      return;
    }
    _stopping = true;
    _poll?.cancel();
    _proc = null;
    try {
      p.kill(ProcessSignal.sigterm);
      await p.exitCode.timeout(grace, onTimeout: () {
        p.kill(ProcessSignal.sigkill);
        return -1;
      });
    } catch (_) {}
    try { _pidFile.deleteSync(); } catch (_) {}
    _stopping = false;
    status = const I2pStatus();
    startedAt = null;
    _set(I2pState.stopped);
  }

  /// Read the web console (plain HTTP, loopback). Runs from a timer while the router runs.
  Future<void> refresh() async {
    if (_polling || _proc == null || state == I2pState.stopped) return;
    _polling = true;
    try {
      final html = await _fetchConsole();
      if (_proc == null || html == null) return; // not up yet: stay "starting"
      status = parseConsole(html);
      // Once connected, stay connected while the router still knows peers and has client tunnels: the success rate of a
      // router behind NAT bounces between ~40% and ~90%, and flipping back to "Joining..." (and disabling the browser
      // button) every time it dips made a working connection look like it had dropped.
      final keep = _wasRunning && (status.routers ?? 0) > 0 && (status.clientTunnels ?? 0) > 0;
      if (status.integrated) _wasRunning = true;
      _set(status.integrated || keep ? I2pState.running : I2pState.starting);
    } finally {
      _polling = false;
    }
  }

  Future<String?> _fetchConsole() async {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final req = await c.getUrl(Uri.parse('http://127.0.0.1:$kI2pConsolePort/'));
      final res = await req.close().timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return null;
      return await res.transform(utf8.decoder).join();
    } catch (_) {
      return null;
    } finally {
      c.close(force: true);
    }
  }

  // ---- orphan protection ----

  /// Stop an i2pd left behind by a previous run of this app (it would hold our ports). Only a pid whose executable is
  /// the recorded i2pd is signalled, so a recycled pid or the user's own i2pd is never touched.
  Future<void> killStale() async {
    // 1. by pid file; 2. any i2pd still using OUR data folder (an orphan whose pid file is gone, e.g. after a crash)
    final orphans = await findOrphansByDatadir(File(exe ?? 'i2pd').uri.pathSegments.last, dir.path);
    for (final o in orphans) {
      if (_proc != null && o == _proc!.pid) continue;
      if (Plat.win) {
        await Process.run('taskkill', ['/F', '/PID', '$o']);
      } else {
        Process.killPid(o);
        await Future.delayed(const Duration(milliseconds: 800));
        Process.killPid(o, ProcessSignal.sigkill);
      }
    }
    try {
      final lines = _pidFile.readAsLinesSync();
      final pid = int.tryParse(lines.first.trim());
      final recorded = lines.length > 1 ? lines[1].trim() : '';
      if (pid != null && pid > 1 && isOurI2pd(pid, recorded)) {
        if (Plat.win) {
          await Process.run('taskkill', ['/F', '/PID', '$pid']);
        } else {
          Process.killPid(pid);
          await Future.delayed(const Duration(milliseconds: 800));
        }
      }
      _pidFile.deleteSync();
    } catch (_) {}
  }

  /// On Linux the live executable of [pid] must resolve to the recorded i2pd. Elsewhere (no /proc) we cannot check,
  /// so nothing is signalled.
  static bool isOurI2pd(int pid, String recorded) {
    if (!Platform.isLinux || recorded.isEmpty) return false;
    try {
      final exe = Link('/proc/$pid/exe').resolveSymbolicLinksSync();
      return File(recorded).existsSync() && exe == File(recorded).resolveSymbolicLinksSync();
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}

/// Per-OS install hints shown when i2pd is not found.
({String label, String command})? i2pInstallHint({required bool win, required bool mac, String? osRelease}) {
  if (win) return null;
  if (mac) return (label: 'Homebrew', command: 'brew install i2pd');
  final r = (osRelease ?? '').toLowerCase();
  if (r.contains('fedora') || r.contains('rhel') || r.contains('centos')) return (label: 'Fedora / RHEL', command: 'sudo dnf install i2pd');
  if (r.contains('arch') || r.contains('manjaro')) return (label: 'Arch', command: 'sudo pacman -S i2pd');
  if (r.contains('suse')) return (label: 'openSUSE', command: 'sudo zypper install i2pd');
  return (label: 'Debian / Ubuntu', command: 'sudo apt install i2pd');
}

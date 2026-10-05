import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show AppExitResponse, FontFeature;
import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:socks5_proxy/socks_client.dart';
import 'about_page.dart';
import 'estimator.dart';
import 'onionoo.dart';
import 'platform.dart';
import 'session.dart';
import 'torrc.dart';
import 'uninstall.dart';
import 'uninstall_page.dart';
import 'world_map.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VpnDeskApp());
  doWhenWindowReady(() {
    appWindow.minSize = const Size(640, 560);
    appWindow.size = const Size(1080, 640);
    appWindow.alignment = Alignment.center;
    appWindow.title = 'VPN Desk';
    appWindow.minSize = const Size(640, 560);
    appWindow.show();
  });
}

const countries = {
  'us': 'United States', 'de': 'Germany', 'nl': 'Netherlands', 'fr': 'France',
  'gb': 'United Kingdom', 'jp': 'Japan', 'sg': 'Singapore', 'in': 'India',
  'ca': 'Canada', 'au': 'Australia', 'se': 'Sweden', 'ch': 'Switzerland',
  'es': 'Spain', 'it': 'Italy', 'br': 'Brazil', 'ru': 'Russia', 'kr': 'South Korea',
  'no': 'Norway', 'fi': 'Finland', 'pl': 'Poland', 'cz': 'Czech Republic', 'at': 'Austria',
  'be': 'Belgium', 'pt': 'Portugal', 'ie': 'Ireland', 'dk': 'Denmark', 'ro': 'Romania',
  'mx': 'Mexico', 'ar': 'Argentina', 'hk': 'Hong Kong', 'tw': 'Taiwan', 'za': 'South Africa',
};

class VpnDeskApp extends StatelessWidget {
  const VpnDeskApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'VPN Desk',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF0B1220),
          cardTheme: CardThemeData(
            color: const Color(0xFF16233A),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFF24344F))),
          ),
        ),
        scrollBehavior: const MaterialScrollBehavior().copyWith(scrollbars: false),
        builder: (context, child) => ClipRRect(borderRadius: BorderRadius.circular(18), child: child),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  Process? _tor;
  bool running = false;
  bool connecting = false;
  String selectedCountry = 'cz';
  TextEditingController? _countryCtrl;
  bool _loadingExit = false, _loadingSpeed = false;
  int _exitGen = 0;
  String realIp = '—';
  String exitIp = '—';
  LatLon? _realLL, _exitLL;
  String? _realPlace, _exitPlace;
  String speed = '—';
  String _log = '';
  // Tor logs for as long as the app is open: keep only the tail so the string (and each rebuild) stays bounded.
  String get log => _log;
  set log(String v) => _log = v.length > 20000 ? v.substring(v.length - 20000) : v;
  Timer? _timer, _realTimer, _statsTimer;
  late AnimationController _dotCtrl;

  Directory get _cfgDir => Plat.configDir();

  String get _torrcPath => '${_cfgDir.path}/torrc';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    // Undo what a previous run that was killed left behind *before* any network lookups.
    _recoverOnStart().whenComplete(() {
      if (!mounted) return;
      _netBlocked = Plat.linux && Plat.netState() != 'none';
      _loadRealIp();
      _loadSpeed();
      _loadCountryStats();
    });
    _exitListener = AppLifecycleListener(onExitRequested: () async {
      await _teardown();
      return AppExitResponse.exit;
    });
    if (!Plat.win) {
      for (final sig in [ProcessSignal.sigterm, ProcessSignal.sigint, ProcessSignal.sighup]) {
        _sigSubs.add(sig.watch().listen((_) => _quit()));
      }
    }
    _startTimers();
    _dotCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }

  void _startTimers() {
    _statsTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _loadCountryStats();
      if (running && !_loadingSpeed) _loadSpeed();
      if (_realLL == null && _ipRe.hasMatch(realIp)) _loadRealGeo(realIp);
    });
    _realTimer = Timer.periodic(const Duration(seconds: 30), (_) { if (!running && !connecting) _loadRealIp(); });
    _timer = Timer.periodic(const Duration(seconds: 20), (_) { _refreshStatus(); if (running && !_loadingExit && !_switching) _loadExitIp(silent: true); });
  }

  void _stopTimers() {
    _timer?.cancel();
    _realTimer?.cancel();
    _statsTimer?.cancel();
  }

  // ---- Uninstall (Linux) ----

  /// Ask, then run the uninstall page. `VPNDESK_UNINSTALL_DRYRUN=1` previews the whole flow and removes nothing.
  Future<void> _beginUninstall() async {
    final dry = Platform.environment['VPNDESK_UNINSTALL_DRYRUN'] == '1';
    UninstallPlan planFor(bool data) => UninstallPlan.detect(exe: Platform.resolvedExecutable, env: Platform.environment, deleteData: data);
    final deleteData = await showUninstallConfirm(context, planFor: planFor, dryRun: dry);
    if (deleteData == null || !mounted) return;
    final plan = planFor(deleteData);
    final up = Uninstaller(
      plan: plan,
      dryRun: dry,
      prepare: () async {
        // Stop everything that could touch the machine or re-create files, then undo what the app changed.
        _stopTimers();
        Plat.frozen = true;
        Session.frozen = true;
        await _teardown();
        await Plat.runRestore();
        Session.end();
      },
    );
    void back() {
      // Cancelled or failed: resume normal operation.
      Plat.frozen = false;
      Session.frozen = false;
      if (_statsTimer?.isActive != true) _startTimers();
      setState(() { running = false; connecting = false; exitIp = '—'; _exitLL = null; }); // we disconnected before asking
      _loadRealIp();
      Navigator.of(context).pop();
    }
    await Navigator.of(context).push(uninstallRoute(plan: plan, start: up.run, onBack: back, onExit: () => exit(0), dryRun: dry));
  }

  // The pulse only matters while connecting/connected; an idle repeating ticker would repaint (and burn CPU) forever.
  void _syncPulse() {
    final want = running || connecting;
    if (want == _dotCtrl.isAnimating) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (running || connecting) {
        if (!_dotCtrl.isAnimating) _dotCtrl.repeat(reverse: true);
      } else {
        _dotCtrl.stop();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _realTimer?.cancel();
    _statsTimer?.cancel();
    _dotCtrl.dispose();
    _exitListener?.dispose();
    for (final s in _sigSubs) { s.cancel(); }
    _teardown(); // not awaitable here; the watchdog + next-start recovery cover a hard exit
    super.dispose();
  }

  AppLifecycleListener? _exitListener;
  final List<StreamSubscription<ProcessSignal>> _sigSubs = [];
  String? _recoveryNote; // shown as a banner after an unclean previous exit
  bool _recoveryFailed = false;

  /// Undo what an earlier, killed run left behind (proxy, orphaned tor, firewall) via `vpndesk-restore`.
  Future<void> _recoverOnStart() async {
    if (!Plat.linux) return;
    final rc = await Plat.runRestore();
    if (!mounted || rc == null || rc == 0) return;
    setState(() {
      _recoveryFailed = rc != 10;
      _recoveryNote = rc == 10
          ? 'Recovered from an unclean exit: your previous network settings were restored.'
          : 'The last session did not exit cleanly and some settings could not be restored. Run  vpndesk-restore  in a terminal.';
    });
  }

  Future<void>? _teardownRun;

  /// Undo everything this session changed (tor, proxy, firewall) and delete the crash journal.
  /// Idempotent: every exit path (Disconnect, signals, window close, dispose) shares one run.
  Future<void> _teardown() => _teardownRun ??= _doTeardown().whenComplete(() => _teardownRun = null);

  Future<void> _doTeardown() async {
    var clean = true;
    final tor = _tor;
    try {
      if (_sysActive) {
        // tor runs as another user behind pkexec: ask it to exit cleanly (HALT); the helper then removes
        // the firewall rules. Fall back to the helper's `stop` if the control port is gone or it hangs.
        final r = await Plat.controlSend(_ctlPass, ['SIGNAL HALT']);
        var done = r != null && r.contains('250');
        if (done && tor != null) {
          await tor.exitCode.timeout(const Duration(seconds: 10), onTimeout: () { done = false; return 0; });
        }
        if (!done || Plat.netState() != 'none') clean = await Plat.restoreNetwork();
        _sysActive = false;
      } else if (tor != null) {
        tor.kill();
        await tor.exitCode.timeout(const Duration(seconds: 3), onTimeout: () { tor.kill(ProcessSignal.sigkill); return 0; });
      }
      _tor = null;
      _dropTorClient();
      await Plat.setSystemProxy(false);
    } catch (_) {
      clean = false;
    }
    if (clean) Session.end(); // otherwise keep it: the next start / watchdog finishes the job
  }

  /// Quit the app (signal or close button): restore the system first, then exit. Never hangs forever.
  Future<void> _quit() async {
    await _teardown().timeout(const Duration(seconds: 25), onTimeout: () {});
    exit(0);
  }

  // Running state is tracked from our own child process (no pgrep).
  void _refreshStatus() {
    if (mounted && _tor == null && running) setState(() => running = false);
  }

  // One keep-alive client for the app's own requests through Tor (IP lookups, geolocation, Onionoo): connections
  // to the same host are reused instead of paying SOCKS + TLS setup over a 3-hop circuit each time.
  // Dropped whenever the Tor session ends so no stale socket survives a reconnect.
  HttpClient? _torClient;
  HttpClient _sharedTorClient() {
    final c = _torClient ??= HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..idleTimeout = const Duration(seconds: 60);
    SocksTCPClient.assignToHttpClient(c, [ProxySettings(InternetAddress.loopbackIPv4, 9050)]);
    return c;
  }

  void _dropTorClient() {
    _torClient?.close(force: true);
    _torClient = null;
  }

  /// Plain HTTP GET, optionally through Tor's SOCKS5 proxy (no curl needed).
  Future<String> _get(String url, {bool viaTor = false, int timeout = 20}) async {
    final client = viaTor ? _sharedTorClient() : (HttpClient()..connectionTimeout = Duration(seconds: timeout));
    try {
      final req = await client.getUrl(Uri.parse(url)).timeout(Duration(seconds: timeout));
      final res = await req.close().timeout(Duration(seconds: timeout));
      return await res.transform(utf8.decoder).join().timeout(Duration(seconds: timeout));
    } finally {
      if (!viaTor) client.close(force: true);
    }
  }

  /// GET returning status/body/headers (for conditional requests), optionally through Tor's SOCKS5 proxy.
  Future<({int status, String body, Map<String, String> headers})> _getFull(String url, Map<String, String> reqHeaders,
      {bool viaTor = false, int timeout = 20}) async {
    final client = viaTor ? _sharedTorClient() : (HttpClient()..connectionTimeout = Duration(seconds: timeout));
    try {
      final req = await client.getUrl(Uri.parse(url)).timeout(Duration(seconds: timeout));
      reqHeaders.forEach(req.headers.set);
      final res = await req.close().timeout(Duration(seconds: timeout));
      final body = await res.transform(utf8.decoder).join().timeout(Duration(seconds: timeout * 2));
      final h = <String, String>{};
      res.headers.forEach((k, v) => h[k.toLowerCase()] = v.join(', '));
      return (status: res.statusCode, body: body, headers: h);
    } finally {
      if (!viaTor) client.close(force: true);
    }
  }

  /// Onionoo answers are cached on disk (30 min TTL, conditional requests after that), so reconnecting and the
  /// periodic refresh do not re-download the relay list, and connecting never has to wait for it.
  late final OnionooCache _onionoo = OnionooCache(
    dir: Directory('${_cfgDir.path}/onionoo'),
    fetch: (url, h) => _getFull(url, h, viaTor: running && _tor != null, timeout: 40),
  );

  static final _ipRe = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');

  Future<void> _loadRealIp() async {
    if (_sysActive) return; // all traffic is tunnelled: a lookup would return the exit IP
    for (final url in ['https://api.ipify.org', 'https://icanhazip.com', 'https://ifconfig.me/ip', 'https://api64.ipify.org']) {
      try {
        final ip = (await _get(url, timeout: 12)).trim();
        if (!_ipRe.hasMatch(ip)) continue;
        if (mounted) setState(() => realIp = ip);
        if (_realLL == null || ip != _realGeoIp) _loadRealGeo(ip);
        return;
      } catch (_) {}
    }
    if (mounted && !_ipRe.hasMatch(realIp)) setState(() => realIp = 'offline'); // keep last good value otherwise
  }

  String? _realGeoIp;
  bool _geoBusy = false;
  File get _realGeoFile => File('${_cfgDir.path}/realgeo.json');

  /// Latitude/longitude/place for [ip], trying several free providers (any one can be rate-limited
  /// or blocked). Looking up an IP number through Tor reveals nothing, so [viaTor] is safe while connected.
  Future<({double lat, double lon, String place})?> _geo(String ip, {bool viaTor = false}) async {
    String place(dynamic city, dynamic country) =>
        [city, country].where((e) => e != null && '$e'.isNotEmpty).join(', ');
    final providers = <String, ({double lat, double lon, String place})? Function(Map<String, dynamic>)>{
      'https://ipinfo.io/$ip/json': (j) {
        final loc = (j['loc'] as String?)?.split(',');
        if (loc == null || loc.length != 2) return null;
        return (lat: double.parse(loc[0]), lon: double.parse(loc[1]), place: place(j['city'], countries[(j['country'] as String? ?? '').toLowerCase()] ?? j['country']));
      },
      'https://get.geojs.io/v1/ip/geo/$ip.json': (j) {
        final la = double.tryParse('${j['latitude']}'), lo = double.tryParse('${j['longitude']}');
        return la == null || lo == null ? null : (lat: la, lon: lo, place: place(j['city'], j['country']));
      },
      'https://ipwho.is/$ip': (j) => j['success'] == false || j['latitude'] == null
          ? null
          : (lat: (j['latitude'] as num).toDouble(), lon: (j['longitude'] as num).toDouble(), place: place(j['city'], j['country'])),
      'https://ipapi.co/$ip/json/': (j) => j['latitude'] == null
          ? null
          : (lat: (j['latitude'] as num).toDouble(), lon: (j['longitude'] as num).toDouble(), place: place(j['city'], j['country_name'])),
    };
    for (final e in providers.entries) {
      try {
        final r = e.value(jsonDecode(await _get(e.key, viaTor: viaTor, timeout: 12)) as Map<String, dynamic>);
        if (r != null) return r;
      } catch (_) {}
    }
    return null;
  }

  /// Lat/lon of the real IP for the map pin. Cached on disk so it shows instantly and survives provider outages.
  Future<void> _loadRealGeo(String ip) async {
    if (_geoBusy) return;
    _geoBusy = true;
    try {
      try {
        final c = jsonDecode(_realGeoFile.readAsStringSync()) as Map<String, dynamic>;
        if (c['ip'] == ip && mounted) {
          _realGeoIp = ip;
          setState(() {
            _realLL = (lat: (c['lat'] as num).toDouble(), lon: (c['lon'] as num).toDouble());
            _realPlace = c['place'] as String?;
          });
          return;
        }
      } catch (_) {}
      final g = await _geo(ip, viaTor: running && _tor != null);
      if (g == null || !mounted) return;
      _realGeoIp = ip;
      setState(() {
        _realLL = (lat: g.lat, lon: g.lon);
        _realPlace = g.place;
      });
      try { _realGeoFile.writeAsStringSync(jsonEncode({'ip': ip, 'lat': g.lat, 'lon': g.lon, 'place': g.place})); } catch (_) {}
    } finally {
      _geoBusy = false;
    }
  }

  /// Exit IP via Tor, trying several providers (any one can be rate-limited).
  Future<void> _loadExitIp({bool silent = false}) async {
    final gen = ++_exitGen; // a newer call supersedes an older one (e.g. location switched mid-lookup)
    setState(() { _loadingExit = !silent; if (!silent) exitIp = '…'; });
    String? result;
    for (var attempt = 0; attempt < 3 && result == null && mounted && running && gen == _exitGen; attempt++) {
      try {
        final j = jsonDecode(await _get('https://ipwho.is/', viaTor: true, timeout: 12)) as Map<String, dynamic>;
        if (j['success'] == true && j['ip'] != null) {
          result = '${j['ip']} — ${j['country']}';
          if (j['latitude'] != null && mounted) {
            _exitLL = (lat: (j['latitude'] as num).toDouble(), lon: (j['longitude'] as num).toDouble());
            _exitPlace = [j['city'], j['country']].where((e) => e != null && '$e'.isNotEmpty).join(', ');
          }
        }
      } catch (_) {}
      if (result != null) break;
      try {
        final j = jsonDecode(await _get('https://api.country.is/', viaTor: true, timeout: 12)) as Map<String, dynamic>;
        if (j['ip'] != null) {
          final name = countries[(j['country'] as String? ?? '').toLowerCase()];
          result = name == null ? '${j['ip']}' : '${j['ip']} — $name';
        }
      } catch (_) {}
      if (result != null) break;
      try {
        final j = jsonDecode(await _get('https://check.torproject.org/api/ip', viaTor: true, timeout: 12)) as Map<String, dynamic>;
        if (j['IP'] != null) result = '${j['IP']}';
      } catch (_) {}
    }
    if (gen != _exitGen) return; // superseded: let the newer lookup report
    if (mounted) setState(() { if (result != null || !silent) exitIp = result ?? 'unavailable'; _loadingExit = false; });
    if (result != null && _exitLL == null && mounted && running) {
      final ip = result.split(' ').first;
      if (_ipRe.hasMatch(ip)) {
        final g = await _geo(ip, viaTor: true);
        if (g != null && mounted && running) setState(() { _exitLL = (lat: g.lat, lon: g.lon); _exitPlace = g.place; });
      }
    }
    if (!mounted || !running) return;
    if (result == null) {
      _unpinExit();
    } else if (_pinnedIp == null) {
      final ip = result.split(' ').first;
      _pinExit(ip);
      if (_pinnedIp != null) {
        await Future.delayed(const Duration(seconds: 5));
        if (mounted && running) _loadExitIp(silent: true);
      }
    }
  }

  /// Download speed, direct when disconnected and through Tor when connected.
  Future<void> _loadSpeed() async {
    if (_loadingSpeed) return;
    final viaTor = running;
    setState(() { _loadingSpeed = true; speed = 'testing…'; });
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      if (viaTor) SocksTCPClient.assignToHttpClient(client, [ProxySettings(InternetAddress.loopbackIPv4, 9050)]);
      final bytes = viaTor ? 2000000 : 5000000;
      final res = await (await client.getUrl(Uri.parse('https://speed.cloudflare.com/__down?bytes=$bytes'))).close().timeout(const Duration(seconds: 40));
      // Time only the transfer (skip connection setup / first byte) for a fairer number.
      Stopwatch? sw;
      var n = 0;
      await for (final c in res.timeout(const Duration(seconds: 40))) {
        if (sw == null) { sw = Stopwatch()..start(); continue; }
        n += c.length;
      }
      sw?.stop();
      final secs = (sw?.elapsedMilliseconds ?? 0) / 1000;
      if (secs <= 0 || n == 0) throw 'no data';
      final mbps = n * 8 / 1e6 / secs;
      if (viaTor && running) _saveMeasured(selectedCountry, mbps);
      if (mounted) setState(() => speed = '${mbps.toStringAsFixed(1)} Mbps · ${viaTor ? 'via VPN Desk' : 'direct'}');
    } catch (_) {
      if (mounted) setState(() => speed = 'unavailable');
    } finally {
      client.close(force: true);
      if (mounted) setState(() => _loadingSpeed = false);
    }
  }

  Future<void> _setSystemProxy(bool on) => Plat.setSystemProxy(on);

  String? _pinnedIp;
  Map<String, double> _estMbps = {};
  bool _statsFailed = false, _statsBusy = false;
  Map<String, double> _rttMs = {};  // live ping per country (ms)
  DateTime? _statsAt;

  Set<String> _noExits = {};
  Map<String, double> _measured = {}; // smoothed (EWMA) live measurements, fresh ones only
  final Smoothed _measuredS = Smoothed(alpha: 0.4, maxAge: const Duration(hours: 1));
  final Smoothed _rttS = Smoothed(alpha: 0.4, maxAge: const Duration(hours: 1));
  final Smoothed _kS = Smoothed(alpha: 0.3, maxAge: const Duration(hours: 24)); // throughput x RTT calibration
  final Map<String, DateTime> _rttProbedAt = {};
  final AutoSwitch _autoRule = AutoSwitch();

  // Auto-fastest: keep the app on the location with the highest (measured, else estimated) speed.
  bool _autoFastest = false;
  DateTime _lastAutoSwitch = DateTime.fromMillisecondsSinceEpoch(0);
  File get _settingsFile => File('${_cfgDir.path}/settings.json');

  void _loadSettings() {
    try {
      final m = jsonDecode(_settingsFile.readAsStringSync()) as Map;
      _autoFastest = m['autoFastest'] == true;
      _systemWide = m['systemWide'] == true && Plat.systemWideProblem() == null;
      final last = m['country'];
      if (last is String && countries.containsKey(last)) selectedCountry = last; // last used location
    } catch (_) {}
  }

  void _saveSettings() {
    try { _settingsFile.writeAsStringSync(jsonEncode({'autoFastest': _autoFastest, 'systemWide': _systemWide, 'country': selectedCountry})); } catch (_) {}
  }

  void _setAuto(bool on) {
    setState(() => _autoFastest = on);
    _saveSettings();
    if (on) _autoSwitch(force: true);
  }

  // ---- Optional system-wide mode (all apps through Tor via an nftables transparent proxy) ----
  bool _systemWide = false; // user preference
  bool _sysActive = false; // this connection is running in system-wide mode
  bool _netBlocked = false; // helper left traffic blocked (tor crashed / stale rules)
  String _ctlPass = '';

  Future<void> _toggleSystemWide() async {
    if (running || connecting) return;
    if (_systemWide) {
      setState(() => _systemWide = false);
      _saveSettings();
      return;
    }
    final problem = Plat.systemWideProblem();
    if (problem != null) {
      await _info('System-wide mode unavailable', problem);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1830),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        title: const Text('Route the whole computer through Tor?'),
        content: const SizedBox(
          width: 460,
          child: Text(
            'When you connect, VPN Desk will ask for your administrator password once, then send all TCP traffic and DNS from every app through Tor, on any desktop (GNOME, KDE, …).\n\n'
            '• Tor cannot carry UDP, so QUIC/HTTP3, games and voice calls are blocked while connected (browsers fall back to HTTPS).\n'
            '• IPv6 is blocked; local-network addresses (192.168.x.x etc.) stay direct.\n'
            '• If Tor crashes, traffic stays blocked until you press Restore, so nothing leaks.\n'
            '• Disconnecting or closing the app restores normal networking.',
            style: TextStyle(height: 1.45, color: Colors.white70),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enable')),
        ],
      ),
    );
    if (ok == true && mounted) {
      setState(() => _systemWide = true);
      _saveSettings();
    }
  }

  Future<void> _info(String title, String body) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0E1830),
          title: Text(title),
          content: Text(body, style: const TextStyle(color: Colors.white70, height: 1.4)),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );

  Future<void> _restoreNetwork() async {
    final ok = await Plat.restoreNetwork();
    if (!mounted) return;
    if (ok) {
      Session.end();
      setState(() => _netBlocked = false);
      _loadRealIp();
    } else {
      await _info('Could not restore', 'Administrator permission was not granted. Try again, or run:  pkexec ${Plat.helperPath ?? 'vpndesk-net'} stop');
    }
  }

  /// Point tor at [exitNodes] without dropping it: control port in system-wide mode, torrc+reload otherwise.
  Future<void> _applyExit(String exitNodes) async {
    if (_tor == null) return;
    if (_sysActive) {
      await Plat.controlSend(_ctlPass, ['SETCONF ExitNodes="$exitNodes" StrictNodes=1']);
    } else {
      _writeTorrc(exitNodes);
      await Plat.reloadTor(_tor!, '${_cfgDir.path}/data');
    }
  }

  double _speedOf(String c) => _measured[c] ?? _estMbps[c] ?? 0;

  String? _bestCountry() {
    String? best;
    for (final c in countries.keys) {
      if (_noExits.contains(c) || !(_measured.containsKey(c) || _estMbps.containsKey(c))) continue;
      if (best == null || _speedOf(c) > _speedOf(best)) best = c;
    }
    return best;
  }

  /// Disconnected: just pre-select the fastest. Connected: switch only if clearly faster (25% margin), not within
  /// 5 minutes of the last switch, and comparing like with like (smoothed measurements, or estimates for both).
  Future<void> _autoSwitch({bool force = false}) async {
    if (!_autoFastest || connecting || !mounted) return;
    if (!running) {
      final best = _bestCountry();
      if (best == null || best == selectedCountry) return;
      setState(() => selectedCountry = best);
      _countryCtrl?.text = countries[best]!;
      return;
    }
    final best = _autoRule.pick(
      current: selectedCountry,
      candidates: countries.keys.where((c) => !_noExits.contains(c)),
      measured: (c) => _measured[c],
      estimate: (c) => _estMbps[c],
      now: DateTime.now(),
      lastSwitch: _lastAutoSwitch,
      force: force,
    );
    if (best == null) return;
    _lastAutoSwitch = DateTime.now();
    setState(() => log += 'Auto-fastest: switching to ${countries[best]} (~${_speedOf(best).toStringAsFixed(1)} Mbps)\n');
    await _selectCountry(best);
  }

  File get _measuredFile => File('${_cfgDir.path}/measured.json');

  void _loadMeasured() {
    try {
      final m = jsonDecode(_measuredFile.readAsStringSync()) as Map<String, dynamic>;
      if (m['v'] == 2) {
        _measuredS.load(m['measured'], DateTime.now());
        _kS.load(m['k'], DateTime.now());
      } // the old format (plain country -> Mbps, no timestamps) is dropped: it could be days old
    } catch (_) {}
    _syncMeasured();
  }

  void _syncMeasured() {
    final now = DateTime.now();
    _measured = {
      for (final c in countries.keys)
        if (_measuredS.value(c, now) != null) c: _measuredS.value(c, now)!
    };
  }

  void _saveMeasured(String cc, double mbps) {
    final now = DateTime.now();
    _measuredS.add(cc, mbps, now);
    final rtt = _rttMs[cc];
    if (rtt != null) _kS.add('k', mbps * rtt, now);
    _syncMeasured();
    try { _measuredFile.writeAsStringSync(jsonEncode({'v': 2, 'measured': _measuredS.toJson(), 'k': _kS.toJson()})); } catch (_) {}
  }

  /// TCP connect time to a relay's OR port (direct, no Tor) in ms, or null if unreachable.
  Future<double?> _rtt(String addr) async {
    final i = addr.lastIndexOf(':');
    double? best;
    for (var k = 0; k < 2; k++) {
      final sw = Stopwatch()..start();
      try {
        final sock = await Socket.connect(addr.substring(0, i), int.parse(addr.substring(i + 1)), timeout: const Duration(seconds: 3));
        sock.destroy();
        final ms = sw.elapsedMicroseconds / 1000;
        if (best == null || ms < best) best = ms;
      } catch (_) {}
    }
    return best;
  }

  /// Estimate per country: Tor throughput is dominated by round-trip distance to the exit region,
  /// capped by the exit relay's bandwidth. Real measurements (after connecting) replace estimates.
  Future<void> _loadCountryStats() async {
    if (_statsBusy) return;
    _statsBusy = true;
    _loadMeasured();
    try {
      final out = await _onionoo.get('details?flag=Exit&running=true&fields=country,observed_bandwidth,or_addresses,flags,fingerprint&limit=3000&order=-consensus_weight');
      if (out == null) throw 'no relay data';
      final top = <String, List<Map<String, dynamic>>>{};
      for (final r in (jsonDecode(out)['relays'] as List).cast<Map<String, dynamic>>()) {
        final cc = r['country'] as String?;
        if (cc == null || (r['flags'] as List).contains('BadExit')) continue;
        final l = top.putIfAbsent(cc, () => []);
        if (l.length < 3) l.add(r);
      }
      final est = <String, double>{}, rtts = <String, double>{};
      final now = DateTime.now();
      // Probe the selected country and the current top few every minute; the rest only every 10 minutes
      // (each probe is a direct connection to a relay, so probing every country every minute was needless load).
      final ranked = countries.keys.where((c) => !_noExits.contains(c)).toList()..sort((a, b) => _speedOf(b).compareTo(_speedOf(a)));
      final hot = {selectedCountry, ...ranked.take(5)};
      await Future.wait(countries.keys.where(top.containsKey).map((cc) async {
        final due = !_rttMs.containsKey(cc) || hot.contains(cc) || now.difference(_rttProbedAt[cc] ?? DateTime.fromMillisecondsSinceEpoch(0)) > const Duration(minutes: 10);
        // While connected, direct probes would reveal the real IP to relays: reuse the last RTT.
        if (!running && due) {
          double? best;
          for (final r in top[cc]!) {
            final v4 = (r['or_addresses'] as List).cast<String>().where((a) => !a.startsWith('[')).toList();
            if (v4.isEmpty) continue;
            final t = await _rtt(v4.first);
            if (t != null && (best == null || t < best)) best = t;
          }
          if (best != null) { _rttS.add(cc, best, now); _rttProbedAt[cc] = now; }
        }
        final rtt = _rttS.value(cc, now) ?? _rttMs[cc]; // smoothed; last known if the samples aged out while connected
        if (rtt != null) rtts[cc] = rtt;
        final bwMbps = ((top[cc]!.first['observed_bandwidth'] as num?) ?? 0) * 8 / 1e6;
        est[cc] = bwMbps * 0.04; // relay-bandwidth cap; combined with live RTT below
      }));
      // Throughput ~ k / RTT. k is a smoothed calibration from this machine's real Tor measurements
      // (mbps x rtt); until one exists, fall back to 400 (seed from one old sample).
      final k = _kS.value('k', now) ?? 400.0;
      for (final cc in est.keys.toList()) {
        final byDistance = rtts.containsKey(cc) ? k / rtts[cc]! : 1.0;
        est[cc] = (byDistance < est[cc]! ? byDistance : est[cc]!).clamp(0.2, 100.0);
      }
      _syncMeasured();
      if (mounted) {
        setState(() {
        _estMbps = est;
        _rttMs = rtts;
        _statsAt = DateTime.now();
        _statsFailed = false;
        _noExits = countries.keys.where((c) => !top.containsKey(c)).toSet();
      });
      }
      _autoSwitch();
    } catch (_) {
      if (mounted) setState(() => _statsFailed = true);
    } finally {
      _statsBusy = false;
    }
  }

  bool _switching = false;
  int _switchGen = 0;

  /// Change exit country without ever dropping Tor or the system proxy: re-point ExitNodes on the live
  /// tor. SOCKS stays up and ExitNodes is strict, so traffic waits for a new circuit instead of going
  /// direct, and the real IP is never exposed mid-switch.
  /// The UI (highlight, pin) updates immediately; a newer request supersedes an older one.
  Future<void> _switchLive(String cc) async {
    if (_tor == null) return;
    final gen = ++_switchGen;
    final oldIp = exitIp.split(' ').first;
    setState(() {
      _switching = true;
      selectedCountry = cc;
      exitIp = '…';
      _exitLL = null; // map shows the new country's pin right away
      _exitPlace = null;
      log += 'Switching to ${countries[cc]} (proxy stays on)…\n';
    });
    _countryCtrl?.text = countries[cc]!;
    bool stale() => !mounted || _tor == null || gen != _switchGen;
    try {
      // Whole country, strict. 'pending' stops the lookup from pinning the OLD exit while the switch is in flight.
      _pinnedIp = 'pending';
      await _applyExit('{$cc}');
      // Poll a tiny IP-only endpoint through Tor until the exit actually changes, then show it at once;
      // the full lookup (country, location pin) follows.
      for (var i = 0; i < 10 && !stale(); i++) {
        await Future.delayed(Duration(milliseconds: i == 0 ? 600 : 900));
        if (stale()) return;
        try {
          final ip = (await _get('https://api.ipify.org', viaTor: true, timeout: 8)).trim();
          if (_ipRe.hasMatch(ip) && ip != oldIp) {
            if (!stale()) setState(() => exitIp = '$ip — ${countries[cc]}');
            _pinnedIp = null; // the exit really changed: now it is safe to pin the new relay
            break;
          }
        } catch (_) {}
      }
      if (stale()) return;
      await _loadExitIp(silent: true);
      if (!stale() && running) _loadSpeed();
    } finally {
      if (mounted && gen == _switchGen) setState(() => _switching = false);
    }
  }

  Future<void> _selectCountry(String cc) async {
    if (_noExits.contains(cc) || (cc == selectedCountry && (running || connecting))) return;
    if (running && _tor != null) {
      await _switchLive(cc);
      return;
    }
    final wasOn = connecting;
    setState(() => selectedCountry = cc);
    _countryCtrl?.text = countries[cc]!;
    if (wasOn) {
      await _stop();
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) _start();
    }
  }

  Widget _sidebar() {
    final list = countries.keys.toList()
      ..sort((a, b) {
        double v(String c) => _noExits.contains(c) ? -2 : (_measured[c] ?? _estMbps[c] ?? -1);
        return v(b).compareTo(v(a));
      });
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.025)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 30, offset: const Offset(0, 12))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(children: [
            const Icon(Icons.public, size: 18, color: Colors.tealAccent),
            const SizedBox(width: 8),
            const Text('Locations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Spacer(),
            Text(_statsFailed ? 'offline' : (_estMbps.isEmpty ? 'loading…' : 'live est. · ${_statsAt == null ? '' : '${DateTime.now().difference(_statsAt!).inSeconds}s ago'}'),
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            itemCount: list.length,
            itemBuilder: (_, i) => _CountryTile(
              key: ValueKey(list[i]),
              index: i,
                            name: countries[list[i]]!,
              mbps: _measured[list[i]] ?? _estMbps[list[i]],
              pingMs: _rttMs[list[i]],
              measured: _measured.containsKey(list[i]),
              unavailable: _noExits.contains(list[i]),
              code: list[i].toUpperCase(),
              selected: list[i] == selectedCountry,
              active: list[i] == selectedCountry && running,
              onTap: () => _selectCountry(list[i]),
            ),
          ),
        ),
      ]),
    );
  }

  String _entryNodes = '';

  void _writeTorrc(String exitNodes) {
    File(_torrcPath).writeAsStringSync(buildTorrc(
      dataDir: Plat.torPath(_cfgDir.path),
      exitNodes: exitNodes,
      geoipLines: Plat.geoipLines(),
      controlLines: Plat.controlLines('${_cfgDir.path}/data'),
      entryNodes: _entryNodes,
      ownerPid: pid,
    ));
  }

  String _relayPath(String filter, int limit) =>
      'details?running=true&order=-consensus_weight&limit=${limit + 4}&fields=fingerprint,flags&$filter';

  List<String> _parseRelays(String? out, int limit) {
    if (out == null) return [];
    try {
      final relays = (jsonDecode(out)['relays'] as List).cast<Map<String, dynamic>>();
      return [
        for (final r in relays)
          if (!(r['flags'] as List).contains('BadExit')) r['fingerprint'] as String
      ].take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  /// Highest-bandwidth relays so the single shared circuit is as fast as possible. Cached on disk;
  /// [cacheOnly] never touches the network (used so that connecting does not wait for Onionoo).
  Future<List<String>> _topRelays(String filter, int limit, {bool cacheOnly = false}) async {
    final path = _relayPath(filter, limit);
    if (cacheOnly) return _parseRelays(_onionoo.peek(path, maxStale: const Duration(hours: 24)), limit);
    return _parseRelays(await _onionoo.get(path), limit);
  }

  /// Pin to the exit relay we just saw so every app shows the same IP.
  int _bootPct = 0; // real progress from tor's "Bootstrapped N%" lines
  static final _bootRe = RegExp(r'Bootstrapped (\d+)%');
  void _trackBootstrap(String s) {
    final m = _bootRe.allMatches(s);
    if (m.isNotEmpty) _bootPct = int.parse(m.last.group(1)!);
  }

  /// After connecting: refresh the relay lists in the background (through Tor) so the next connect has fresh guards.
  Future<void> _warmRelayCache() async {
    await _topRelays('flag=Guard', 12);
  }

  void _pinExit(String ip) {
    if (_pinnedIp != null || _tor == null || !RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(ip)) return;
    _pinnedIp = ip;
    _applyExit(ip);
  }

  void _unpinExit() {
    if (_pinnedIp == null || _tor == null) return;
    _pinnedIp = null;
    _applyExit('{$selectedCountry}');
  }

  Future<void> _start() async {
    if (_autoFastest) {
      final best = _bestCountry();
      if (best != null) {
        selectedCountry = best;
        _countryCtrl?.text = countries[best]!;
      }
      _lastAutoSwitch = DateTime.now();
    }
    final typed = _countryCtrl?.text.trim().toLowerCase() ?? '';
    final match = countries.entries.where((e) => e.value.toLowerCase() == typed);
    if (match.isNotEmpty) {
      selectedCountry = match.first.key;
    } else if (typed.isNotEmpty) {
      setState(() => log = 'Unknown country "$typed" - pick one from the list.\n');
      return;
    }
    if (_noExits.contains(selectedCountry)) {
      setState(() => log = '${countries[selectedCountry]} has no Tor exit relays - pick another location.\n');
      return;
    }
    setState(() { connecting = true; log = ''; _bootPct = 0; });
    _saveSettings(); // remember the location for next launch
    if (Plat.linux) {
      // Journal first, before anything on the system is touched; the watchdog repairs it if we get killed.
      Session.begin(_systemWide && Plat.systemWideProblem() == null ? 'system-wide' : 'default');
      Plat.startWatchdog();
    }
    // An orphaned tor from a previous app run (e.g. killed with pkill) would hold port 9050.
    await Plat.killStaleTor();
    _dropTorClient();
    _pinnedIp = null;
    // Connecting must not wait for Onionoo: guards come from the disk cache, and the exit is the whole country
    // (still StrictNodes 1). Benchmarks showed no speed difference against pinning the single top relay
    // (docs/bench/DECISIONS.md), and not pinning avoids sending every user to the same volunteer relay. Once the
    // exit IP is seen, _pinExit keeps that relay so every app shows one stable IP.
    final guards = await _topRelays('flag=Guard', 12, cacheOnly: true);
    _entryNodes = guards.map((f) => '\$$f').join(',');
    final exitNodes = '{$selectedCountry}';
    setState(() => log += 'Connecting (any exit in ${countries[selectedCountry]})…\n');
    if (_systemWide && Plat.systemWideProblem() == null) {
      await _startSystemWide(exitNodes);
      return;
    }
    _writeTorrc(exitNodes);
    try {
      _tor = await Process.start(Plat.torExecutable(), ['-f', Plat.torPath(_torrcPath)], environment: Plat.torEnv());
      Plat.rememberTor(_tor!.pid);
      _tor!.stdout.transform(SystemEncoding().decoder).listen((s) {
        if (!mounted) return;
        setState(() {
          log += s;
          _trackBootstrap(s);
          if (s.contains('Bootstrapped 100%')) {
            connecting = false;
            running = true;
            _setSystemProxy(true);
            _loadExitIp();
            _loadSpeed();
            _loadRealIp();
            _warmRelayCache();
          }
        });
      });
      _tor!.stderr.transform(SystemEncoding().decoder).listen((s) {
        if (mounted) setState(() => log += s);
      });
      final proc = _tor!;
      proc.exitCode.then((_) async {
        if (!identical(_tor, proc)) return; // a newer connection already replaced this one
        _tor = null;
        _dropTorClient();
        await _setSystemProxy(false);
        Session.end();
        if (mounted) setState(() { running = false; connecting = false; });
      });
    } catch (e) {
      await _setSystemProxy(false);
      Session.end();
      setState(() { log = 'Failed to start tor: $e\n'; connecting = false; });
    }
  }

  /// System-wide connect: one pkexec prompt, then the helper installs nftables rules and runs tor.
  Future<void> _startSystemWide(String exitNodes) async {
    _ctlPass = Plat.randomHex(16);
    final hash = await Plat.hashPassword(_ctlPass);
    if (hash == null) {
      Session.end();
      setState(() { log += 'Could not prepare the Tor control password.\n'; connecting = false; });
      return;
    }
    final torrc = 'ExitNodes $exitNodes\nStrictNodes 1\n'
        '${_entryNodes.isEmpty ? '' : 'EntryNodes $_entryNodes\n'}'
        'HashedControlPassword $hash\nMaxCircuitDirtiness 86400\nNewCircuitPeriod 86400\n__OwningControllerProcess $pid\n';
    setState(() { log += 'Waiting for administrator permission…\n'; _netBlocked = false; });
    try {
      final p = await Plat.startSystemWide(torrc);
      _tor = p;
      _sysActive = true;
      p.stdout.transform(SystemEncoding().decoder).listen((s) {
        if (!mounted) return;
        setState(() {
          log += s;
          _trackBootstrap(s);
          if (s.contains('VPNDESK_BLOCKED')) _netBlocked = true;
          if (s.contains('Bootstrapped 100%')) {
            connecting = false;
            running = true;
            _loadExitIp();
            _loadSpeed();
            _warmRelayCache();
          }
        });
      });
      p.stderr.transform(SystemEncoding().decoder).listen((s) {
        if (mounted) setState(() => log += s);
      });
      p.exitCode.then((code) {
        if (!identical(_tor, p)) return;
        _tor = null;
        _sysActive = false;
        // Blocked = fail-closed table still installed on purpose: keep the journal so recovery can lift it.
        if (Plat.netState() == 'none') Session.end();
        if (!mounted) return;
        setState(() {
          if (code == 126 || code == 127) log += 'Administrator permission was not granted — system-wide mode not started.\n';
          if (Plat.netState() == 'blocked') _netBlocked = true;
          running = false;
          connecting = false;
        });
      });
    } catch (e) {
      Session.end();
      setState(() { log += 'Failed to start system-wide mode: $e\n'; connecting = false; _sysActive = false; });
    }
  }

  Future<void> _stop() async {
    final wasSys = _sysActive;
    await _teardown();
    if (!mounted) return;
    setState(() { running = false; connecting = false; exitIp = '—'; _exitLL = null; log += wasSys ? '\nStopped. Normal networking restored.\n' : '\nStopped.\n'; });
    if (wasSys) _loadRealIp();
    _loadSpeed();
  }

  Widget _winDot(Color c, VoidCallback onTap) => _WinDot(color: c, onTap: onTap);

  static const _teal = Color(0xFF2DE2C4), _amber = Color(0xFFFFC857), _red = Color(0xFFFF6B6B);

  Widget _glass({required Widget child, EdgeInsets padding = const EdgeInsets.all(16), Color? glow}) => Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.025)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          boxShadow: [BoxShadow(color: (glow ?? Colors.black).withValues(alpha: 0.22), blurRadius: 30, offset: const Offset(0, 12))],
        ),
        child: child,
      );

  /// Splits "main — detail" / "main · detail" into a big value and a small caption.
  (String, String?) _split(String v) {
    for (final sep in [' — ', ' · ']) {
      final i = v.indexOf(sep);
      if (i > 0) return (v.substring(0, i), v.substring(i + sep.length));
    }
    return (v, null);
  }

  Widget _statCard(String title, String value, IconData icon, Color accent,
      {String? sub, VoidCallback? onRefresh, bool loading = false, bool compact = false}) {
    final (main, detail) = _split(value);
    final caption = sub ?? detail;
    return Expanded(
      child: _glass(
        glow: accent,
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 15, color: accent),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
            ),
            if (onRefresh != null) _RefreshButton(onTap: onRefresh, loading: loading),
          ]),
          SizedBox(height: compact ? 8 : 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Align(
              key: ValueKey(main),
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(main, style: TextStyle(fontSize: compact ? 18 : 22, fontWeight: FontWeight.w700, letterSpacing: 0.3, fontFeatures: const [FontFeature.tabularFigures()])),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(caption ?? ' ', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _statusOrb() {
    final color = running ? _teal : (connecting ? _amber : const Color(0xFF64748B));
    return AnimatedBuilder(
      animation: _dotCtrl,
      builder: (_, _) {
        final pulse = (running || connecting) ? _dotCtrl.value : 0.0;
        return SizedBox(
          width: 64, height: 64,
          child: Stack(alignment: Alignment.center, children: [
            Container(
              width: 44 + 20 * pulse, height: 44 + 20 * pulse,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.18 * (1 - pulse))),
            ),
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [color.withValues(alpha: 0.95), color.withValues(alpha: 0.55)]),
                boxShadow: [BoxShadow(color: color.withValues(alpha: running ? 0.6 : 0.25), blurRadius: 18)],
              ),
              child: Icon(running ? Icons.lock : (connecting ? Icons.sync : Icons.lock_open), size: 19, color: const Color(0xFF07101F)),
            ),
          ]),
        );
      },
    );
  }

  Widget _connectButton() {
    final disabled = connecting;
    final colors = running ? [const Color(0xFFFF8A8A), _red] : [_teal, const Color(0xFF22B8CF)];
    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: disabled ? null : (running ? _stop : _start),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 26),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: disabled ? [Colors.white24, Colors.white12] : colors),
            boxShadow: disabled ? null : [BoxShadow(color: colors.last.withValues(alpha: 0.45), blurRadius: 22, offset: const Offset(0, 8))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(running ? Icons.power_settings_new : Icons.bolt, color: const Color(0xFF07101F), size: 20),
            const SizedBox(width: 8),
            Text(connecting ? 'Connecting…' : (running ? 'Disconnect' : 'Connect'),
                style: const TextStyle(color: Color(0xFF07101F), fontWeight: FontWeight.w800, fontSize: 15)),
          ]),
        ),
      ),
    );
  }

  Widget _autoToggle() => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Tooltip(
          message: 'Automatically use the location with the highest speed',
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _setAuto(!_autoFastest),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: _autoFastest ? _teal.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.06),
                  border: Border.all(color: _autoFastest ? _teal : Colors.white24),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.bolt, size: 15, color: _autoFastest ? _teal : Colors.white54),
                  const SizedBox(width: 4),
                  Text('Auto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _autoFastest ? _teal : Colors.white54)),
                ]),
              ),
            ),
          ),
        ),
      );

  Widget _countryField() => Autocomplete<String>(
        initialValue: TextEditingValue(text: countries[selectedCountry]!),
        optionsBuilder: (v) => (running || _autoFastest) ? const Iterable<String>.empty() : countries.values.where((n) => n.toLowerCase().contains(v.text.toLowerCase())),
        onSelected: (name) => setState(() => selectedCountry = countries.entries.firstWhere((e) => e.value == name).key),
        fieldViewBuilder: (ctx, ctrl, focus, onSubmit) {
          _countryCtrl = ctrl;
          return TextField(
            controller: ctrl, focusNode: focus,
            // readOnly (not enabled:false) so the Auto chip in the suffix stays tappable.
            readOnly: running || _autoFastest,
            style: TextStyle(color: (running || _autoFastest) ? Colors.white54 : null),
            onChanged: (v) { for (final e in countries.entries) { if (e.value.toLowerCase() == v.toLowerCase()) selectedCountry = e.key; } },
            decoration: InputDecoration(
              hintText: _autoFastest ? 'Fastest available' : 'Search a country…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _autoToggle(),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _teal)),
            ),
          );
        },
      );

  Widget _systemWidePill() {
    final locked = running || connecting;
    final problem = Plat.systemWideProblem();
    final on = _systemWide && problem == null;
    final color = on ? _teal : Colors.white54;
    return Tooltip(
      message: problem ?? (locked ? 'Disconnect to change this' : 'Send all apps\' traffic through Tor (asks for administrator permission)'),
      child: MouseRegion(
        cursor: locked ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: locked ? null : _toggleSystemWide,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: (locked && !on) || problem != null ? 0.55 : 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: on ? _teal.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: on ? _teal : Colors.white24),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(on ? Icons.shield : Icons.shield_outlined, size: 14, color: color),
                const SizedBox(width: 6),
                Flexible(child: Text(on ? 'System-wide: on · all apps' : 'System-wide: off · browser/proxy apps only',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color))),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _recoveryBanner() {
    final c = _recoveryFailed ? _amber : _teal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: c.withValues(alpha: 0.10),
          border: Border.all(color: c.withValues(alpha: 0.5)),
        ),
        child: Row(children: [
          Icon(_recoveryFailed ? Icons.info_outline_rounded : Icons.check_circle_outline_rounded, color: c),
          const SizedBox(width: 12),
          Expanded(child: Text(_recoveryNote!, style: const TextStyle(fontSize: 13, height: 1.35))),
          IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => setState(() => _recoveryNote = null)),
        ]),
      ),
    );
  }

  Widget _blockedBanner() => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _red.withValues(alpha: 0.12),
            border: Border.all(color: _red.withValues(alpha: 0.6)),
          ),
          child: Row(children: [
            const Icon(Icons.gpp_maybe_rounded, color: _red),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Internet is blocked: a previous system-wide session ended unexpectedly. Restore normal networking, or connect again.',
                  style: TextStyle(fontSize: 13, height: 1.35)),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: _restoreNetwork,
              style: FilledButton.styleFrom(backgroundColor: _red, foregroundColor: const Color(0xFF07101F)),
              child: const Text('Restore'),
            ),
          ]),
        ),
      );

  Widget _hero(double width) {
    final title = connecting ? 'Connecting…' : (running ? 'Protected' : 'Not protected');
    final sub = _switching ? 'Switching location — traffic stays inside Tor' : running ? '${_sysActive ? 'System-wide · ' : ''}${_autoFastest ? 'Auto-fastest · ' : ''}Exit in ${countries[selectedCountry]} · SOCKS5 127.0.0.1:9050' : (connecting ? (_bootPct > 0 ? 'Building a Tor circuit · $_bootPct%' : 'Starting Tor…') : 'Pick a country and connect');
    final head = Row(children: [
      _statusOrb(),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: running ? _teal : Colors.white)),
          const SizedBox(height: 2),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 8),
          _systemWidePill(),
        ]),
      ),
    ]);
    final controls = [Expanded(child: _countryField()), const SizedBox(width: 12), _connectButton()];
    return _glass(
      glow: running ? _teal : null,
      padding: const EdgeInsets.all(18),
      child: width >= 760
          ? Row(children: [Expanded(flex: 5, child: head), const SizedBox(width: 20), Expanded(flex: 6, child: Row(children: controls))])
          : Column(mainAxisSize: MainAxisSize.min, children: [head, const SizedBox(height: 14), Row(children: controls)]),
    );
  }

  Widget _legendDot(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle, boxShadow: [BoxShadow(color: c, blurRadius: 6)])),
        const SizedBox(width: 6),
        Text(t, style: const TextStyle(fontSize: 11, color: Colors.white70, letterSpacing: 0.4)),
      ]);

  Widget _mapPanel() => Stack(children: [
        Positioned.fill(
          child: WorldMap(
            country: selectedCountry,
            connected: running,
            real: _realLL,
            exit: running ? _exitLL : null,
            realLabel: _realLL == null ? null : '$realIp${_realPlace == null ? '' : ' · $_realPlace'}',
            exitLabel: running && exitIp.contains(RegExp(r'\d')) ? '${exitIp.split(' — ').first}${_exitPlace == null ? '' : ' · $_exitPlace'}' : null,
          ),
        ),
        Positioned(
          left: 14, bottom: 12,
          child: Row(children: [_legendDot(_amber, 'Real'), const SizedBox(width: 14), _legendDot(_teal, 'Exit')]),
        ),
      ]);

  Widget _mainColumn(double width, double height) {
    final compact = width < 640 || height < 640;
    final (_, speedDetail) = _split(speed);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_recoveryNote != null) _recoveryBanner(),
      if (_netBlocked && !connecting && !running) _blockedBanner(),
      _hero(width),
      const SizedBox(height: 14),
      Row(children: [
        _statCard('Real IP', realIp, Icons.home_rounded, _amber, sub: _realPlace, compact: compact),
        const SizedBox(width: 12),
        _statCard('Exit IP', exitIp, Icons.public, _teal, onRefresh: running ? _loadExitIp : null, loading: _loadingExit, sub: running ? _exitPlace : null, compact: compact),
        const SizedBox(width: 12),
        _statCard('Speed', speed, Icons.speed, const Color(0xFF7C9CFF), onRefresh: _loadSpeed, loading: _loadingSpeed, sub: speedDetail, compact: compact),
      ]),
      const SizedBox(height: 14),
      Expanded(child: _mapPanel()),
    ]);
  }

  Widget _windowDots() => Row(children: [
        _winDot(const Color(0xFFFF5F57), _quit),
        _winDot(const Color(0xFFFEBC2E), () => appWindow.minimize()),
        _winDot(const Color(0xFF28C840), () => appWindow.maximizeOrRestore()),
      ]);

  Widget _aboutButton() => Tooltip(
        message: 'About VPN Desk',
        child: TextButton.icon(
          onPressed: () => Navigator.of(context).push(aboutRoute(_windowDots(), onUninstall: Plat.linux ? _beginUninstall : null)),
          style: TextButton.styleFrom(foregroundColor: Colors.white70, backgroundColor: Colors.white.withValues(alpha: 0.06), shape: const StadiumBorder()),
          icon: const Icon(Icons.info_outline_rounded, size: 16),
          label: const Text('About'),
        ),
      );

  Widget _blob(Alignment a, Color c, double size) => Align(
        alignment: a,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c.withValues(alpha: 0.22), c.withValues(alpha: 0)])),
        ),
      );

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        _syncPulse();
        final showSidebar = box.maxWidth >= 860;
        final sideW = (box.maxWidth * 0.28).clamp(250.0, 330.0);
        return Scaffold(
          extendBodyBehindAppBar: true,
          endDrawer: showSidebar ? null : Drawer(width: 300, backgroundColor: Colors.transparent, child: Padding(padding: const EdgeInsets.all(12), child: _sidebar())),
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(40),
            child: GestureDetector(
              onPanStart: (_) => appWindow.startDragging(),
              onDoubleTap: () => appWindow.maximizeOrRestore(),
              child: Container(
                color: Colors.transparent,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(children: [
                  _winDot(const Color(0xFFFF5F57), _quit),
                  _winDot(const Color(0xFFFEBC2E), () => appWindow.minimize()),
                  _winDot(const Color(0xFF28C840), () => appWindow.maximizeOrRestore()),
                  const SizedBox(width: 16),
                  ClipRRect(borderRadius: BorderRadius.circular(5), child: Image.asset('assets/icon.png', width: 20, height: 20, filterQuality: FilterQuality.medium)),
                  const SizedBox(width: 8),
                  const Text('VPN Desk', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.3)),
                  const Spacer(),
                  if (!showSidebar)
                    Builder(builder: (ctx) => TextButton.icon(
                          onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                          icon: const Icon(Icons.public, size: 16),
                          label: const Text('Locations'),
                        )),
                  const SizedBox(width: 6),
                  _aboutButton(),
                ]),
              ),
            ),
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF070D1A), Color(0xFF0E1830), Color(0xFF070D1A)]),
            ),
            child: Stack(children: [
              _blob(const Alignment(-1, -1), _teal, 520),
              _blob(const Alignment(1, 1), const Color(0xFF7C5CFF), 560),
              // Same top/bottom padding for the dashboard and the sidebar keeps their heights equal.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: LayoutBuilder(builder: (_, c) => _mainColumn(c.maxWidth, box.maxHeight))),
                  if (showSidebar) ...[const SizedBox(width: 16), SizedBox(width: sideW, child: _sidebar())],
                ]),
              ),
            ]),
          ),
        );
      });
}

/// Small animated pill button: spins while loading, glows on hover.
class _RefreshButton extends StatefulWidget {
  const _RefreshButton({required this.onTap, required this.loading});
  final VoidCallback onTap;
  final bool loading;
  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  bool _hover = false;

  @override
  void didUpdateWidget(_RefreshButton old) {
    super.didUpdateWidget(old);
    if (widget.loading && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.loading && _spin.isAnimating) {
      _spin.animateTo(1).whenComplete(() => _spin.reset());
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.loading) _spin.repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.loading ? null : widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(colors: _hover
                  ? [const Color(0xFF14B8A6), const Color(0xFF6366F1)]
                  : [const Color(0xFF14B8A6).withValues(alpha: 0.25), const Color(0xFF6366F1).withValues(alpha: 0.25)]),
              border: Border.all(color: Colors.tealAccent.withValues(alpha: _hover ? 0.9 : 0.35)),
              boxShadow: _hover ? [BoxShadow(color: Colors.tealAccent.withValues(alpha: 0.35), blurRadius: 10)] : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              RotationTransition(turns: _spin, child: const Icon(Icons.refresh_rounded, size: 15, color: Colors.white)),
              const SizedBox(width: 5),
              Text(widget.loading ? 'Checking' : 'Refresh', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
            ]),
          ),
        ),
      );
}

/// Animated country button: staggered slide-in, hover lift/glow, selected highlight.
class _CountryTile extends StatefulWidget {
  const _CountryTile({super.key, required this.index, required this.code, required this.name, required this.mbps, this.pingMs, required this.measured, required this.unavailable, required this.selected, required this.active, required this.onTap});
  final int index;
  final String code, name;
  final double? mbps;
  final double? pingMs;
  final bool measured, unavailable, selected, active;
  final VoidCallback onTap;
  @override
  State<_CountryTile> createState() => _CountryTileState();
}

class _CountryTileState extends State<_CountryTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    if (widget.unavailable) return Opacity(opacity: 0.4, child: _body(context, sel));
    return _body(context, sel);
  }

  Widget _body(BuildContext context, bool sel) {
    final frac = widget.mbps == null ? 0.0 : (widget.mbps! / 8).clamp(0.05, 1.0);
    final barColor = Color.lerp(const Color(0xFFF59E0B), const Color(0xFF22C55E), frac)!;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (widget.index.clamp(0, 12)) * 45),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Opacity(opacity: t, child: Transform.translate(offset: Offset(24 * (1 - t), 0), child: child)),
      child: MouseRegion(
        cursor: widget.unavailable ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            transform: Matrix4.translationValues(_hover ? -3 : 0, 0, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: sel
                  ? const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF4F46E5)])
                  : null,
              color: sel ? null : (_hover ? const Color(0xFF1B2A44) : const Color(0xFF16233A)),
              border: Border.all(color: sel ? Colors.tealAccent.withValues(alpha: 0.8) : (_hover ? const Color(0xFF3B5278) : Colors.transparent)),
              boxShadow: sel || _hover ? [BoxShadow(color: (sel ? Colors.tealAccent : Colors.white).withValues(alpha: sel ? 0.25 : 0.08), blurRadius: 12)] : null,
            ),
            child: Row(children: [
              Container(
                width: 32, height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6)),
                child: Text(widget.code, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.name, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.bold : FontWeight.w500)),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: frac),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 4, backgroundColor: Colors.white12, color: barColor),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 68,
                child: Text(widget.unavailable ? 'no exits' : (widget.mbps == null ? '—' : '${widget.measured ? '' : '~'}${widget.mbps!.toStringAsFixed(1)} Mbps${widget.pingMs == null ? '' : ' · ${widget.pingMs!.round()} ms'}'),
                    textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: widget.measured ? const Color(0xFF5EEAD4) : Colors.white70, fontWeight: widget.measured ? FontWeight.bold : FontWeight.normal, fontFamily: 'monospace')),
              ),
              if (widget.active) ...[
                const SizedBox(width: 6),
                const Icon(Icons.check_circle, size: 15, color: Color(0xFF22C55E)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// Mac-style window dot: grows, glows and shows its glyph (x / - / +) under the pointer.
class _WinDot extends StatefulWidget {
  const _WinDot({required this.color, required this.onTap});
  final Color color;
  final VoidCallback onTap;
  @override
  State<_WinDot> createState() => _WinDotState();
}

class _WinDotState extends State<_WinDot> {
  bool _hover = false, _down = false;

  IconData get _glyph => switch (widget.color.toARGB32()) {
        0xFFFF5F57 => Icons.close_rounded,
        0xFFFEBC2E => Icons.remove_rounded,
        _ => Icons.add_rounded,
      };

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() { _hover = false; _down = false; }),
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _down = true),
          onTapUp: (_) => setState(() => _down = false),
          onTapCancel: () => setState(() => _down = false),
          child: SizedBox(
            width: 22, height: 22, // fixed hit area so growing doesn't shift neighbours
            child: Center(
              child: AnimatedScale(
                scale: _down ? 0.88 : (_hover ? 1.35 : 1),
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutBack,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 14, height: 14,
                  decoration: BoxDecoration(
                    color: _hover ? Color.lerp(widget.color, Colors.white, 0.12) : widget.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black26),
                    boxShadow: _hover ? [BoxShadow(color: widget.color.withValues(alpha: 0.75), blurRadius: 10, spreadRadius: 1)] : null,
                  ),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: _hover ? 1 : 0,
                    child: Icon(_glyph, size: 11, color: Colors.black.withValues(alpha: 0.65)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

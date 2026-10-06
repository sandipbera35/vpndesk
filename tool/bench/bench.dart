// OnionDesk benchmark harness (Linux). Starts its OWN tor on private ports with a private DataDirectory,
// so it never touches the app, the system proxy or the firewall.
//
//   dart tool/bench/bench.dart run --variant baseline --country de
//   dart tool/bench/bench.dart ab  --a baseline --b exitset3 --country de --pairs 10
//
// Measures per tor session: bootstrap (cold/warm), time to first request, TTFB of a small HTTPS GET,
// single-stream and parallel-stream download throughput. Output: JSON + markdown in docs/bench/.
// Dev-only: control-port telemetry (--telemetry) is written to a local file and never sent anywhere.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'stats.dart';
import 'variants.dart';

const ttfbUrl = 'https://www.cloudflare.com/cdn-cgi/trace';
String downUrl(int bytes) => 'https://speed.cloudflare.com/__down?bytes=$bytes';

late final Map<String, String> opt;
int get ttfbN => int.parse(opt['ttfb-n'] ?? '30');
int get dlN => int.parse(opt['dl-n'] ?? '10');
int get parN => int.parse(opt['par-n'] ?? '10');
int get streams => int.parse(opt['streams'] ?? '4');
int get dlBytes => int.parse(opt['bytes'] ?? '3000000');
int get maxTime => int.parse(opt['max-time'] ?? '120');
bool get multiDest => opt.containsKey('multidest');
int get rerollMbps => int.parse(opt['reroll-mbps'] ?? '5');

/// Four unrelated download hosts (all support Range), for the circuit-isolation experiment.
List<(String, String?)> destinations(int bytes) => [
      (downUrl(bytes), null),
      ('https://download.thinkbroadband.com/10MB.zip', '0-${bytes - 1}'),
      ('https://nbg1-speed.hetzner.com/100MB.bin', '0-${bytes - 1}'),
      ('https://hel1-speed.hetzner.com/100MB.bin', '0-${bytes - 1}'),
    ];

String get country => (opt['country'] ?? 'de').toLowerCase();

String bundleDir() => '${Directory.current.path}/build/linux/x64/release/bundle/tor';

Future<String> httpGet(String url) async {
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 25);
  try {
    final r = await (await c.getUrl(Uri.parse(url))).close();
    return await r.transform(utf8.decoder).join();
  } finally {
    c.close(force: true);
  }
}

/// Same Onionoo queries the app uses (lib/main.dart `_topRelays`), so the baseline matches real behaviour.
Future<List<String>> topRelays(String filter, int limit) async {
  final out = await httpGet('https://onionoo.torproject.org/details?running=true&order=-consensus_weight&limit=${limit + 4}&fields=fingerprint,flags&$filter');
  final relays = (jsonDecode(out)['relays'] as List).cast<Map<String, dynamic>>();
  return [for (final r in relays) if (!(r['flags'] as List).contains('BadExit')) r['fingerprint'] as String].take(limit).toList();
}

class Tor {
  final Process proc;
  final Socket? ctl;
  Tor(this.proc, this.ctl);
}

class Session {
  final String variant;
  final String torVersion;
  final bool cold;
  double bootstrapS = double.nan, firstRequestS = double.nan;
  final ttfb = <double>[], single = <double>[], parallel = <double>[];
  int failures = 0, attempts = 0, rerolls = 0;
  double rerollOverheadS = 0;
  Map<String, Object?> meta = {};
  Session(this.variant, this.torVersion, this.cold);

  Map<String, Object?> toJson() => {
        'variant': variant,
        'tor': torVersion,
        'cold': cold,
        'bootstrap_s': bootstrapS.isNaN ? null : double.parse(bootstrapS.toStringAsFixed(2)),
        'first_request_s': firstRequestS.isNaN ? null : double.parse(firstRequestS.toStringAsFixed(2)),
        'ttfb_s': ttfb,
        'single_mbps': single,
        'parallel_mbps': parallel,
        'failures': failures,
        'attempts': attempts,
        'rerolls': rerolls,
        'reroll_overhead_s': double.parse(rerollOverheadS.toStringAsFixed(1)),
        'meta': meta,
      };
}

/// curl through the SOCKS port with remote DNS. Returns [ttfb s, speed bytes/s, size] or null on failure.
Future<List<double>?> curl(int port, String url, {int maxT = 30, String? range}) async {
  final r = await Process.run('curl', [
    '-sS', '-o', '/dev/null', if (range != null) ...['-r', range], '--socks5-hostname', '127.0.0.1:$port', '--max-time', '$maxT',
    '-w', '%{time_starttransfer} %{speed_download} %{size_download} %{http_code}', url,
  ]);
  if (r.exitCode != 0) return null;
  final p = (r.stdout as String).trim().split(' ');
  if (p.length < 4 || (p[3] != '200' && p[3] != '206')) return null;
  return [double.parse(p[0]), double.parse(p[1]), double.parse(p[2])];
}

Future<String> torVersion(String exe, Map<String, String> env) async {
  final r = await Process.run(exe, ['--version'], environment: env);
  return (r.stdout as String).split('\n').first.replaceFirst('Tor version ', '').split(' ').first;
}

/// One tor session: launch, bootstrap, measure, stop.
Future<Session> runSession(String variant, {required bool cold, required Ctx base, IOSink? telemetry, bool bootstrapOnly = false}) async {
  final dir = Directory(base.dataDir);
  if (cold && dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);
  final torDir = bundleDir();
  final exe = '$torDir/tor';
  final env = {'LD_LIBRARY_PATH': torDir};
  final s = Session(variant, await torVersion(exe, env), cold);
  final torrc = File('${base.dataDir}/../torrc-$variant')..writeAsStringSync(variants[variant]!(base));
  final v = await Process.run(exe, ['--verify-config', '-f', torrc.path], environment: env);
  if (v.exitCode != 0) throw StateError('tor --verify-config rejected variant $variant:\n${v.stdout}${v.stderr}');
  final sw = Stopwatch()..start();
  final proc = await Process.start(exe, ['-f', torrc.path], environment: env);
  final boot = Completer<void>();
  proc.stdout.transform(utf8.decoder).listen((t) {
    if (t.contains('Bootstrapped 100%') && !boot.isCompleted) boot.complete();
  });
  proc.stderr.drain<void>();
  Socket? ctl;
  try {
    await boot.future.timeout(const Duration(minutes: 5));
    s.bootstrapS = sw.elapsedMilliseconds / 1000;
    ctl = await _telemetry(base, telemetry);
    // time to first successful request after connect
    sw..reset()..start();
    for (var i = 0; i < 20; i++) {
      final r = await curl(base.socksPort, ttfbUrl, maxT: 20);
      if (r != null) { s.firstRequestS = sw.elapsedMilliseconds / 1000; break; }
    }
    if (!bootstrapOnly && rerollVariants.contains(variant)) {
      // Probe the circuit; if it is slower than the threshold ask tor for a new one (NEWNYM), up to 3 times.
      final t = Stopwatch()..start();
      for (var k = 0; k < 3; k++) {
        final r = await curl(base.socksPort, downUrl(1500000), maxT: 40);
        if (r != null && r[1] * 8 / 1e6 >= rerollMbps) break;
        if (!await newnym(base)) break;
        s.rerolls++;
        await Future.delayed(const Duration(seconds: 11)); // tor rate-limits NEWNYM to one per 10 s
      }
      s.rerollOverheadS = t.elapsedMilliseconds / 1000;
    }
    for (var i = 0; !bootstrapOnly && i < ttfbN; i++) {
      s.attempts++;
      final r = await curl(base.socksPort, ttfbUrl);
      r == null ? s.failures++ : s.ttfb.add(r[0]);
    }
    for (var i = 0; !bootstrapOnly && i < dlN; i++) {
      s.attempts++;
      final r = await curl(base.socksPort, downUrl(dlBytes), maxT: maxTime);
      r == null ? s.failures++ : s.single.add(r[1] * 8 / 1e6);
    }
    for (var i = 0; !bootstrapOnly && i < parN; i++) {
      s.attempts++;
      final t = Stopwatch()..start();
      final d = destinations(dlBytes);
      final rs = await Future.wait([
        for (var k = 0; k < streams; k++)
          multiDest ? curl(base.socksPort, d[k % d.length].$1, maxT: maxTime, range: d[k % d.length].$2) : curl(base.socksPort, downUrl(dlBytes), maxT: maxTime)
      ]);
      t.stop();
      final ok = rs.whereType<List<double>>().toList();
      if (ok.length < streams) { s.failures++; continue; }
      s.parallel.add(ok.map((r) => r[2]).reduce((a, b) => a + b) * 8 / 1e6 / (t.elapsedMilliseconds / 1000));
    }
    s.meta = {'exits': base.exits.take(8).toList(), 'guards': base.guards.take(12).toList(), 'country': base.country};
  } finally {
    ctl?.destroy();
    proc.kill();
    await proc.exitCode.timeout(const Duration(seconds: 5), onTimeout: () { proc.kill(ProcessSignal.sigkill); return 0; });
  }
  return s;
}

/// SIGNAL NEWNYM over the control port (cookie auth, loopback only).
Future<bool> newnym(Ctx c) async {
  try {
    final cookie = File('${c.dataDir}/control_auth_cookie').readAsBytesSync();
    final hex = cookie.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final s = await Socket.connect('127.0.0.1', c.controlPort);
    s.write('AUTHENTICATE $hex\r\nSIGNAL NEWNYM\r\nQUIT\r\n');
    final out = await s.cast<List<int>>().transform(utf8.decoder).join().timeout(const Duration(seconds: 5), onTimeout: () => '');
    s.destroy();
    return RegExp('250 OK').allMatches(out).length >= 2;
  } catch (_) {
    return false;
  }
}

/// Dev-only: CIRC / STATUS_CLIENT / BW events to a local file. Nothing leaves the machine.
Future<Socket?> _telemetry(Ctx c, IOSink? out) async {
  if (out == null) return null;
  try {
    final cookie = File('${c.dataDir}/control_auth_cookie').readAsBytesSync();
    final hex = cookie.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final s = await Socket.connect('127.0.0.1', c.controlPort);
    s.write('AUTHENTICATE $hex\r\nSETEVENTS CIRC STATUS_CLIENT BW\r\n');
    s.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen((l) {
      if (l.startsWith('650')) out.writeln(jsonEncode({'t': DateTime.now().toIso8601String(), 'ev': l}));
    });
    return s;
  } catch (_) {
    return null;
  }
}

String fmt(double v) => v.isNaN ? '–' : v.toStringAsFixed(2);

String table(String title, Map<String, List<Session>> bySession, {required bool cold}) {
  final b = StringBuffer('### $title\n\n| variant | runs | bootstrap s (med) | 1st req s (med) | TTFB s med / p90 / sd (n) | 1-stream Mbps med / p90 / sd (n) | $streams-stream Mbps med / p90 / sd (n) | failures |\n|---|---|---|---|---|---|---|---|\n');
  for (final e in bySession.entries) {
    final ss = e.value;
    final t = Stats([for (final s in ss) ...s.ttfb]), one = Stats([for (final s in ss) ...s.single]), par = Stats([for (final s in ss) ...s.parallel]);
    final boot = Stats([for (final s in ss) s.bootstrapS]), fr = Stats([for (final s in ss) s.firstRequestS]);
    String c(Stats x, [int d = 2]) => '${fmt(x.median)} / ${fmt(x.p90)} / ${fmt(x.stddev)} (${x.n})';
    b.writeln('| ${e.key} | ${ss.length} | ${fmt(boot.median)} | ${fmt(fr.median)} | ${c(t)} | ${c(one)} | ${c(par)} | ${ss.fold<int>(0, (a, s) => a + s.failures)}/${ss.fold<int>(0, (a, s) => a + s.attempts)}${ss.any((s) => s.rerolls > 0 || s.rerollOverheadS > 0) ? ' · rerolls ${ss.fold<int>(0, (a, s) => a + s.rerolls)}, overhead med ${fmt(Stats([for (final s in ss) s.rerollOverheadS]).median)} s' : ''} |');
  }
  return b.toString();
}

Future<Ctx> makeCtx(String name, {String? dataDir}) async {
  final td = bundleDir();
  final exits = await topRelays('flag=Exit&country=$country', 8);
  final guards = await topRelays('flag=Guard', 12);
  final cache = '${Platform.environment['HOME']}/.cache/oniondesk-bench';
  return Ctx(
      dataDir: dataDir ?? '$cache/data-$name', geoip: '$td/geoip', geoip6: '$td/geoip6', socksPort: 19050, controlPort: 19051,
      exits: exits, guards: guards, country: country, ownerPid: pid);
}

Future<void> save(String label, Map<String, Object?> json, String md) async {
  Directory('docs/bench').createSync(recursive: true);
  final stamp = DateTime.now().toIso8601String().substring(0, 16).replaceAll(':', '');
  File('docs/bench/$stamp-$label.json').writeAsStringSync(const JsonEncoder.withIndent(' ').convert(json));
  File('docs/bench/$stamp-$label.md').writeAsStringSync(md);
  stdout.writeln('wrote docs/bench/$stamp-$label.{json,md}');
}

Future<void> main(List<String> args) async {
  if (args.isEmpty || !{'run', 'ab'}.contains(args.first)) {
    stderr.writeln('usage: bench.dart run|ab [--variant V | --a A --b B] [--country cc] [--pairs N] [--cold] [--telemetry]');
    exit(64);
  }
  final cmd = args.first;
  opt = {};
  for (var i = 1; i < args.length; i++) {
    if (args[i].startsWith('--')) {
      final k = args[i].substring(2);
      opt[k] = (i + 1 < args.length && !args[i + 1].startsWith('--')) ? args[++i] : 'true';
    }
  }
  if (!File('${bundleDir()}/tor').existsSync()) { stderr.writeln('Bundled tor missing: run flutter build linux --release && ./bundle_tor.sh'); exit(1); }
  final tele = opt.containsKey('telemetry') ? File('docs/bench/telemetry-${DateTime.now().millisecondsSinceEpoch}.jsonl').openWrite() : null;
  final meta = {'date': DateTime.now().toIso8601String(), 'country': country, 'multidest': multiDest, 'reroll_mbps': rerollMbps, 'os': Platform.operatingSystemVersion, 'bytes': dlBytes, 'streams': streams};

  if (cmd == 'run') {
    final v = opt['variant'] ?? 'baseline';
    final ctx = await makeCtx(v);
    final all = <Session>[];
    final cold = opt.containsKey('cold') ? await runSession(v, cold: true, base: ctx, telemetry: tele, bootstrapOnly: true) : null;
    all.add(await runSession(v, cold: false, base: ctx, telemetry: tele));
    if (cold != null) all.insert(0, cold);
    final md = '# Benchmark: $v ($country)\n\n${meta.entries.map((e) => '- ${e.key}: ${e.value}').join('\n')}\n- tor: ${all.first.torVersion}\n- exits: ${ctx.exits.take(3).join(', ')}\n\n${table(v, {for (final x in all) '$v ${x.cold ? 'cold' : 'warm'}': [x]}, cold: false)}';
    await save('$v-$country', {'meta': meta, 'sessions': [for (final s in all) s.toJson()]}, md);
    stdout.writeln(md);
  } else {
    final a = opt['a'] ?? 'baseline', b = opt['b']!, pairs = int.parse(opt['pairs'] ?? '10');
    final ca = await makeCtx(a), cb = await makeCtx(b);
    final res = {a: <Session>[], b: <Session>[]};
    for (var i = 0; i < pairs; i++) {
      stdout.writeln('pair ${i + 1}/$pairs');
      // A,B then B,A alternately so slow drift in Tor load does not favour one side
      for (final (name, ctx) in (i.isEven ? [(a, ca), (b, cb)] : [(b, cb), (a, ca)])) {
        try {
          res[name]!.add(await runSession(name, cold: false, base: ctx, telemetry: tele));
        } catch (e) {
          stdout.writeln('  $name failed: $e');
        }
      }
    }
    final md = '# A/B: $a vs $b ($country, $pairs interleaved pairs)\n\n${meta.entries.map((e) => '- ${e.key}: ${e.value}').join('\n')}\n\n${table('$a vs $b', res, cold: false)}';
    await save('ab-$a-vs-$b-$country', {'meta': meta, 'results': {for (final e in res.entries) e.key: [for (final s in e.value) s.toJson()]}}, md);
    stdout.writeln(md);
  }
  await tele?.close();
}

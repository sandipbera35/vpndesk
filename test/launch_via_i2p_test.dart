import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:oniondesk/launch_via_i2p.dart';

void main() {
  test('plain program: I2P proxy variables only, no Tor ones', () {
    final s = buildI2pLaunch('qbittorrent --webui-port=9000', profileDir: '/p');
    expect(s.executable, 'qbittorrent');
    expect(s.args, ['--webui-port=9000']);
    expect(s.env['http_proxy'], 'http://127.0.0.1:4444');
    expect(s.env['https_proxy'], 'http://127.0.0.1:4444');
    expect(s.env['ALL_PROXY'], 'socks5h://127.0.0.1:4447');
    expect(s.env.values.any((v) => v.contains('9050')), isFalse);
  });

  test('your own environment is kept', () {
    final s = buildI2pLaunch('app', profileDir: '/p', base: {'HOME': '/home/x'});
    expect(s.env['HOME'], '/home/x');
  });

  test('firefox gets a private profile; chromium gets proxy flags and a profile', () {
    final f = buildI2pLaunch('firefox https://x.i2p', profileDir: '/p/ff');
    expect(f.args.take(3), ['-no-remote', '-profile', '/p/ff']);
    final c = buildI2pLaunch('chromium', profileDir: '/p/c');
    expect(c.args, contains('--proxy-server=http=127.0.0.1:4444;https=127.0.0.1:4444'));
    expect(c.args.any((a) => a.startsWith('--host-resolver-rules')), isFalse, reason: 'Chrome warns about this flag');
    expect(c.args, contains('--user-data-dir=/p/c'));
  });

  test('flatpak apps get the proxy explicitly', () {
    final s = buildI2pLaunch('flatpak run org.example.App', profileDir: '/p');
    expect(s.args.take(3), ['run', '--env=http_proxy=http://127.0.0.1:4444', '--env=https_proxy=http://127.0.0.1:4444']);
    expect(s.args.last, 'org.example.App');
  });

  test('firefox profile points at i2pd', () {
    final js = firefoxI2pUserJs();
    expect(js, contains('network.proxy.http_port", 4444'));
    expect(js, contains('network.proxy.socks_port", 4447'));
    expect(js, contains('socks_remote_dns", true'));
    expect(js, isNot(contains('9050')));
  });

  test('labels for the saved list', () {
    expect(appLabel('/usr/bin/firefox --new-window'), 'firefox');
    expect(appLabel('flatpak run org.mozilla.firefox'), 'org.mozilla.firefox');
    expect(appLabel('flatpak run --user org.example.App'), 'org.example.App');
    expect(appLabel(''), '');
  });

  test('empty command is refused', () {
    expect(() => buildI2pLaunch('   ', profileDir: '/p'), throwsFormatException);
  });

  test('force shim: a plain program gets LD_PRELOAD + the proxychains config, existing LD_PRELOAD is kept', () {
    final s = buildI2pLaunch('someapp', profileDir: '/p', base: {'LD_PRELOAD': '/x.so'}, forceLib: '/b/libproxychains4.so', forceConf: '/c/pc.conf');
    expect(s.env['LD_PRELOAD'], '/b/libproxychains4.so:/x.so');
    expect(s.env['PROXYCHAINS_CONF_FILE'], '/c/pc.conf');
    expect(s.env['PROXYCHAINS_QUIET_MODE'], '1');
    expect(s.notes.join(), contains('Forced through I2P'));
    expect(buildI2pLaunch('someapp', profileDir: '/p', forceLib: '/b/l.so', forceConf: '/c').env['LD_PRELOAD'], '/b/l.so');
  });

  test('force shim is not used for browsers or flatpak (they have their own mechanism), nor when absent', () {
    for (final l in ['firefox', 'chromium', 'flatpak run org.x.App']) {
      expect(buildI2pLaunch(l, profileDir: '/p', forceLib: '/b/l.so', forceConf: '/c').env.containsKey('LD_PRELOAD'), isFalse, reason: l);
    }
    expect(buildI2pLaunch('someapp', profileDir: '/p').env.containsKey('LD_PRELOAD'), isFalse);
  });

  test('proxychains config: i2pd SOCKS port, names resolved remotely, loopback left alone', () {
    final c = proxychainsConf();
    expect(c, contains('proxy_dns'));
    expect(c, contains('localnet 127.0.0.0/255.0.0.0'));
    expect(c, contains('socks5 127.0.0.1 4447'));
  });

  // Real shim. Needs PROXYCHAINS_LIB=/path/to/libproxychains4.so (built by build_proxychains_linux.sh) and curl.
  test('REAL: a program that ignores proxy settings is forced to send its host name to the I2P SOCKS port', () async {
    final lib = Platform.environment['PROXYCHAINS_LIB'];
    if (lib == null || !Platform.isLinux) return;
    ServerSocket srv;
    try {
      srv = await ServerSocket.bind(InternetAddress.loopbackIPv4, 4447);
    } catch (_) {
      return; // a real i2pd is using the port
    }
    addTearDown(srv.close);
    final seen = Completer<String>();
    srv.listen((c) {
      c.done.catchError((_) {});
      var step = 0;
      final buf = <int>[];
      c.listen((d) {
        buf.addAll(d);
        if (step == 0) {
          c.add([5, 0]);
          step = 1;
          buf.clear();
        } else if (step == 1 && buf.length >= 5) {
          final n = buf[4];
          if (buf.length >= 5 + n + 2) {
            if (!seen.isCompleted) seen.complete(utf8.decode(buf.sublist(5, 5 + n)));
            c.add([5, 5, 0, 1, 0, 0, 0, 0, 0, 0]); // refuse: we only want to see the request
            step = 2;
          }
        }
      }, onError: (_) {});
    }, onError: (_) {});
    final dir = Directory.systemTemp.createTempSync('pcforce');
    addTearDown(() => dir.deleteSync(recursive: true));
    final conf = File('${dir.path}/pc.conf')..writeAsStringSync(proxychainsConf());
    final spec = buildI2pLaunch('curl', profileDir: dir.path, base: Platform.environment, forceLib: lib, forceConf: conf.path);
    final r = await Process.run('curl', ['-s', '-m', '8', '--noproxy', '*', 'http://forced-test.i2p/'], environment: spec.env);
    expect(r.exitCode, isNot(0)); // the fake proxy refuses
    expect(await seen.future.timeout(const Duration(seconds: 3)), 'forced-test.i2p');
  });
}

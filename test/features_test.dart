import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oniondesk/autostart.dart';
import 'package:oniondesk/blocklist.dart';
import 'package:oniondesk/blocklist_update.dart';
import 'package:oniondesk/l10n.dart' show L10n, kRtl;
import 'package:oniondesk/l10n_strings.dart';
import 'package:oniondesk/installed_apps.dart';
import 'package:oniondesk/launch_via_tor.dart';
import 'package:oniondesk/leak_test.dart';
import 'package:oniondesk/tor_control.dart';
import 'package:oniondesk/update_check.dart';

void main() {
  moreTests();
  launchTests();
  l10nTests();
  streamTests();
  appListTests();
  group('circuit-status parsing', () {
    const out = '250+circuit-status=\r\n'
        '7 BUILT \$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA~guard,\$BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB~mid,\$CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC~exit BUILD_FLAGS=NEED_CAPACITY PURPOSE=GENERAL TIME_CREATED=x\r\n'
        '9 BUILT \$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA~guard,\$DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD~mid2,\$EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE~exit2 PURPOSE=GENERAL\r\n'
        '10 BUILT \$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA~guard,\$DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD~hs PURPOSE=HS_CLIENT_INTRO\r\n'
        '11 EXTENDED \$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA~guard PURPOSE=GENERAL\r\n'
        '.\r\n250 OK\r\n';

    test('parses ids, status, purpose and hops', () {
      final c = parseCircuitStatus(out);
      expect(c.map((e) => e.id), ['7', '9', '10', '11']);
      expect(c.first.hops.map((h) => h.nickname), ['guard', 'mid', 'exit']);
      expect(c.first.hops.first.fingerprint, 'A' * 40);
      expect(c[2].purpose, 'HS_CLIENT_INTRO');
    });

    test('picks the newest built general 3-hop circuit', () {
      expect(pickUserCircuit(parseCircuitStatus(out))!.id, '9');
    });

    test('nothing usable gives null', () {
      expect(pickUserCircuit(parseCircuitStatus('250 OK\r\n')), isNull);
      expect(pickUserCircuit(const []), isNull);
    });
  });

  group('control-port geo answers', () {
    test('ns/id r-lines give the relay IPs in order', () {
      const out = '250+ns/id/AAAA=\r\nr guard AAAAAAAAAAAAAAAAAAAAAAAAAAA BBBBBBBBBBBBBBBBBBBBBBBBBBB 2026-10-06 12:00:00 185.220.101.1 9001 0\r\ns Fast Guard\r\n.\r\n250 OK\r\n'
          '250+ns/id/BBBB=\r\nr mid CCCCCCCCCCCCCCCCCCCCCCCCCCC DDDDDDDDDDDDDDDDDDDDDDDDDDD 2026-10-06 12:00:00 51.15.0.2 443 80\r\ns Fast\r\n.\r\n250 OK\r\n';
      expect(parseNsIps(out), ['185.220.101.1', '51.15.0.2']);
    });
    test('ip-to-country answers', () {
      final m = parseIpCountry('250-ip-to-country/185.220.101.1=de\r\n250-ip-to-country/9.9.9.9=??\r\n250 OK\r\n');
      expect(m['185.220.101.1'], 'de');
      expect(m['9.9.9.9'], '??');
    });
  });

  group('update check', () {
    test('version comparison', () {
      expect(isNewer('1.1.4', '1.1.5'), isTrue);
      expect(isNewer('1.1.4', 'v1.2.0'), isTrue);
      expect(isNewer('1.1.4', '2.0.0'), isTrue);
      expect(isNewer('1.1.4', '1.1.4'), isFalse);
      expect(isNewer('1.1.4', '1.1.3'), isFalse);
      expect(isNewer('1.1.4', '1.10.0'), isTrue); // numeric, not lexical
      expect(isNewer('1.1.4', 'banana'), isFalse);
      expect(isNewer('x', '1.0.0'), isFalse);
    });

    test('release JSON: drafts, prereleases, bad links and malformed answers are ignored', () {
      Map<String, dynamic> j({String tag = 'v9.0.0', String url = 'https://github.com/o/r/releases/tag/v9.0.0', bool draft = false, bool pre = false}) =>
          {'tag_name': tag, 'html_url': url, 'draft': draft, 'prerelease': pre};
      expect(parseLatest(j(), '1.1.4')!.version, '9.0.0');
      expect(parseLatest(j(draft: true), '1.1.4'), isNull);
      expect(parseLatest(j(pre: true), '1.1.4'), isNull);
      expect(parseLatest(j(url: 'http://evil.example/x'), '1.1.4'), isNull);
      expect(parseLatest(j(tag: 'v1.1.4'), '1.1.4'), isNull);
      expect(parseLatest({'message': 'rate limited'}, '1.1.4'), isNull);
    });

    test('kAppVersion matches pubspec.yaml', () {
      final v = RegExp(r'^version: (\d+\.\d+\.\d+)', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1);
      expect(kAppVersion, v);
    });
  });

  group('leak verdicts', () {
    LeakInputs inp({String? real = '1.1.1.1', String? proxy = '9.9.9.9', bool? isTor = true, String? direct = '1.1.1.1', bool? directTor = false, bool sys = false, bool? dns = true}) =>
        LeakInputs(realIp: real, proxyIp: proxy, proxyIsTor: isTor, directIp: direct, directIsTor: directTor, systemWide: sys, dnsViaProxyOk: dns);
    LeakLevel lvl(List<LeakCheck> c, int i) => c[i].level;

    test('healthy proxy mode: proxy ok, dns ok, ignoring apps warned, webrtc note', () {
      final c = evaluateLeaks(inp());
      expect([lvl(c, 0), lvl(c, 1), lvl(c, 2), lvl(c, 3)], [LeakLevel.ok, LeakLevel.ok, LeakLevel.warn, LeakLevel.warn]);
    });

    test('proxy shows the real IP: fail', () {
      expect(lvl(evaluateLeaks(inp(proxy: '1.1.1.1')), 0), LeakLevel.fail);
    });

    test('no answer through the proxy: fail', () {
      expect(lvl(evaluateLeaks(inp(proxy: null)), 0), LeakLevel.fail);
    });

    test('exit not recognised as Tor: warn, not ok', () {
      expect(lvl(evaluateLeaks(inp(isTor: false)), 0), LeakLevel.warn);
    });

    test('system-wide: a plain connection must leave through Tor', () {
      expect(lvl(evaluateLeaks(inp(sys: true, direct: '9.9.9.9', directTor: true)), 2), LeakLevel.ok);
      expect(lvl(evaluateLeaks(inp(sys: true, direct: '1.1.1.1', directTor: false)), 2), LeakLevel.fail);
    });

    test('dns failure is reported', () {
      expect(lvl(evaluateLeaks(inp(dns: false)), 1), LeakLevel.fail);
      expect(lvl(evaluateLeaks(inp(dns: null)), 1), LeakLevel.warn);
    });
  });
}

// ---- autostart + ad list update ----
void moreTests() {
  group('autostart builders', () {
    test('linux entry quotes the path and passes --autostart', () {
      final e = linuxAutostartEntry('/opt/my apps/oniondesk');
      expect(e, contains('Exec="/opt/my apps/oniondesk" --autostart\n'));
      expect(e, contains('X-GNOME-Autostart-enabled=true'));
    });
    test('mac plist is escaped and runs at load', () {
      final e = macLaunchAgent('/Applications/A&B.app/x');
      expect(e, contains('<string>/Applications/A&amp;B.app/x</string>'));
      expect(e, contains('<key>RunAtLoad</key><true/>'));
    });
    test('windows run value', () => expect(windowsRunValue(r'C:\Program Files\OnionDesk\oniondesk.exe'), r'"C:\Program Files\OnionDesk\oniondesk.exe" --autostart'));
    test('linux writer enables and disables a file in XDG_CONFIG_HOME', () async {
      final d = Directory.systemTemp.createTempSync('as_');
      addTearDown(() => d.deleteSync(recursive: true));
      final a = Autostart(env: {'HOME': d.path, 'XDG_CONFIG_HOME': '${d.path}/cfg'}, exe: '/opt/oniondesk/oniondesk');
      expect(await a.isEnabled(), isFalse);
      expect(await a.set(true), isTrue);
      expect(await a.isEnabled(), isTrue);
      expect(File('${d.path}/cfg/autostart/$kAppId.desktop').readAsStringSync(), contains('--autostart'));
      expect(await a.set(false), isTrue);
      expect(await a.isEnabled(), isFalse);
    }, testOn: 'linux');
  });

  group('ad list download validation', () {
    String hosts(int n, {List<String> extra = const []}) => [for (var i = 0; i < n; i++) '0.0.0.0 ad$i.example.net', ...extra.map((h) => '0.0.0.0 $h')].join('\n');

    test('a normal list is accepted', () => expect(rejectList(hosts(5000)), isNull));
    test('too small / not hosts format is rejected', () {
      expect(rejectList(hosts(10)), contains('too small'));
      expect(rejectList('<html>Not found</html>'), contains('too small'));
    });
    test('a list that would block the app or tor is rejected', () {
      expect(rejectList(hosts(5000, extra: ['torproject.org'])), contains('torproject.org'));
      expect(rejectList(hosts(5000, extra: ['cloudflare.com'])), contains('cloudflare.com'));
    });
    test('update writes atomically and reports the count; a bad list leaves the old file alone', () async {
      final d = Directory.systemTemp.createTempSync('bl_');
      addTearDown(() => d.deleteSync(recursive: true));
      final f = File('${d.path}/$kRemoteListFile');
      expect(await updateRemoteList((_) async => hosts(3000), f), 3000);
      final good = f.readAsStringSync();
      await expectLater(updateRemoteList((_) async => hosts(5, extra: ['github.com']), f), throwsA(contains('not updated')));
      expect(f.readAsStringSync(), good);
      expect(File('${f.path}.tmp').existsSync(), isFalse);
    });
    test('Blocklist.load reads bundled + remote + user lists', () {
      final d = Directory.systemTemp.createTempSync('bl2_');
      addTearDown(() => d.deleteSync(recursive: true));
      File('${d.path}/r.txt').writeAsStringSync('0.0.0.0 remote.example.net');
      File('${d.path}/u.txt').writeAsStringSync('user.example.net');
      final b = Blocklist.load('0.0.0.0 bundled.example.net', File('${d.path}/u.txt'), remoteFile: File('${d.path}/r.txt'));
      for (final h in ['bundled.example.net', 'remote.example.net', 'user.example.net']) { expect(b.isBlocked(h), isTrue, reason: h); }
    });
  });
}

void launchTests() {
  group('splitCommand', () {
    test('words, quotes, escapes', () {
      expect(splitCommand('firefox --private'), ['firefox', '--private']);
      expect(splitCommand('"/opt/my app/run" --x "a b"'), ['/opt/my app/run', '--x', 'a b']);
      expect(splitCommand(r"curl -H 'X: y z' my\ url"), ['curl', '-H', 'X: y z', 'my url']);
      expect(splitCommand('   '), isEmpty);
      expect(splitCommand('a "" b'), ['a', '', 'b']);
    });
    test('unclosed quote is an error', () => expect(() => splitCommand('a "b'), throwsFormatException));
  });

  group('buildLaunch', () {
    LaunchSpec b(String l, {bool ts = false}) => buildLaunch(l, profileDir: '/p', hasTorsocks: ts, base: {'HOME': '/h'});
    test('plain program: proxy env only (socks5h = remote DNS), user env kept', () {
      final s = b('curl -s https://example.com');
      expect(s.executable, 'curl');
      expect(s.args, ['-s', 'https://example.com']);
      expect(s.env['ALL_PROXY'], 'socks5h://127.0.0.1:9050');
      expect(s.env['HOME'], '/h');
      expect(s.notes.single, contains('not covered'));
    });
    test('torsocks wraps unknown programs when available', () {
      final s = b('mycli --a', ts: true);
      expect(s.executable, 'torsocks');
      expect(s.args, ['mycli', '--a']);
      expect(s.env.containsKey('ALL_PROXY'), isFalse, reason: 'torsocks blocks localhost, so no proxy variables with it');
      expect(s.env['HOME'], '/h');
    });
    test('chromium family: proxy flags, no local DNS, own profile, WebRTC non-proxied UDP disabled', () {
      final s = b('/usr/bin/google-chrome https://x.test', ts: true);
      expect(s.executable, '/usr/bin/google-chrome');
      expect(s.args, containsAll(['--proxy-server=socks5://127.0.0.1:9050', '--user-data-dir=/p', '--force-webrtc-ip-handling-policy=disable_non_proxied_udp']));
      expect(s.args.any((a) => a.startsWith('--host-resolver-rules=MAP * ~NOTFOUND')), isTrue);
      expect(s.args.last, 'https://x.test');
    });
    test('firefox: private profile, never torsocks', () {
      final s = b('firefox', ts: true);
      expect(s.args, ['-no-remote', '-profile', '/p']);
      expect(s.executable, 'firefox');
      final js = firefoxUserJs();
      expect(js, contains('socks_remote_dns", true'));
      expect(js, contains('media.peerconnection.enabled", false'));
    });
    test('empty command is rejected', () => expect(() => b('  '), throwsFormatException));
  });
}

void l10nTests() {
  group('translations', () {
    final langs = ['hi', 'bn', 'es', 'ar', 'ru'];
    test('every language has the same keys, non-empty values and the same placeholders', () {
      final base = kTranslations['hi']!;
      for (final l in langs) {
        final t = kTranslations[l]!;
        expect(t.keys.toSet(), base.keys.toSet(), reason: l);
        for (final e in t.entries) {
          expect(e.value.trim(), isNotEmpty, reason: '$l: ${e.key}');
          final ph = RegExp(r'\{\d\}');
          expect(ph.allMatches(e.value).map((m) => m.group(0)).toSet(), ph.allMatches(e.key).map((m) => m.group(0)).toSet(), reason: '$l: ${e.key}');
        }
      }
    });

    test('exact and placeholder strings translate; unknown strings stay English', () {
      expect(L10n.tr('Connect', 'es'), 'Conectar');
      expect(L10n.tr('Disconnect', 'ru'), 'Отключить');
      expect(L10n.tr('live est. · 41s ago', 'ru'), 'оценка · 41 с назад');
      expect(L10n.tr('Exit in Germany · SOCKS5 127.0.0.1:9050', 'es'), 'Salida en Germany · SOCKS5 127.0.0.1:9050');
      expect(L10n.tr('Sites see 1.2.3.4 (a Tor exit), not your real IP.', 'es'), contains('1.2.3.4'));
      expect(L10n.tr('Germany', 'hi'), 'Germany');
      expect(L10n.tr('Connect', 'en'), 'Connect');
      expect(L10n.tr('Connect', 'xx'), 'Connect');
    });

    test('system language detection', () {
      expect(L10n.systemLanguage('es_ES.UTF-8'), 'es');
      expect(L10n.systemLanguage('zh_CN'), 'en'); // not supported: falls back to English
      expect(L10n.systemLanguage('fr_FR.UTF-8'), 'en');
      expect(L10n.systemLanguage('C'), 'en');
    });

    test('arabic is right-to-left, the rest are not', () {
      expect(kRtl, {'ar'});
    });
  });
}

void streamTests() {
  test('stream-status parsing and per-circuit targets', () {
    const out = '250+stream-status=\r\n'
        '21 SUCCEEDED 7 www.example.com:443 PURPOSE=USER\r\n'
        '22 SUCCEEDED 7 www.example.com:80 PURPOSE=USER\r\n'
        '23 SUCCEEDED 9 api.github.com:443 PURPOSE=USER\r\n'
        '24 NEW 0 pending.example:443\r\n'
        '25 CLOSED 9 closed.example:443 REASON=DONE\r\n'
        '.\r\n250 OK\r\n';
    final s = parseStreamStatus(out);
    expect(s, hasLength(5));
    final t = targetsByCircuit(s);
    expect(t['7'], ['www.example.com']);
    expect(t['9'], ['api.github.com']);
    expect(t.containsKey('0'), isFalse);
  });
}

void appListTests() {
  group('desktop entries', () {
    test('field codes are stripped, localised keys ignored', () {
      final e = parseDesktopEntry('[Desktop Entry]\nType=Application\nName=Firefox\nName[de]=Feuerfuchs\nExec=firefox %u --new-window %%x\n[Desktop Action new]\nName=Other\nExec=other')!;
      expect(e.name, 'Firefox');
      expect(e.command, 'firefox --new-window %x');
    });
    test('hidden, terminal, non-application and incomplete entries are skipped', () {
      for (final t in [
        '[Desktop Entry]\nType=Application\nName=A\nExec=a\nNoDisplay=true',
        '[Desktop Entry]\nType=Application\nName=A\nExec=a\nHidden=true',
        '[Desktop Entry]\nType=Application\nName=A\nExec=a\nTerminal=true',
        '[Desktop Entry]\nType=Link\nName=A\nURL=x',
        '[Desktop Entry]\nType=Application\nName=A',
        '[Desktop Entry]\nType=Application\nExec=a',
        '[Desktop Entry]\nType=Application\nName=A\nExec=%U',
        'garbage',
      ]) {
        expect(parseDesktopEntry(t), isNull, reason: t);
      }
    });
    test('mac open command carries the proxy', () {
      final c = macOpenCommand('/Applications/Some App.app');
      expect(c, contains('--env ALL_PROXY=socks5h://127.0.0.1:9050'));
      expect(splitCommand(c).last, '/Applications/Some App.app');
    });
    test('filtering matches all words, prefix hits first', () {
      const apps = [AppEntry('Google Chrome', 'c'), AppEntry('Chromium', 'd'), AppEntry('Firefox', 'f'), AppEntry('Files', 'x')];
      expect(filterApps(apps, 'chro').map((a) => a.name), ['Chromium', 'Google Chrome']);
      expect(filterApps(apps, 'goo chr').map((a) => a.name), ['Google Chrome']);
      expect(filterApps(apps, ''), apps);
      expect(filterApps(apps, 'zzz'), isEmpty);
    });
    test('linux scan reads a temp applications dir', () {
      final d = Directory.systemTemp.createTempSync('apps_');
      addTearDown(() => d.deleteSync(recursive: true));
      Directory('${d.path}/applications').createSync();
      File('${d.path}/applications/a.desktop').writeAsStringSync('[Desktop Entry]\nType=Application\nName=Zed\nExec=zed %F');
      File('${d.path}/applications/b.desktop').writeAsStringSync('[Desktop Entry]\nType=Application\nName=alpha\nExec=alpha');
      final r = scanLinuxApps({'HOME': d.path, 'XDG_DATA_HOME': d.path, 'XDG_DATA_DIRS': '/nonexistent'}, includeSystemDirs: false);
      expect(r.map((a) => a.name), ['alpha', 'Zed']);
      expect(r.last.command, 'zed');
    }, testOn: 'linux');
  });
  group('launcher extras', () {
    test('flatpak run gets the proxy as --env, and is not wrapped in torsocks', () {
      final s = buildLaunch('flatpak run org.mozilla.firefox', profileDir: '/p', hasTorsocks: true);
      expect(s.executable, 'flatpak');
      expect(s.args, ['run', '--env=ALL_PROXY=socks5h://127.0.0.1:9050', '--env=all_proxy=socks5h://127.0.0.1:9050', 'org.mozilla.firefox']);
    });
    test('open / snap are never wrapped in torsocks', () {
      expect(buildLaunch('open -a Foo', profileDir: '/p', hasTorsocks: true).executable, 'open');
      expect(buildLaunch('snap run vlc', profileDir: '/p', hasTorsocks: true).executable, 'snap');
    });
  });
}

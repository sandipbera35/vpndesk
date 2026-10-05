@TestOn('linux')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_desk/session.dart';

import 'support/fake_system.dart';

const script = 'packaging/linux/vpndesk-restore';
const proxy = FakeSystem.proxy;

Future<ProcessResult> run(FakeSystem sys, [List<String> args = const ['--auto']]) =>
    Process.run(script, args, environment: sys.env);

/// A throw-away process that stands in for "the app" or "tor" (pid + real start time).
Future<Process> sleeper([int secs = 60]) => Process.start('sleep', ['$secs']);

String exeOf(Process p) => File('/proc/${p.pid}/exe').resolveSymbolicLinksSync();

Map<String, Object?> deadAppJournal({Map<String, Object?> extra = const {}}) => {
      'version': 1,
      'session': 'abc',
      'app_pid': 999999,
      'app_start': 1,
      'mode': 'default',
      'tor_pid': 0,
      'tor_start': 0,
      'tor_exe': '',
      'proxy_changed': false,
      ...extra,
    };

void main() {
  late FakeSystem sys;
  setUp(() => sys = FakeSystem());
  tearDown(() => sys.dispose());

  group('proxy', () {
    test('restores the previous values recorded in the journal, not a blind none', () async {
      sys.stuckProxy();
      sys.writeJournal(deadAppJournal(extra: {
        'proxy_changed': true,
        'prev_proxy_mode': 'manual',
        'prev_proxy_host': '10.1.2.3',
        'prev_proxy_port': 8080,
      }));
      final r = await run(sys);
      expect(r.exitCode, 10, reason: '${r.stdout}${r.stderr}');
      expect(sys.getGs(proxy, 'mode'), "'manual'");
      expect(sys.getGs('$proxy.socks', 'host'), "'10.1.2.3'");
      expect(sys.getGs('$proxy.socks', 'port'), '8080');
      expect(sys.journal.existsSync(), isFalse);
    });

    test('a previous value that is our own leftover becomes none', () async {
      sys.stuckProxy();
      sys.writeJournal(deadAppJournal(extra: {
        'proxy_changed': true,
        'prev_proxy_mode': 'manual',
        'prev_proxy_host': '127.0.0.1',
        'prev_proxy_port': 9050,
      }));
      expect((await run(sys)).exitCode, 10);
      expect(sys.getGs(proxy, 'mode'), "'none'");
    });

    test('journal says the proxy was never changed: leave the user settings alone', () async {
      sys.setGs(proxy, 'mode', "'manual'");
      sys.setGs('$proxy.socks', 'host', "'10.9.9.9'");
      sys.setGs('$proxy.socks', 'port', '1080');
      sys.writeJournal(deadAppJournal());
      final r = await run(sys);
      expect(r.exitCode, 0);
      expect(sys.getGs(proxy, 'mode'), "'manual'");
      expect(File('${sys.gs.path}/log').existsSync(), isFalse, reason: 'no gsettings set expected');
    });

    test('no journal (older version crashed): a proxy pointing at dead 127.0.0.1:9050 is cleared', () async {
      sys.stuckProxy();
      final r = await run(sys);
      expect(r.exitCode, 10, reason: '${r.stdout}${r.stderr}');
      expect(sys.getGs(proxy, 'mode'), "'none'");
    });

    test('no journal: a different manual proxy is never touched', () async {
      sys.setGs(proxy, 'mode', "'manual'");
      sys.setGs('$proxy.socks', 'host', "'10.9.9.9'");
      sys.setGs('$proxy.socks', 'port', '9050');
      expect((await run(sys)).exitCode, 0);
      expect(sys.getGs(proxy, 'mode'), "'manual'");
    });
  });

  group('app liveness', () {
    test('a running app (pid AND start time match) is left alone', () async {
      final app = await sleeper();
      addTearDown(app.kill);
      sys.stuckProxy();
      sys.writeJournal(deadAppJournal(extra: {
        'app_pid': app.pid,
        'app_start': Session.startTime(app.pid),
        'proxy_changed': true,
        'prev_proxy_mode': 'none',
        'prev_proxy_host': '',
        'prev_proxy_port': 0,
      }));
      final r = await run(sys);
      expect(r.exitCode, 0);
      expect(sys.getGs(proxy, 'mode'), "'manual'");
      expect(sys.journal.existsSync(), isTrue);
    });

    test('pid reuse: same pid but a different start time means the app is dead', () async {
      final impostor = await sleeper();
      addTearDown(impostor.kill);
      sys.stuckProxy();
      sys.writeJournal(deadAppJournal(extra: {
        'app_pid': impostor.pid,
        'app_start': (Session.startTime(impostor.pid) ?? 0) + 12345,
        'proxy_changed': true,
        'prev_proxy_mode': 'none',
        'prev_proxy_host': '',
        'prev_proxy_port': 0,
      }));
      expect((await run(sys)).exitCode, 10);
      expect(sys.getGs(proxy, 'mode'), "'none'");
      expect(Session.startTime(impostor.pid), isNotNull, reason: 'the impostor process must not be killed');
    });
  });

  group('tor', () {
    test('the recorded orphan tor (pid + exe + start time) is stopped', () async {
      final tor = await sleeper();
      addTearDown(tor.kill);
      sys.writeJournal(deadAppJournal(extra: {'tor_pid': tor.pid, 'tor_start': Session.startTime(tor.pid), 'tor_exe': exeOf(tor)}));
      final r = await run(sys);
      expect(r.exitCode, 10, reason: '${r.stdout}${r.stderr}');
      expect(await tor.exitCode.timeout(const Duration(seconds: 8)), isNonZero);
    });

    test('a different process that reused the pid (start time differs) is never touched', () async {
      final other = await sleeper();
      addTearDown(other.kill);
      sys.writeJournal(deadAppJournal(extra: {'tor_pid': other.pid, 'tor_start': (Session.startTime(other.pid) ?? 0) + 99, 'tor_exe': exeOf(other)}));
      await run(sys);
      expect(Session.startTime(other.pid), isNotNull);
    });

    test("the user's own tor (right pid, different executable) is never touched", () async {
      final other = await sleeper();
      addTearDown(other.kill);
      sys.writeJournal(deadAppJournal(extra: {'tor_pid': other.pid, 'tor_start': Session.startTime(other.pid), 'tor_exe': '/opt/vpn_desk/tor/tor'}));
      await run(sys);
      expect(Session.startTime(other.pid), isNotNull);
    });
  });

  group('system-wide firewall', () {
    test('a stale active table is removed through the helper via pkexec', () async {
      sys.setNetState('active');
      sys.writeJournal(deadAppJournal(extra: {'mode': 'system-wide', 'nft_table': 'inet vpndesk'}));
      final r = await run(sys);
      expect(r.exitCode, 10, reason: '${r.stdout}${r.stderr}');
      expect(sys.pkexecCalls, ['${sys.helper.path} stop']);
      expect(sys.netStateNow, 'none');
      expect(sys.journal.existsSync(), isFalse);
    });

    test('nothing installed: no admin prompt', () async {
      sys.writeJournal(deadAppJournal(extra: {'mode': 'system-wide'}));
      expect((await run(sys)).exitCode, 0);
      expect(sys.pkexecCalls, isEmpty);
    });

    test('permission denied: exit 1, journal kept so it can be retried', () async {
      sys.setNetState('blocked');
      sys.failPkexec(true);
      sys.writeJournal(deadAppJournal(extra: {'mode': 'system-wide'}));
      final r = await run(sys);
      expect(r.exitCode, 1);
      expect(sys.journal.existsSync(), isTrue);
      expect(r.stderr, contains('nft delete table'));
    });

    test('--net forces the removal even when the state file says none', () async {
      final r = await run(sys, ['--net']);
      expect(r.exitCode, 10, reason: '${r.stdout}${r.stderr}');
      expect(sys.pkexecCalls, hasLength(1));
    });
  });

  test('idempotent: a second run after recovery does nothing', () async {
    sys.stuckProxy();
    sys.writeJournal(deadAppJournal(extra: {'proxy_changed': true, 'prev_proxy_mode': 'none', 'prev_proxy_host': '', 'prev_proxy_port': 0}));
    expect((await run(sys)).exitCode, 10);
    expect((await run(sys)).exitCode, 0);
  });

  group('watchdog', () {
    test('recovers by itself when the app is killed', () async {
      final app = await sleeper();
      addTearDown(app.kill);
      sys.stuckProxy();
      sys.writeJournal(deadAppJournal(extra: {
        'app_pid': app.pid,
        'app_start': Session.startTime(app.pid),
        'proxy_changed': true,
        'prev_proxy_mode': 'none',
        'prev_proxy_host': '',
        'prev_proxy_port': 0,
      }));
      final guard = await Process.start(script, ['--watch'], environment: sys.env);
      await Future.delayed(const Duration(milliseconds: 1500));
      expect(sys.getGs(proxy, 'mode'), "'manual'", reason: 'app is still alive');
      app.kill(ProcessSignal.sigkill);
      expect(await guard.exitCode.timeout(const Duration(seconds: 15)), 0);
      expect(sys.getGs(proxy, 'mode'), "'none'");
      expect(sys.journal.existsSync(), isFalse);
    });

    test('exits quietly without touching anything after a clean disconnect (journal deleted)', () async {
      final app = await sleeper();
      addTearDown(app.kill);
      sys.stuckProxy();
      sys.writeJournal(deadAppJournal(extra: {'app_pid': app.pid, 'app_start': Session.startTime(app.pid), 'proxy_changed': true}));
      final guard = await Process.start(script, ['--watch'], environment: sys.env);
      await Future.delayed(const Duration(milliseconds: 500));
      sys.journal.deleteSync();
      expect(await guard.exitCode.timeout(const Duration(seconds: 5)), 0);
      expect(sys.getGs(proxy, 'mode'), "'manual'", reason: 'a clean disconnect already restored things itself');
    });

    test('a newer session replaces the journal: the old guard stands down', () async {
      final app = await sleeper();
      addTearDown(app.kill);
      final j = {'app_pid': app.pid, 'app_start': Session.startTime(app.pid)};
      sys.writeJournal(deadAppJournal(extra: {...j, 'session': 'one'}));
      final guard = await Process.start(script, ['--watch'], environment: sys.env);
      await Future.delayed(const Duration(milliseconds: 500));
      sys.writeJournal(deadAppJournal(extra: {...j, 'session': 'two'}));
      expect(await guard.exitCode.timeout(const Duration(seconds: 5)), 0);
    });
  });
}

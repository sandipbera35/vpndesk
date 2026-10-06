@TestOn('linux')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oniondesk/platform.dart';
import 'package:oniondesk/session.dart';

import 'support/fake_system.dart';

void main() {
  late FakeSystem sys;
  setUp(() {
    sys = FakeSystem();
    Session.dirOverride = sys.state;
    Session.end();
    Plat.gsettingsCmd = '${sys.bin.path}/gsettings';
  });
  tearDown(() {
    Session.end();
    Session.dirOverride = null;
    Plat.gsettingsCmd = 'gsettings';
    sys.dispose();
  });

  Future<void> withFakeGsettings(Future<void> Function() body) async {
    // Plat shells out to the fake with the sandbox env via a wrapper that exports it.
    final wrapper = File('${sys.bin.path}/gsettings-wrapped')
      ..writeAsStringSync('#!/bin/bash\n${sys.env.entries.map((e) => 'export ${e.key}="${e.value}"').join('\n')}\nexec ${sys.bin.path}/gsettings "\$@"\n');
    Process.runSync('chmod', ['+x', wrapper.path]);
    Plat.gsettingsCmd = wrapper.path;
    await body();
  }

  test('start time of this very process is readable and stable', () {
    final a = Session.startTime(pid);
    expect(a, isNotNull);
    expect(Session.startTime(pid), a);
    expect(Session.startTime(999999999), isNull);
  });

  test('journal is flat JSON, one key per line, and written atomically', () {
    Session.begin('default');
    expect(Session.file.existsSync(), isTrue);
    expect(File('${Session.file.path}.tmp').existsSync(), isFalse);
    final text = Session.file.readAsStringSync();
    final j = jsonDecode(text) as Map<String, dynamic>;
    expect(j['app_pid'], pid);
    expect(j['app_start'], Session.startTime(pid));
    expect(j['proxy_changed'], false);
    expect(text.split('\n').where((l) => l.startsWith('  "')).length, j.length);
  });

  test('recordTor stores pid, start time and the resolved executable', () async {
    final p = await Process.start('sleep', ['30']);
    addTearDown(p.kill);
    Session.begin('default');
    Session.recordTor(p.pid, '/bin/sleep');
    final j = jsonDecode(Session.file.readAsStringSync()) as Map<String, dynamic>;
    expect(j['tor_pid'], p.pid);
    expect(j['tor_start'], Session.startTime(p.pid));
    expect(j['tor_exe'], File('/proc/${p.pid}/exe').resolveSymbolicLinksSync());
  });

  test('recordTor resolves a bare executable name through PATH', () async {
    final p = await Process.start('sleep', ['30']);
    addTearDown(p.kill);
    Session.begin('default');
    Session.recordTor(p.pid, 'sleep');
    final j = jsonDecode(Session.file.readAsStringSync()) as Map<String, dynamic>;
    expect(j['tor_exe'], File('/proc/${p.pid}/exe').resolveSymbolicLinksSync());
  });

  test('end() deletes the journal', () {
    Session.begin('default');
    Session.end();
    expect(Session.file.existsSync(), isFalse);
    expect(Session.active, isFalse);
  });

  test("proxy: the user's previous settings are journaled first and restored exactly", () => withFakeGsettings(() async {
        sys.setGs(FakeSystem.proxy, 'mode', "'manual'");
        sys.setGs('${FakeSystem.proxy}.socks', 'host', "'10.1.2.3'");
        sys.setGs('${FakeSystem.proxy}.socks', 'port', '8080');
        Session.begin('default');
        await Plat.setSystemProxy(true);
        expect(sys.getGs(FakeSystem.proxy, 'mode'), "'manual'");
        expect(sys.getGs('${FakeSystem.proxy}.socks', 'host'), "'127.0.0.1'");
        final j = jsonDecode(Session.file.readAsStringSync()) as Map<String, dynamic>;
        expect([j['proxy_changed'], j['prev_proxy_mode'], j['prev_proxy_host'], j['prev_proxy_port']], [true, 'manual', '10.1.2.3', 8080]);

        await Plat.setSystemProxy(false);
        expect(sys.getGs(FakeSystem.proxy, 'mode'), "'manual'");
        expect(sys.getGs('${FakeSystem.proxy}.socks', 'host'), "'10.1.2.3'");
        expect(sys.getGs('${FakeSystem.proxy}.socks', 'port'), '8080');
      }));

  test('proxy: previously none goes back to none; a second off is a no-op', () => withFakeGsettings(() async {
        sys.setGs(FakeSystem.proxy, 'mode', "'none'");
        sys.setGs('${FakeSystem.proxy}.socks', 'host', "''");
        sys.setGs('${FakeSystem.proxy}.socks', 'port', '0');
        Session.begin('default');
        await Plat.setSystemProxy(true);
        await Plat.setSystemProxy(false);
        expect(sys.getGs(FakeSystem.proxy, 'mode'), "'none'");
        final before = File('${sys.gs.path}/log').readAsLinesSync().length;
        await Plat.setSystemProxy(false);
        expect(File('${sys.gs.path}/log').readAsLinesSync().length, before, reason: 'idempotent');
      }));

  test('proxy: disconnect without ever connecting does not clobber the user proxy', () => withFakeGsettings(() async {
        sys.setGs(FakeSystem.proxy, 'mode', "'manual'");
        Session.begin('default');
        await Plat.setSystemProxy(false);
        expect(sys.getGs(FakeSystem.proxy, 'mode'), "'manual'");
      }));

  test('proxy: turning it on twice keeps the ORIGINAL previous values', () => withFakeGsettings(() async {
        sys.setGs(FakeSystem.proxy, 'mode', "'none'");
        sys.setGs('${FakeSystem.proxy}.socks', 'host', "''");
        sys.setGs('${FakeSystem.proxy}.socks', 'port', '0');
        Session.begin('default');
        await Plat.setSystemProxy(true);
        await Plat.setSystemProxy(true);
        await Plat.setSystemProxy(false);
        expect(sys.getGs(FakeSystem.proxy, 'mode'), "'none'");
      }));
}

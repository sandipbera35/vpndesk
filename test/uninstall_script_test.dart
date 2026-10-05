@TestOn('linux')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Runs a copy of packaging/linux/vpndesk-uninstall whose hard-coded system paths are rewritten into a temp tree,
/// with fake id/rpm/dpkg/userdel/nft/... on PATH. The real system is never touched.
class Sandbox {
  final Directory root = Directory.systemTemp.createTempSync('vpndesk_uninst_');
  late final Directory bin = Directory('${root.path}/fakebin')..createSync();
  late final File log = File('${root.path}/calls.log');
  late final File script;

  Sandbox({String installed = 'rpm', bool packageManagerFails = false, bool userExists = true}) {
    var s = File('packaging/linux/vpndesk-uninstall').readAsStringSync();
    s = s.replaceAll('/opt/vpn_desk', '${root.path}/opt/vpn_desk').replaceAll('/var/lib/vpn_desk', '${root.path}/var/lib/vpn_desk').replaceAll('/run/vpn_desk', '${root.path}/run/vpn_desk').replaceAll('/usr/', '${root.path}/usr/');
    script = File('${root.path}/uninstall.sh')..writeAsStringSync(s);
    fake('id', userExists ? r'if [ "$1" = -u ] && [ $# = 1 ]; then echo 0; exit 0; fi; exit 0' : r'if [ "$1" = -u ] && [ $# = 1 ]; then echo 0; exit 0; fi; exit 1');
    fake('pkill', r'echo "pkill $*" >> "$LOG"');
    fake('nft', r'echo "nft $*" >> "$LOG"');
    fake('userdel', r'echo "userdel $*" >> "$LOG"');
    fake('groupdel', r'echo "groupdel $*" >> "$LOG"');
    fake('getent', r'exit 1');
    fake('update-desktop-database', 'exit 0');
    fake('gtk-update-icon-cache', 'exit 0');
    final fail = packageManagerFails ? r'echo "database is locked" >&2; exit 1' : r'echo "$0 $*" >> "$LOG"; exit 0';
    fake('dpkg', installed == 'dpkg' ? (r'if [ "$1" = -s ]; then exit 0; fi; ' + fail) : 'exit 1');
    fake('rpm', installed == 'rpm' ? (r'if [ "$1" = -q ]; then exit 0; fi; ' + fail) : 'exit 1');
    touch('opt/vpn_desk/vpn_desk');
    touch('opt/vpn_desk/vpndesk-uninstall');
    touch('var/lib/vpn_desk/data/state');
    touch('run/vpn_desk/state');
    touch('usr/bin/vpndesk-restore');
    touch('usr/share/applications/io.vpndesk.VPNDesk.desktop');
    touch('usr/share/polkit-1/actions/io.vpndesk.net.policy');
    touch('usr/share/icons/hicolor/512x512/apps/vpn_desk.png');
    touch('usr/bin/unrelated-tool');
    touch('opt/other_app/keep');
    touch('var/lib/other/keep');
  }

  void fake(String name, String body) {
    final f = File('${bin.path}/$name')..writeAsStringSync('#!/bin/bash\n$body\n');
    Process.runSync('chmod', ['+x', f.path]);
  }

  void touch(String rel) => File('${root.path}/$rel').createSync(recursive: true);
  bool has(String rel) => File('${root.path}/$rel').existsSync() || Directory('${root.path}/$rel').existsSync();

  Future<ProcessResult> run() => Process.run('/bin/bash', [script.path], environment: {'PATH': '${bin.path}:${Platform.environment['PATH']}', 'LOG': log.path});
  String get calls => log.existsSync() ? log.readAsStringSync() : '';
  void dispose() => root.deleteSync(recursive: true);
}

void main() {
  test('rpm install: package removed through rpm, system data and user removed, step lines emitted', () async {
    final sb = Sandbox();
    addTearDown(sb.dispose);
    final r = await sb.run();
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    expect((r.stdout as String).trim().split('\n'), ['STEP:firewall:Removing firewall rules', 'STEP:package:Removing application files', 'STEP:system:Removing system helper and data', 'DONE']);
    expect(sb.calls, contains('rpm -e vpn-desk'));
    expect(sb.calls, contains('nft delete table inet vpndesk'));
    expect(sb.calls, contains('pkill -u vpndesk -x tor'));
    expect(sb.calls, contains('userdel vpndesk'));
    expect(sb.has('var/lib/vpn_desk'), isFalse);
    expect(sb.has('run/vpn_desk'), isFalse);
    expect(sb.has('usr/bin/unrelated-tool'), isTrue);
    expect(sb.has('opt/other_app/keep'), isTrue);
    expect(sb.has('var/lib/other/keep'), isTrue);
  });

  test('deb install uses dpkg --purge', () async {
    final sb = Sandbox(installed: 'dpkg');
    addTearDown(sb.dispose);
    final r = await sb.run();
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    expect(sb.calls, contains('--purge vpn-desk'));
    expect(sb.calls, isNot(contains('rpm -e')));
  });

  test('package manager failure: ERROR line, exit 1, and the system step never runs', () async {
    final sb = Sandbox(packageManagerFails: true);
    addTearDown(sb.dispose);
    final r = await sb.run();
    expect(r.exitCode, 1);
    expect(r.stdout, contains('ERROR:rpm could not remove vpn-desk: database is locked'));
    expect(r.stdout, isNot(contains('DONE')));
    expect(r.stdout, isNot(contains('STEP:system')));
    expect(sb.has('var/lib/vpn_desk'), isTrue, reason: 'nothing past the failed step is touched');
    expect(sb.calls, isNot(contains('userdel')));
  });

  test('no package manager knows it: only the exact known files are removed', () async {
    final sb = Sandbox(installed: 'none');
    addTearDown(sb.dispose);
    final r = await sb.run();
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    for (final gone in ['opt/vpn_desk', 'usr/bin/vpndesk-restore', 'usr/share/applications/io.vpndesk.VPNDesk.desktop', 'usr/share/polkit-1/actions/io.vpndesk.net.policy', 'usr/share/icons/hicolor/512x512/apps/vpn_desk.png']) {
      expect(sb.has(gone), isFalse, reason: gone);
    }
    expect(sb.has('usr/bin/unrelated-tool'), isTrue);
    expect(sb.has('opt/other_app/keep'), isTrue);
  });

  test('no vpndesk user (system-wide mode never used): no userdel', () async {
    final sb = Sandbox(userExists: false);
    addTearDown(sb.dispose);
    final r = await sb.run();
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    expect(sb.calls, isNot(contains('userdel')));
  });

  test('refuses to run as non-root', () async {
    final sb = Sandbox();
    addTearDown(sb.dispose);
    sb.fake('id', r'echo 1000');
    final r = await sb.run();
    expect(r.exitCode, 1);
    expect(r.stdout, contains('ERROR:'));
    expect(sb.has('opt/vpn_desk'), isTrue);
  });
}

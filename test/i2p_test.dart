import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:oniondesk/i2p.dart';

void main() {
  test('conf: loopback only, our ports, transit off unless sharing, no I2PControl', () {
    final c = buildI2pConf(share: false);
    expect(c, contains('notransit = true'));
    expect(c, contains('port = 4444'));
    expect(c, contains('port = 4447'));
    expect(c, contains('port = 7070'));
    expect(c, isNot(contains('7650')));
    expect(c, contains('bandwidth = 4096'));
    expect(c, contains('[addressbook]'));
    expect(c, contains('subscriptions = http://notbob.i2p/hosts.txt'));
    expect(c, contains('[i2pcontrol]\nenabled = false'));
    expect(RegExp(r'address = (\S+)').allMatches(c).every((m) => m.group(1) == '127.0.0.1'), isTrue);
    expect(buildI2pConf(share: true), contains('notransit = false'));
  });

  test('finder: the copy shipped with the app beats an installed one, the user\'s own choice beats both', () {
    final have = <String>{'/opt/oniondesk/i2pd/i2pd', '/usr/bin/i2pd', '/opt/mine/i2pd'};
    bool ex(String p) => have.contains(p);
    expect(findI2pd(bundled: '/opt/oniondesk/i2pd/i2pd', exists: ex, env: {'PATH': '/usr/bin'}, win: false, mac: false), '/opt/oniondesk/i2pd/i2pd');
    expect(findI2pd(custom: '/opt/mine/i2pd', bundled: '/opt/oniondesk/i2pd/i2pd', exists: ex, env: {'PATH': '/usr/bin'}, win: false, mac: false), '/opt/mine/i2pd');
    expect(findI2pd(bundled: '/missing/i2pd', exists: ex, env: {'PATH': '/usr/bin'}, win: false, mac: false), '/usr/bin/i2pd');
  });

  test('conf logs to a file where there is no console (Windows)', () {
    expect(buildI2pConf(share: false), contains('log = stdout'));
    final c = buildI2pConf(share: false, logFile: r'C:\x\i2pd.log');
    expect(c, contains('log = file'));
    expect(c, contains(r'logfile = C:\x\i2pd.log'));
  });

  test('finder: custom path wins, then PATH, then known folders', () {
    final have = <String>{'/opt/mine/i2pd', '/usr/bin/i2pd'};
    bool ex(String p) => have.contains(p);
    expect(findI2pd(custom: '/opt/mine/i2pd', exists: ex, env: {'PATH': '/usr/bin'}, win: false, mac: false), '/opt/mine/i2pd');
    expect(findI2pd(custom: '/gone/i2pd', exists: ex, env: {'PATH': '/usr/bin'}, win: false, mac: false), '/usr/bin/i2pd');
    expect(findI2pd(exists: (_) => false, env: {'PATH': '/usr/bin'}, win: false, mac: false), isNull);
    expect(findI2pd(exists: (p) => p == r'C:\Program Files\i2pd\i2pd.exe', env: {'ProgramFiles': r'C:\Program Files'}, win: true, mac: false), r'C:\Program Files\i2pd\i2pd.exe');
    expect(findI2pd(exists: (p) => p == '/opt/homebrew/bin/i2pd', env: {'PATH': ''}, win: false, mac: true), '/opt/homebrew/bin/i2pd');
  });

  // Text of the real i2pd 2.61.0 console main page (captured 2026-10-07), tags and CSS left in.
  const consoleHtml = '<html><head><style>.a { color: red; }</style></head><body><div class="content">'
      '<b>Uptime:</b> 22 seconds<br>\n<b>Network status:</b> Firewalled - Symmetric NAT<br>\n<b>Tunnel creation success rate:</b> 100%<br>\n'
      '<b>Received:</b> 27.90 KiB (1.14 KiB/s)<br>\n<b>Sent:</b> 28.62 KiB (1.33 KiB/s)<br>\n<b>Transit:</b> 0.00 KiB (0.00 KiB/s)<br>\n'
      '<b>Version:</b> 2.61.0<br>\n<b>Routers:</b> 170&nbsp;&nbsp;&nbsp; <b>Floodfills:</b> 108&nbsp;&nbsp;&nbsp; <b>LeaseSets:</b> 0<br>\n'
      '<b>Client Tunnels:</b> 5&nbsp;&nbsp;&nbsp; <b>Transit Tunnels:</b> 0<br></div></body></html>';

  test('console parsing reads the real i2pd page', () {
    final s = parseConsole(consoleHtml);
    expect(s.version, '2.61.0');
    expect(s.netText, 'Firewalled - Symmetric NAT');
    expect(s.routers, 170);
    expect(s.floodfills, 108);
    expect(s.clientTunnels, 5);
    expect(s.successRate, 100);
    expect(s.bwIn, closeTo(1.14 * 1024, 0.01));
    expect(s.bwOut, closeTo(1.33 * 1024, 0.01));
    expect(s.integrated, isTrue);
  });

  test('console parsing tolerates junk and a router that has not integrated yet', () {
    final empty = parseConsole('<html>nothing here</html>');
    expect(empty.routers, isNull);
    expect(empty.integrated, isFalse);
    expect(parseConsole('<b>Routers:</b> 3<br><b>Client Tunnels:</b> 0<br><b>Tunnel creation success rate:</b> 0%').integrated, isFalse);
    expect(parseConsole('<b>Routers:</b> 84<br><b>Client Tunnels:</b> 4<br><b>Tunnel creation success rate:</b> 10%').integrated, isFalse, reason: 'early, mostly failing tunnels');
    expect(parseConsole('<b>Received:</b> 5 MiB (2.00 MiB/s)').bwIn, 2.0 * 1048576);
  });

  test('install hints per OS', () {
    expect(i2pInstallHint(win: true, mac: false), isNull);
    expect(i2pInstallHint(win: false, mac: true)!.command, 'brew install i2pd');
    expect(i2pInstallHint(win: false, mac: false, osRelease: 'ID=fedora')!.command, 'sudo dnf install i2pd');
    expect(i2pInstallHint(win: false, mac: false, osRelease: 'ID=ubuntu')!.command, 'sudo apt install i2pd');
  });

  test('a pid is only ours when its executable is the recorded one', () async {
    if (!Platform.isLinux) return;
    final p = await Process.start('sleep', ['30']);
    try {
      final real = File('/proc/${p.pid}/exe').resolveSymbolicLinksSync();
      expect(I2pRouter.isOurI2pd(p.pid, real), isTrue);
      expect(I2pRouter.isOurI2pd(p.pid, '/usr/bin/true'), isFalse);
      expect(I2pRouter.isOurI2pd(p.pid, ''), isFalse);
    } finally {
      p.kill();
    }
  });

  test('stale pid file: an orphan that is really ours is stopped, someone else\'s process is left alone', () async {
    if (!Platform.isLinux) return;
    final dir = Directory.systemTemp.createTempSync('i2ptest');
    addTearDown(() => dir.deleteSync(recursive: true));
    final r = I2pRouter(dirOverride: dir);
    final mine = await Process.start('sleep', ['60']);
    final other = await Process.start('sleep', ['60']);
    addTearDown(() { mine.kill(); other.kill(); });
    final sleepExe = File('/proc/${mine.pid}/exe').resolveSymbolicLinksSync();
    // Record `mine` with the right exe: killed.
    File('${dir.path}/i2pd.pid').writeAsStringSync('${mine.pid}\n$sleepExe');
    await r.killStale();
    expect(await mine.exitCode.timeout(const Duration(seconds: 3), onTimeout: () => -99), isNot(-99));
    expect(File('${dir.path}/i2pd.pid').existsSync(), isFalse);
    // Record `other` with a different exe: untouched.
    File('${dir.path}/i2pd.pid').writeAsStringSync('${other.pid}\n/usr/bin/true');
    await r.killStale();
    expect(await other.exitCode.timeout(const Duration(milliseconds: 600), onTimeout: () => -99), -99);
  });

  test('lifecycle with a fake i2pd: starts, reports starting, stop kills it and removes the pid file', () async {
    if (!Platform.isLinux) return;
    if ((await busyI2pPorts()).isNotEmpty) return; // a real router is using the ports
    final dir = Directory.systemTemp.createTempSync('i2ptest');
    addTearDown(() => dir.deleteSync(recursive: true));
    final fake = File('${dir.path}/fake-i2pd')..writeAsStringSync('#!/bin/bash\necho "fake i2pd started"\nexec sleep 300\n');
    await Process.run('chmod', ['+x', fake.path]);
    final r = I2pRouter(dirOverride: Directory('${dir.path}/data'))..customPath = fake.path;
    r.detect();
    expect(r.state, I2pState.stopped);
    await r.start();
    expect(r.state, I2pState.starting);
    final pidFile = File('${dir.path}/data/i2pd.pid');
    expect(pidFile.existsSync(), isTrue);
    final pid = int.parse(pidFile.readAsLinesSync().first);
    expect(Directory('/proc/$pid').existsSync(), isTrue);
    expect(File('${dir.path}/data/i2pd.conf').readAsStringSync(), contains('notransit = true'));
    await Future.delayed(const Duration(milliseconds: 300));
    expect(r.log, contains('fake i2pd started'));
    await r.stop();
    expect(r.state, I2pState.stopped);
    expect(pidFile.existsSync(), isFalse);
    await Future.delayed(const Duration(milliseconds: 300));
    expect(Directory('/proc/$pid').existsSync(), isFalse);
  });

  test('a port already in use means we do not start (another router is running)', () async {
    if (!Platform.isLinux) return;
    final srv = await ServerSocket.bind(InternetAddress.loopbackIPv4, 7070).catchError((_) => ServerSocket.bind(InternetAddress.loopbackIPv4, 0));
    addTearDown(srv.close);
    if (srv.port != 7070) return; // could not take the port in this environment
    final dir = Directory.systemTemp.createTempSync('i2ptest');
    addTearDown(() => dir.deleteSync(recursive: true));
    final fake = File('${dir.path}/fake-i2pd')..writeAsStringSync('#!/bin/bash\nexec sleep 300\n');
    await Process.run('chmod', ['+x', fake.path]);
    final r = I2pRouter(dirOverride: dir)..customPath = fake.path;
    await r.start();
    expect(r.state, I2pState.external);
    expect(r.busyPorts, contains(7070));
  });

  test('seed address book: copied once into the data folder, never over an existing file, nothing if no seed', () {
    final root = Directory.systemTemp.createTempSync('i2pseed');
    addTearDown(() => root.deleteSync(recursive: true));
    final bundle = Directory('${root.path}/bundle')..createSync();
    final data = Directory('${root.path}/data');
    expect(seedAddressBook(bundle, data), isFalse, reason: 'no seed shipped');
    File('${bundle.path}/hosts.txt').writeAsStringSync('stats.i2p=AAAA\n');
    expect(seedAddressBook(bundle, data), isTrue);
    expect(File('${data.path}/hosts.txt').readAsStringSync(), 'stats.i2p=AAAA\n');
    File('${data.path}/hosts.txt').writeAsStringSync('mine.i2p=BBBB\n');
    expect(seedAddressBook(bundle, data), isFalse);
    expect(File('${data.path}/hosts.txt').readAsStringSync(), 'mine.i2p=BBBB\n', reason: 'an existing file is kept');
  });

  test('the shipped seed lists the usual sites and has only name=destination lines', () {
    final lines = File('packaging/i2p/hosts.txt').readAsLinesSync().where((l) => l.isNotEmpty && !l.startsWith('#')).toList();
    expect(lines.length, greaterThan(20));
    for (final h in ['stats.i2p', 'i2pforum.i2p', 'i2p-projekt.i2p']) {
      expect(lines.any((l) => l.startsWith('$h=')), isTrue, reason: h);
    }
    expect(lines.every((l) => RegExp(r'^[a-z0-9.-]+\.i2p=[A-Za-z0-9~-]+(=*)(#.*)?$').hasMatch(l)), isTrue);
  });
}

@TestOn('linux')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_desk/platform.dart';
import 'package:vpn_desk/session.dart';

void main() {
  test("killStaleTor never kills a process that is not our tor (recycled pid / user's own process)", () async {
    final cfg = Directory.systemTemp.createTempSync('vpndesk_cfg_');
    Plat.configDirOverride = cfg;
    final other = await Process.start('sleep', ['60']);
    addTearDown(() {
      other.kill();
      Plat.configDirOverride = null;
      cfg.deleteSync(recursive: true);
    });
    File('${cfg.path}/tor.pid').writeAsStringSync('${other.pid}');
    await Plat.killStaleTor();
    expect(Session.startTime(other.pid), isNotNull, reason: 'an unrelated process must survive');
    expect(File('${cfg.path}/tor.pid').existsSync(), isFalse, reason: 'stale pid file is cleaned up');
  });
}

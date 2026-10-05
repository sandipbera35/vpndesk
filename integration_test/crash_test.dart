// Drives the real app to "connected", then ends it the way $VPNDESK_CRASH_MODE (file /tmp/vpndesk_crash_mode) says:
// kill (SIGKILL) | term | hup | dot (the red window dot) | disconnect (the Disconnect button). Run by tool/crash_check.sh,
// which verifies from the outside that proxy/tor/journal are put back (watchdog + restore script).
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vpn_desk/main.dart';

bool has(String s) => find.textContaining(s).evaluate().isNotEmpty;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('connect then SIGKILL', (t) async {
    t.view.physicalSize = const Size(1280, 860);
    t.view.devicePixelRatio = 1.0;
    await t.pumpWidget(const VpnDeskApp());
    await t.pump(const Duration(seconds: 3));
    await t.tap(find.text('Connect'));
    for (var i = 0; i < 240 && !(has('Protected') && !has('Not protected')); i++) {
      await t.pump(const Duration(milliseconds: 500));
    }
    expect(has('Protected') && !has('Not protected'), true, reason: 'connected');
    debugPrint('CRASH_CONNECTED app_pid=$pid');
    for (var i = 0; i < 16; i++) {
      await t.pump(const Duration(milliseconds: 500));
    }
    final mode = File('/tmp/vpndesk_crash_mode').existsSync() ? File('/tmp/vpndesk_crash_mode').readAsStringSync().trim() : 'kill';
    if (mode == 'disconnect') {
      await t.tap(find.text('Disconnect'));
      for (var i = 0; i < 60 && !has('Not protected'); i++) {
        await t.pump(const Duration(milliseconds: 500));
      }
      debugPrint('CRASH_DISCONNECTED');
      await Future.delayed(const Duration(seconds: 2));
      Process.killPid(pid, ProcessSignal.sigkill); // after a clean disconnect there must be nothing left to recover
    } else if (mode == 'dot') {
      final dots = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_WinDot');
      await t.tap(dots.first);
      await t.pump(const Duration(seconds: 1));
    } else {
      Process.killPid(pid, mode == 'term' ? ProcessSignal.sigterm : mode == 'hup' ? ProcessSignal.sighup : ProcessSignal.sigkill);
    }
    await Future.delayed(const Duration(seconds: 30));
  }, timeout: const Timeout(Duration(minutes: 6)));
}

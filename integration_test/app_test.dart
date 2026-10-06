import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oniondesk/main.dart';

Future<bool> waitFor(WidgetTester t, bool Function() ok, {int secs = 90}) async {
  for (var i = 0; i < secs * 2; i++) {
    await t.pump(const Duration(milliseconds: 500));
    if (ok()) return true;
  }
  return false;
}

bool has(String s) => find.textContaining(s).evaluate().isNotEmpty;
int rssMb() => ProcessInfo.currentRss ~/ (1024 * 1024);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('connect, switch, disconnect x2 with memory sampling', (t) async {
    t.view.physicalSize = const Size(1280, 860);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(const OnionDeskApp());
    await t.pump(const Duration(seconds: 3));
    expect(has('Not protected'), true, reason: 'initial state');
    debugPrint('T initial rss=${rssMb()}MB');

    // Window dots animate under the mouse pointer
    final dots = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_WinDot');
    expect(dots, findsNWidgets(3));
    debugPrint('T dots found');
    final g = await t.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    for (var i = 0; i < 3; i++) {
      await g.moveTo(t.getCenter(dots.at(i)));
      await t.pump(const Duration(milliseconds: 250));
      final sc = t.widget<AnimatedScale>(find.descendant(of: dots.at(i), matching: find.byType(AnimatedScale)));
      expect(sc.scale, greaterThan(1.2), reason: 'dot $i grows on hover');
    }
    await g.moveTo(const Offset(600, 400));
    await t.pump(const Duration(milliseconds: 250));
    expect(t.widget<AnimatedScale>(find.descendant(of: dots.first, matching: find.byType(AnimatedScale))).scale, 1.0);
    debugPrint('T dots ok');
    // About page opens and closes
    await t.tap(find.text('About'));
    await t.pump(const Duration(seconds: 3));
    debugPrint('T about open: ${find.byType(Scaffold).evaluate().length} scaffolds');
    t.state<NavigatorState>(find.byType(Navigator).first).pop();
    await t.pump(const Duration(seconds: 2));
    expect(has('Not protected'), true);
    debugPrint('T about ok');
    // Auto toggle on/off
    await t.tap(find.text('Auto'));
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.text('Auto'));
    await t.pump(const Duration(seconds: 1));
    debugPrint('T auto ok');
    // System-wide pill dialog, then cancel
    await t.tap(find.textContaining('System-wide'));
    await t.pump(const Duration(seconds: 2));
    debugPrint('T system-wide dialog or info shown: ${has('Route the whole computer') || has('unavailable')}');
    if (find.text('Cancel').evaluate().isNotEmpty) {
      await t.tap(find.text('Cancel'));
    } else if (find.text('OK').evaluate().isNotEmpty) {
      await t.tap(find.text('OK'));
    }
    await t.pump(const Duration(seconds: 1));

    for (var round = 1; round <= 2; round++) {
      await t.tap(find.text('Connect'));
      await t.pump();
      expect(has('Connecting'), true, reason: 'connecting state');
      expect(await waitFor(t, () => has('Protected') && !has('Not protected')), true, reason: 'connected r$round');
      debugPrint('T r$round connected rss=${rssMb()}MB');

      // Exit IP card fills in
      expect(await waitFor(t, () => RegExp(r'\d+\.\d+\.\d+\.\d+').hasMatch(
          (find.byType(Text).evaluate().map((e) => (e.widget as Text).data ?? '').join(' | ')))), true, reason: 'ip shown');
      await t.pump(const Duration(seconds: 8));

      // Switch live to another location from the sidebar
      final tile = find.text(round == 1 ? 'Germany' : 'Netherlands');
      if (tile.evaluate().isEmpty) {
        // the sidebar is a lazy list: drag it until the tile is built (best effort)
        try {
          await t.dragUntilVisible(tile, find.byType(ListView).first, const Offset(0, -150), maxIteration: 60);
        } catch (e) {
          debugPrint('T r$round sidebar tile not reachable by dragging: $e');
        }
      }
      expect(tile, findsWidgets, reason: 'sidebar tile');
      await t.tap(tile.first);
      expect(await waitFor(t, () => has('Exit in ${round == 1 ? 'Germany' : 'Netherlands'}'), secs: 10), true, reason: 'switch label');
      await t.pump(const Duration(seconds: 25));
      final ips = find.byType(Text).evaluate().map((e) => (e.widget as Text).data ?? '').where((x) => RegExp(r'\d+\.\d+\.\d+\.\d+').hasMatch(x)).toList();
      debugPrint('T r$round switched ips=$ips rss=${rssMb()}MB');

      await t.tap(find.text('Disconnect'));
      expect(await waitFor(t, () => has('Not protected'), secs: 30), true, reason: 'disconnected r$round');
      await t.pump(const Duration(seconds: 3));
      debugPrint('T r$round disconnected rss=${rssMb()}MB');
    }
    final left = Process.runSync('pgrep', ['-x', 'tor']);
    debugPrint('T leftover tor after test: ${left.stdout}'.trim());
  }, timeout: const Timeout(Duration(minutes: 8)));
}

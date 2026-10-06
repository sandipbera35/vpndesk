@TestOn('linux')
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oniondesk/uninstall.dart';
import 'package:oniondesk/uninstall_page.dart';

UninstallPlan pkgPlan({bool data = true}) =>
    UninstallPlan.detect(exe: '/opt/oniondesk/oniondesk', env: {'HOME': '/home/u'}, deleteData: data, exists: (_) => true);

Future<void> loadFonts() async {
  for (final f in [('Roboto', '/opt/flutter/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf'), ('Roboto', '/opt/flutter/bin/cache/artifacts/material_fonts/Roboto-Bold.ttf'), ('MaterialIcons', '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')]) {
    if (!File(f.$2).existsSync()) continue;
    final bytes = File(f.$2).readAsBytesSync();
    await (FontLoader(f.$1)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
}

Widget app(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF0B1220), textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Roboto')),
      home: child,
    );

void main() {
  late StreamController<UninstallEvent> ctl;
  int starts = 0, exits = 0, backs = 0;

  setUp(() {
    ctl = StreamController<UninstallEvent>();
    starts = exits = backs = 0;
  });
  tearDown(() {
    ctl.close(); // not awaited: close() only completes once something listens
  });

  Widget page({bool dry = false}) => app(UninstallPage(
        plan: pkgPlan(),
        start: () {
          starts++;
          if (starts > 1) ctl = StreamController<UninstallEvent>(); // like Uninstaller.run(): a fresh stream per start
          return ctl.stream;
        },
        onBack: () => backs++,
        onExit: () => exits++,
        dryRun: dry,
        closeAfter: const Duration(seconds: 2),
      ));

  Future<void> settle(WidgetTester t, [int ms = 1500]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('walks through the steps and ends on the uninstalled screen, then asks the app to exit', (t) async {
    t.view.physicalSize = const Size(1080, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(page());
    await settle(t);
    expect(find.text('Uninstalling OnionDesk'), findsOneWidget);
    for (final s in pkgPlan().steps) {
      expect(find.text(s.label), findsOneWidget);
    }
    ctl.add(const UninstallEvent.step('disconnect', UStepState.running));
    await settle(t, 600);
    expect(find.text('Disconnecting and restoring your network'), findsWidgets);
    ctl.add(const UninstallEvent.step('disconnect', UStepState.done));
    ctl.add(const UninstallEvent.step('firewall', UStepState.running));
    await settle(t, 600);
    ctl.add(const UninstallEvent.finished());
    await settle(t, 2000);
    expect(find.text('OnionDesk has been uninstalled'), findsOneWidget);
    expect(find.textContaining('Closing in'), findsOneWidget);
    await settle(t, 2500);
    expect(exits, 1, reason: 'asks the app to exit once the countdown ends');
  });

  testWidgets('cannot be dismissed with the back gesture while running', (t) async {
    t.view.physicalSize = const Size(1080, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(app(Builder(
      builder: (ctx) => TextButton(
        onPressed: () => Navigator.of(ctx).push(MaterialPageRoute<void>(
          builder: (_) => UninstallPage(plan: pkgPlan(), start: () => ctl.stream, onBack: () {}, onExit: () {}),
        )),
        child: const Text('go'),
      ),
    )));
    await t.tap(find.text('go'));
    await settle(t);
    expect(find.text('Uninstalling OnionDesk'), findsOneWidget);
    await t.binding.handlePopRoute();
    await settle(t, 800);
    expect(find.text('Uninstalling OnionDesk'), findsOneWidget, reason: 'still on the page');
  });

  testWidgets('cancelled administrator prompt: shows the message, Back and Try again; Try again restarts', (t) async {
    t.view.physicalSize = const Size(1080, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(page());
    await settle(t);
    ctl.add(const UninstallEvent.failed('firewall', 'Administrator permission was not granted. Nothing was removed.', cancelled: true));
    await settle(t, 1200);
    expect(find.text('Uninstall cancelled'), findsOneWidget);
    expect(find.textContaining('Nothing was removed'), findsOneWidget);
    expect(find.text('Back to OnionDesk'), findsOneWidget);
    expect(starts, 1);
    await t.tap(find.text('Try again'));
    await settle(t, 600);
    expect(starts, 2);
    expect(find.text('Uninstalling OnionDesk'), findsOneWidget);
  });

  testWidgets('a hard failure offers Close and Try again', (t) async {
    t.view.physicalSize = const Size(1080, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(page());
    await settle(t);
    ctl.add(const UninstallEvent.failed('package', 'rpm could not remove oniondesk: database is locked'));
    await settle(t, 1200);
    expect(find.text('Uninstall stopped'), findsOneWidget);
    expect(find.textContaining('database is locked'), findsOneWidget);
    await t.tap(find.text('Close'));
    expect(backs, 1);
  });

  testWidgets('preview (dry run) finishes with a Back button and never asks to exit', (t) async {
    t.view.physicalSize = const Size(1080, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(page(dry: true));
    await settle(t);
    ctl.add(const UninstallEvent.finished());
    await settle(t, 3500);
    expect(find.text('Preview finished'), findsOneWidget);
    expect(find.text('Back to OnionDesk'), findsOneWidget);
    expect(exits, 0);
  });

  testWidgets('confirmation dialog lists what is removed and returns the data choice', (t) async {
    t.view.physicalSize = const Size(1080, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    bool? result = false;
    await t.pumpWidget(app(Builder(builder: (ctx) => TextButton(onPressed: () async => result = await showUninstallConfirm(ctx, planFor: (d) => pkgPlan(data: d)), child: const Text('open')))));
    await t.tap(find.text('open'));
    await settle(t, 800);
    expect(find.text('Uninstall OnionDesk?'), findsOneWidget);
    expect(find.textContaining('system-wide helper'), findsOneWidget);
    expect(find.textContaining('Your settings and saved data'), findsOneWidget);
    await t.tap(find.text('Also delete my settings and saved data'));
    await settle(t, 400);
    expect(find.textContaining('Your settings and saved data'), findsNothing, reason: 'list updates when the box is unticked');
    await t.tap(find.text('Uninstall'));
    await settle(t, 600);
    expect(result, isFalse, reason: 'unticked = keep data');
  });

  testWidgets('cancel in the confirmation dialog returns null', (t) async {
    t.view.physicalSize = const Size(1080, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    bool? result = true;
    await t.pumpWidget(app(Builder(builder: (ctx) => TextButton(onPressed: () async => result = await showUninstallConfirm(ctx, planFor: (d) => pkgPlan(data: d)), child: const Text('open')))));
    await t.tap(find.text('open'));
    await settle(t, 800);
    await t.tap(find.text('Cancel'));
    await settle(t, 600);
    expect(result, isNull);
  });

  // Visual QA: QA_PNG_DIR=/some/dir flutter test test/uninstall_page_test.dart writes a PNG per state.
  final qaDir = Platform.environment['QA_PNG_DIR'];
  testWidgets('render states to PNG (only when QA_PNG_DIR is set)', (t) async {
    await loadFonts();
    t.view.physicalSize = const Size(1080, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final key = GlobalKey();
    Future<void> shot(String name) async {
      await t.runAsync(() async {
        final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await b.toImage();
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$qaDir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
      });
    }

    await t.pumpWidget(RepaintBoundary(key: key, child: page()));
    await settle(t, 1800);
    ctl.add(const UninstallEvent.step('disconnect', UStepState.done));
    ctl.add(const UninstallEvent.step('firewall', UStepState.done));
    ctl.add(const UninstallEvent.step('package', UStepState.running));
    await settle(t, 1500);
    await shot('1-running');
    ctl.add(const UninstallEvent.step('package', UStepState.done));
    ctl.add(const UninstallEvent.step('system', UStepState.done));
    ctl.add(const UninstallEvent.step('data', UStepState.running));
    await settle(t, 1500);
    await shot('2-almost');
    ctl.add(const UninstallEvent.finished());
    await settle(t, 2200);
    await shot('3-done');
    await t.pumpWidget(const SizedBox());
    ctl = StreamController<UninstallEvent>();
    await t.pumpWidget(RepaintBoundary(key: key, child: page()));
    await settle(t, 1200);
    ctl.add(const UninstallEvent.failed('firewall', 'Administrator permission was not granted. Nothing was removed.', cancelled: true));
    await settle(t, 1500);
    await shot('4-cancelled');
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(RepaintBoundary(key: key, child: app(Builder(builder: (ctx) => Scaffold(body: Center(child: TextButton(onPressed: () => showUninstallConfirm(ctx, planFor: (d) => pkgPlan(data: d)), child: const Text('open'))))))));
    await t.tap(find.text('open'));
    await settle(t, 900);
    await shot('5-confirm');
  }, skip: qaDir == null);
}

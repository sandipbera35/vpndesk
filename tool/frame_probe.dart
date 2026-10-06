// Profile-mode frame timing probe: `flutter run --profile -d linux -t tool/frame_probe.dart`
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:oniondesk/main.dart' as app;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final b = <double>[], r = <double>[];
  SchedulerBinding.instance.addTimingsCallback((ts) {
    for (final t in ts) {
      b.add(t.buildDuration.inMicroseconds / 1000);
      r.add(t.rasterDuration.inMicroseconds / 1000);
    }
  });
  Timer.periodic(const Duration(seconds: 3), (_) {
    if (b.isEmpty) return;
    double p(List<double> l, double q) { final s = [...l]..sort(); return s[(s.length * q).floor().clamp(0, s.length - 1)]; }
    // ignore: avoid_print
    print('PROBE frames=${b.length} build p50=${p(b, .5).toStringAsFixed(1)} p95=${p(b, .95).toStringAsFixed(1)} max=${p(b, 1).toStringAsFixed(1)} | raster p50=${p(r, .5).toStringAsFixed(1)} p95=${p(r, .95).toStringAsFixed(1)} max=${p(r, 1).toStringAsFixed(1)}');
    b.clear(); r.clear();
  });
  app.main();
  Offset? find(String t) {
    Offset? out;
    void walk(Element e) {
      if (out != null) return;
      final w = e.widget;
      if (w is Text && w.data == t) { final ro = e.renderObject as RenderBox; out = ro.localToGlobal(ro.size.center(Offset.zero)); return; }
      e.visitChildren(walk);
    }
    WidgetsBinding.instance.rootElement?.visitChildren(walk);
    return out;
  }
  var id = 1;
  void tap(Offset p) {
    final g = GestureBinding.instance;
    g.handlePointerEvent(PointerAddedEvent(position: p, pointer: id));
    g.handlePointerEvent(PointerDownEvent(position: p, pointer: id));
    g.handlePointerEvent(PointerUpEvent(position: p, pointer: id));
  }
  Future<void> scrollSidebar() async {
    final p = find('Locations');
    if (p == null) return;
    final at = p + const Offset(0, 200);
    for (var i = 0; i < 120; i++) {
      GestureBinding.instance.handlePointerEvent(PointerScrollEvent(position: at, scrollDelta: Offset(0, i < 60 ? 30 : -30)));
      await Future.delayed(const Duration(milliseconds: 16));
    }
  }
  Future.delayed(const Duration(seconds: 8), () async {
    print('PHASE scroll-idle'); await scrollSidebar();
    await Future.delayed(const Duration(seconds: 4));
    print('PHASE connect'); final c = find('Connect'); if (c != null) tap(c);
    await Future.delayed(const Duration(seconds: 25));
    print('PHASE connected-steady');
    await Future.delayed(const Duration(seconds: 9));
    print('PHASE connected-scroll'); await scrollSidebar();
    await Future.delayed(const Duration(seconds: 4));
    print('PHASE disconnect'); final d = find('Disconnect'); if (d != null) tap(d);
    await Future.delayed(const Duration(seconds: 6));
    print('PHASE done');
  });
}

// Presses Connect in the real app and then keeps it connected for a while (speed A/B between app versions).
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:oniondesk/main.dart' as app;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  app.main();
  Future<void> go() async {
    await Future.delayed(Duration(seconds: int.tryParse(Platform.environment['PROBE_CONNECT_DELAY'] ?? '') ?? 8));
    Offset? out;
    void walk(Element e) {
      if (out != null) return;
      final w = e.widget;
      if (w is Text && w.data == 'Connect') { final ro = e.renderObject as RenderBox; out = ro.localToGlobal(ro.size.center(Offset.zero)); return; }
      e.visitChildren(walk);
    }
    WidgetsBinding.instance.rootElement?.visitChildren(walk);
    if (out != null) {
      final g = GestureBinding.instance;
      g.handlePointerEvent(PointerAddedEvent(position: out!, pointer: 1));
      g.handlePointerEvent(PointerDownEvent(position: out!, pointer: 1));
      g.handlePointerEvent(PointerUpEvent(position: out!, pointer: 1));
    }
    print('CONNECT pressed');
  }
  go();
}

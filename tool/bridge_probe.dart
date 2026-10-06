// Connect with the bridge mode saved in settings.json and report when "Protected" shows up.
import 'package:flutter/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:oniondesk/main.dart' as app;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  app.main();
  bool has(String t) {
    var f = false;
    void walk(Element e) {
      if (f) return;
      final w = e.widget;
      if (w is Text && (w.data ?? '').startsWith(t)) { f = true; return; }
      e.visitChildren(walk);
    }
    WidgetsBinding.instance.rootElement?.visitChildren(walk);
    return f;
  }
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
  Future<void> go() async {
    await Future.delayed(const Duration(seconds: 8));
    print('BRIDGE pill: ${has('Bridges: snowflake')}');
    final c = find('Connect');
    if (c != null) {
      final g = GestureBinding.instance;
      g.handlePointerEvent(PointerAddedEvent(position: c, pointer: 1));
      g.handlePointerEvent(PointerDownEvent(position: c, pointer: 1));
      g.handlePointerEvent(PointerUpEvent(position: c, pointer: 1));
    }
    for (var i = 1; i <= 24; i++) {
      await Future.delayed(const Duration(seconds: 5));
      print('BRIDGE t=${i * 5}s protected=${has('Protected')} building=${has('Building a Tor circuit')}');
      if (has('Protected')) break;
    }
    await Future.delayed(const Duration(seconds: 15));
    final d = find('Disconnect');
    if (d != null) {
      final g = GestureBinding.instance;
      g.handlePointerEvent(PointerAddedEvent(position: d, pointer: 2));
      g.handlePointerEvent(PointerDownEvent(position: d, pointer: 2));
      g.handlePointerEvent(PointerUpEvent(position: d, pointer: 2));
    }
    await Future.delayed(const Duration(seconds: 4));
    print('BRIDGE done');
  }
  go();
}

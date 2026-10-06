// Connect, then switch country twice, printing the exit IP card each time (headless check that the IP really changes).
import 'package:flutter/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:oniondesk/main.dart' as app;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  app.main();
  final ipRe = RegExp(r'^\d+\.\d+\.\d+\.\d+');
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
  String ips() {
    final f = <String>[];
    void walk(Element e) {
      final w = e.widget;
      if (w is Text && w.data != null && ipRe.hasMatch(w.data!)) f.add(w.data!);
      e.visitChildren(walk);
    }
    WidgetsBinding.instance.rootElement?.visitChildren(walk);
    return f.join(' | ');
  }
  var id = 1;
  void tap(Offset p) {
    final g = GestureBinding.instance;
    g.handlePointerEvent(PointerAddedEvent(position: p, pointer: id));
    g.handlePointerEvent(PointerDownEvent(position: p, pointer: id));
    g.handlePointerEvent(PointerUpEvent(position: p, pointer: id));
    id++;
  }
  Future<void> go() async {
    await Future.delayed(const Duration(seconds: 8));
    final c = find('Connect'); if (c != null) tap(c);
    await Future.delayed(const Duration(seconds: 45));
    print('SWITCH connected: ${ips()}');
    for (final name in ['Germany', 'Singapore', 'United States']) {
      final p = find(name);
      print('SWITCH tapping $name found=${p != null}');
      if (p != null) tap(p);
      await Future.delayed(const Duration(seconds: 30));
      print('SWITCH after $name: ${ips()}');
    }
    final d = find('Disconnect'); if (d != null) tap(d);
  }
  go();
}

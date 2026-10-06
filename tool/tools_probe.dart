// Headless check of the tools row: connect, New identity (IP must change), Leak test dialog text.
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
  List<String> texts(bool Function(String) ok) {
    final f = <String>[];
    void walk(Element e) {
      final w = e.widget;
      if (w is Text && w.data != null && ok(w.data!)) f.add(w.data!);
      e.visitChildren(walk);
    }
    WidgetsBinding.instance.rootElement?.visitChildren(walk);
    return f;
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
    await Future.delayed(const Duration(seconds: 50));
    print('TOOLS connected: ${texts(ipRe.hasMatch).join(' | ')}');
    print('TOOLS pills: ${texts((t) => const ['New identity', 'Leak test', 'Exclude countries', 'More'].contains(t) || t.startsWith('Auto-rotate')).join(', ')}');
    final n = find('New identity'); if (n != null) tap(n);
    await Future.delayed(const Duration(seconds: 30));
    print('TOOLS after new identity: ${texts(ipRe.hasMatch).join(' | ')}');
    final l = find('Leak test'); if (l != null) tap(l);
    await Future.delayed(const Duration(seconds: 60));
    print('TOOLS leak: ${texts((t) => t.length > 12 && (t.contains('Sites') || t.contains('proxy') || t.contains('Names') || t.contains('WebRTC') || t.contains('plain') || t.contains('DNS') || t.contains('resolved'))).join(' || ')}');
    final x = find('Close'); if (x != null) tap(x);
    await Future.delayed(const Duration(seconds: 2));
    final d = find('Disconnect'); if (d != null) tap(d);
  }
  go();
}

// Prints the sidebar header ("live est. · Ns ago" / "loading…" / "offline") so a headless run can tell if estimates arrived.
import 'package:flutter/widgets.dart';
import 'package:oniondesk/main.dart' as app;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  app.main();
  void probe() {
    final found = <String>[];
    void walk(Element e) {
      final w = e.widget;
      if (w is Text && w.data != null && (w.data!.startsWith('live est') || w.data == 'loading…' || w.data == 'offline' || w.data!.contains('Mbps'))) found.add(w.data!);
      e.visitChildren(walk);
    }
    WidgetsBinding.instance.rootElement?.visitChildren(walk);
    // ignore: avoid_print
    print('STATS ${found.take(4).join(' | ')}');
  }
  for (final s in [10, 25, 45]) { Future.delayed(Duration(seconds: s), probe); }
}

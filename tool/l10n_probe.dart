// Collects every string the UI draws without a translation (run with ONIONDESK_L10N_DUMP=1).
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:oniondesk/l10n.dart' show L10n;
import 'package:oniondesk/main.dart' as app;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    id++;
  }
  Future<void> step(String label, String t, int secs) async {
    final p = find(t);
    if (p != null) tap(p); else print('L10N could not find "$t" for $label');
    await Future.delayed(Duration(seconds: secs));
  }
  void dump(String tag) {
    File('/tmp/claude-1000/-home-sandipbera-opencode-vpn/d8b1c7df-4de0-406d-995d-91572e1cf77d/scratchpad/l10n_missing.txt').writeAsStringSync(L10n.missing.join('\n'));
    print('L10N $tag: ${L10n.missing.length} missing so far');
  }
  Future<void> go() async {
    await Future.delayed(const Duration(seconds: 6));
    dump('idle');
    await step('exclude', 'Exclude countries', 2); dump('exclude'); await step('cancel', 'Cancel', 1);
    await step('more', 'More', 2); dump('more menu');
    await Future.delayed(const Duration(milliseconds: 300));
    GestureBinding.instance.handlePointerEvent(PointerDownEvent(position: const Offset(5, 5), pointer: 99)); GestureBinding.instance.handlePointerEvent(PointerUpEvent(position: const Offset(5, 5), pointer: 99));
    await Future.delayed(const Duration(seconds: 1));
    await step('connect', 'Connect', 50); dump('connected');
    await step('leak', 'Leak test', 70); dump('leak');
    await step('close', 'Close', 2);
    await step('run', 'More', 2);
    await Future.delayed(const Duration(milliseconds: 300));
    await step('runapp', 'Run an app through OnionDesk…', 2); dump('run app dialog'); await step('cancel', 'Cancel', 1);
    await step('disc', 'Disconnect', 5); dump('end');
  }
  go();
}

// Reports the country text in the search box before/after pressing Connect (debugging "country changes by itself").
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:oniondesk/main.dart' as app;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  app.main();
  String field() {
    String t = '?';
    void walk(Element e) {
      final w = e.widget;
      if (w is EditableText && t == '?') { t = w.controller.text; return; }
      e.visitChildren(walk);
    }
    WidgetsBinding.instance.rootElement?.visitChildren(walk);
    return t;
  }
  Offset? find(String s) {
    Offset? o;
    void walk(Element e) {
      if (o != null) return;
      final w = e.widget;
      if (w is Text && w.data == s) { final ro = e.renderObject as RenderBox; o = ro.localToGlobal(ro.size.center(Offset.zero)); return; }
      e.visitChildren(walk);
    }
    WidgetsBinding.instance.rootElement?.visitChildren(walk);
    return o;
  }
  String cfg() { try { return File('${Platform.environment['XDG_CONFIG_HOME']}/oniondesk/settings.json').readAsStringSync(); } catch (_) { return 'none'; } }
  Future<void> go() async {
    for (final t in [2, 4, 6, 8, 12, 20]) { await Future.delayed(Duration(seconds: t == 2 ? 2 : 2)); print('CTRY t=$t field="${field()}" settings=${cfg().replaceAll(RegExp(r',"winW.*'), '')}'); }
    final c = find('Connect');
    print('CTRY connect at $c');
    if (c != null) {
      final g = GestureBinding.instance;
      g.handlePointerEvent(PointerAddedEvent(position: c, pointer: 1));
      g.handlePointerEvent(PointerDownEvent(position: c, pointer: 1));
      g.handlePointerEvent(PointerUpEvent(position: c, pointer: 1));
    }
    for (var i = 0; i < 4; i++) { await Future.delayed(const Duration(seconds: 3)); print('CTRY after-connect field="${field()}" settings=${cfg().replaceAll(RegExp(r',"winW.*'), '')}'); }
    print('CTRY done');
  }
  go();
}

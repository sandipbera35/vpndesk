// Saves PNG screenshots of the running app: idle, settings page, connected (map with guard/middle labels).
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:oniondesk/main.dart' as app;

const out = '/tmp/claude-1000/-home-sandipbera-opencode-vpn/d8b1c7df-4de0-406d-995d-91572e1cf77d/scratchpad';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  app.main();
  Future<void> shot(String name) async {
    final rv = RendererBinding.instance.renderViews.first;
    // ignore: invalid_use_of_protected_member
    final layer = rv.layer! as OffsetLayer;
    final img = await layer.toImage(Offset.zero & (rv.size * rv.flutterView.devicePixelRatio));
    final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!;
    File('$out/shot_$name.png').writeAsBytesSync(bytes.buffer.asUint8List());
    print('SHOT $name');
  }
  Offset? findText(String t) {
    Offset? o;
    void walk(Element e) {
      if (o != null) return;
      final w = e.widget;
      if (w is Text && w.data == t) { final ro = e.renderObject as RenderBox; o = ro.localToGlobal(ro.size.center(Offset.zero)); return; }
      e.visitChildren(walk);
    }
    WidgetsBinding.instance.rootElement?.visitChildren(walk);
    return o;
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
    await Future.delayed(const Duration(seconds: 6));
    final c = findText('Connect');
    if (c != null) tap(c);
    var n = 0;
    var done = false;
    for (var i = 0; i < 160 && !done; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (i % 4 == 0 && n < 8) await shot('ring_${n++}');
      if (findText('Protected') != null) {
        for (var k = 0; k < 7; k++) { await shot('burst_$k'); await Future.delayed(const Duration(milliseconds: 140)); }
        done = true;
      }
    }
    final d = findText('Disconnect');
    if (d != null) tap(d);
    await Future.delayed(const Duration(seconds: 4));
    print('SHOT done');
  }
  go();
}

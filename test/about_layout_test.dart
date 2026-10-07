import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oniondesk/about_page.dart';

void main() {
  for (final w in [1000.0, 700.0, 480.0]) {
    testWidgets('About page lays out without overflow at $w px', (t) async {
      t.view.physicalSize = Size(w, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(theme: ThemeData.dark(), home: const AboutPage(windowDots: SizedBox())));
      await t.pump(const Duration(seconds: 2));
      expect(t.takeException(), isNull);
    });
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oniondesk/legal_page.dart';

void main() {
  test('parses headings, bullets, tables and paragraphs', () {
    final b = parseLegalMarkdown('# Title\n\nline one\nline two\n\n- a bullet\n\n| When | Contacts | Sees |\n|---|---|---|\n| Not connected | ipify | your **IP** |\n');
    expect(b[0], isA<LegalHeading>());
    expect((b[1] as LegalParagraph).text, 'line one line two');
    expect((b[2] as LegalBullet).text, 'a bullet');
    final row = b[3] as LegalRow;
    expect(row.title, 'Not connected');
    expect(row.fields, [('Contacts', 'ipify'), ('Sees', 'your **IP**')]);
    expect(b.length, 4);
  });

  test('every shipped legal file is declared as an asset and parses', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final d in kLegalDocs) {
      for (final a in d.assets) {
        expect(pubspec.contains('- $a'), isTrue, reason: '$a must be in pubspec assets');
        expect(File(a).existsSync(), isTrue);
      }
    }
    expect(parseLegalMarkdown(File('PRIVACY.md').readAsStringSync()).whereType<LegalRow>().length, greaterThan(5));
  });

  for (final w in [1000.0, 420.0]) {
    testWidgets('legal page shows every tab at $w px without overflow', (t) async {
      t.view.physicalSize = Size(w, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: LegalPage(windowDots: const SizedBox(), loader: (a) => Future.value(File(a).readAsStringSync())),
      ));
      for (var i = 0; i < kLegalDocs.length; i++) {
        await t.tap(find.text(kLegalDocs[i].title).first);
        await t.pump(const Duration(milliseconds: 300));
        await t.pump();
        final ex = t.takeException();
        expect(ex, isNull, reason: '${kLegalDocs[i].title}: $ex');
        if (i == 1) expect(find.textContaining('Apache License', findRichText: true), findsWidgets);
      }
    });
  }
}

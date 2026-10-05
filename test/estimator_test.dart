import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_desk/estimator.dart';

void main() {
  final t0 = DateTime(2026, 10, 5, 12);

  group('Smoothed', () {
    test('EWMA smooths a single outlier instead of following it', () {
      final s = Smoothed(alpha: 0.4);
      for (var i = 0; i < 5; i++) { s.add('de', 10, t0.add(Duration(minutes: i))); }
      s.add('de', 2, t0.add(const Duration(minutes: 5)));
      final v = s.value('de', t0.add(const Duration(minutes: 5)))!;
      expect(v, greaterThan(6), reason: 'one bad sample must not collapse the estimate');
      expect(v, lessThan(10));
    });

    test('samples older than maxAge are dropped', () {
      final s = Smoothed(maxAge: const Duration(hours: 1));
      s.add('nl', 5, t0);
      expect(s.value('nl', t0.add(const Duration(minutes: 59))), 5);
      expect(s.value('nl', t0.add(const Duration(minutes: 61))), isNull);
    });

    test('keeps at most `keep` samples and survives a JSON round trip', () {
      final s = Smoothed(keep: 3);
      for (var i = 0; i < 10; i++) { s.add('fr', i.toDouble(), t0.add(Duration(seconds: i))); }
      final s2 = Smoothed(keep: 3)..load(s.toJson(), t0.add(const Duration(seconds: 10)));
      expect(s2.value('fr', t0.add(const Duration(seconds: 10))), s.value('fr', t0.add(const Duration(seconds: 10))));
    });

    test('tolerates garbage on load', () {
      final s = Smoothed()..load('nonsense', t0)..load(null, t0);
      expect(s.value('x', t0), isNull);
    });
  });

  group('AutoSwitch', () {
    final a = AutoSwitch();
    final long = t0.subtract(const Duration(hours: 1));
    String? pick({required Map<String, double> m, required Map<String, double> e, String current = 'de', DateTime? last, bool force = false}) => a.pick(
        current: current, candidates: e.keys, measured: (c) => m[c], estimate: (c) => e[c], now: t0, lastSwitch: last ?? long, force: force);

    test('needs a >=25% margin', () {
      expect(pick(m: {'de': 10, 'nl': 12}, e: {'de': 9, 'nl': 9}), isNull);
      expect(pick(m: {'de': 10, 'nl': 12.6}, e: {'de': 9, 'nl': 9}), 'nl');
    });

    test('cooldown of 5 minutes blocks a switch unless forced', () {
      final recent = t0.subtract(const Duration(minutes: 2));
      expect(pick(m: {'de': 5, 'nl': 20}, e: {'de': 5, 'nl': 20}, last: recent), isNull);
      expect(pick(m: {'de': 5, 'nl': 20}, e: {'de': 5, 'nl': 20}, last: recent, force: true), 'nl');
    });

    test('never compares the current MEASURED speed with a candidate ESTIMATE', () {
      // current measured 3 Mbps (real, slow right now); candidate estimated 4 (optimistic scale). Mixed domain
      // would say 4 > 3*1.25 and switch; same-domain says current's estimate is 8, candidate 4 -> stay.
      expect(pick(m: {'de': 3}, e: {'de': 8, 'nl': 4}), isNull);
    });

    test('falls back to estimates for both when only one side has a measurement', () {
      expect(pick(m: {'de': 3}, e: {'de': 4, 'nl': 6}), 'nl');
    });

    test('picks the best candidate, not just the first', () {
      expect(pick(m: {}, e: {'de': 5, 'nl': 7, 'se': 11}), 'se');
    });
  });
}

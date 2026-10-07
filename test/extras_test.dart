import 'package:flutter_test/flutter_test.dart';
import 'package:oniondesk/extras.dart';

void main() {
  test('formatBytes', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(1023), '1023 B');
    expect(formatBytes(1536), '1.5 KB');
    expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
    expect(formatBytes(300 * 1024 * 1024), '300 MB');
  });

  test('formatElapsed', () {
    expect(formatElapsed(const Duration(seconds: 5)), '0:05');
    expect(formatElapsed(const Duration(minutes: 12, seconds: 3)), '12:03');
    expect(formatElapsed(const Duration(hours: 1, minutes: 2, seconds: 9)), '1:02:09');
    expect(formatElapsed(const Duration(seconds: -4)), '0:00');
  });

  test('parseTraffic reads both counters from a control reply', () {
    const r = '250-traffic/read=1234\r\n250 OK\r\n250-traffic/written=99\r\n250 OK\r\n';
    expect(parseTraffic(r, 'read'), 1234);
    expect(parseTraffic(r, 'written'), 99);
    expect(parseTraffic('250 OK', 'read'), isNull);
  });

  test('export leaves out bridge lines and machine-specific keys', () {
    final out = exportSettings({'customBridges': 'obfs4 1.2.3.4:1 SECRET', 'winW': 900, 'recentApps': ['x'], 'rotateMin': 10, 'favorites': ['de']});
    expect(out.containsKey('customBridges'), isFalse);
    expect(out.containsKey('winW'), isFalse);
    expect(out.containsKey('recentApps'), isFalse);
    expect(out['rotateMin'], 10);
    expect(out['favorites'], ['de']);
  });

  test('import keeps only known keys with the right type', () {
    final clean = sanitizeImport({
      'rotateMin': 30, 'autoFastest': 'yes', 'lang': 'es', 'customBridges': 'x', 'systemWide': true,
      'favorites': ['de', 5], 'excluded': ['us', 'gb'], 'themeMode': 'light',
    });
    expect(clean, {'rotateMin': 30, 'lang': 'es', 'excluded': ['us', 'gb'], 'themeMode': 'light'});
    expect(sanitizeImport('not a map'), isEmpty);
    expect(sanitizeImport({'lang': 'x' * 100}), isEmpty);
  });
}

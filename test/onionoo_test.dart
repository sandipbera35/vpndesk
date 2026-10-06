import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oniondesk/onionoo.dart';

void main() {
  late Directory dir;
  late List<Map<String, String>> sent;
  late int status;
  late String body;
  late bool fail;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('onionoo_');
    sent = [];
    status = 200;
    body = '{"relays":[1]}';
    fail = false;
  });
  tearDown(() => dir.deleteSync(recursive: true));

  OnionooCache make({Duration ttl = const Duration(minutes: 30)}) => OnionooCache(
      dir: dir,
      ttl: ttl,
      fetch: (url, h) async {
        sent.add(h);
        if (fail) throw const SocketException('offline');
        return (status: status, body: status == 304 ? '' : body, headers: {'last-modified': 'Mon, 05 Oct 2026 10:00:00 GMT', 'etag': '"abc"'});
      });

  test('within the TTL nothing is fetched at all', () async {
    final c = make();
    expect(await c.get('details?x=1'), body);
    expect(await c.get('details?x=1'), body);
    expect(sent, hasLength(1));
  });

  test('after the TTL a conditional request is sent and a 304 reuses the cached body', () async {
    final c = make(ttl: Duration.zero);
    await c.get('details?x=1');
    status = 304;
    expect(await c.get('details?x=1'), '{"relays":[1]}');
    expect(sent.last['If-Modified-Since'], 'Mon, 05 Oct 2026 10:00:00 GMT');
    expect(sent.last['If-None-Match'], '"abc"');
  });

  test('a changed answer replaces the cache', () async {
    final c = make(ttl: Duration.zero);
    await c.get('details?x=1');
    body = '{"relays":[2]}';
    expect(await c.get('details?x=1'), '{"relays":[2]}');
  });

  test('offline: a cached answer is served; with none, null', () async {
    final c = make(ttl: Duration.zero);
    expect(await c.get('details?x=1'), body);
    fail = true;
    expect(await c.get('details?x=1'), body);
    expect(await c.get('details?never=1'), isNull);
  });

  test('offline and too stale: null', () async {
    final c = make(ttl: Duration.zero);
    await c.get('details?x=1');
    fail = true;
    expect(await c.get('details?x=1', maxStale: Duration.zero), isNull);
  });

  test('a non-JSON 200 is never cached', () async {
    final c = make(ttl: Duration.zero);
    body = '<html>captive portal</html>';
    expect(await c.get('details?x=1'), isNull);
    expect(dir.listSync(), isEmpty);
    expect(() => jsonDecode(body), throwsFormatException);
  });
}

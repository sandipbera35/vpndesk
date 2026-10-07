import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:oniondesk/browser_page.dart';

void main() {
  String dataUrl(String html) => 'data:text/html;base64,${Uri.encodeComponent(base64.encode(utf8.encode(html)))}';

  test('a failed-load page of the engine is read back as (url, error)', () {
    final r = parseLoadError(dataUrl('<html><body bgcolor="white"><h2>Failed to load URL http://i2pforum.i2p/ with error ERR_SOCKS_CONNECTION_FAILED (-120).</h2></body></html>'))!;
    expect(r.url, 'http://i2pforum.i2p/');
    expect(r.error, 'ERR_SOCKS_CONNECTION_FAILED');
  });

  test('other addresses are not errors', () {
    expect(parseLoadError('http://stats.i2p/'), isNull);
    expect(parseLoadError('about:blank'), isNull);
    expect(parseLoadError(dataUrl('<html>hello</html>')), isNull);
    expect(parseLoadError('data:text/html;base64,%%%not-base64'), isNull);
  });
}

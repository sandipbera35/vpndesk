import 'package:flutter_test/flutter_test.dart';
import 'package:oniondesk/browser_nav.dart';

void main() {
  String? r(String s, {bool tor = true, bool i2p = true}) => resolveAddress(s, useTor: tor, useI2p: i2p);

  test('a bare .i2p name is opened, not searched (the bug of the stock address bar)', () {
    expect(r('i2p-projekt.i2p'), 'http://i2p-projekt.i2p');
    expect(r('stats.i2p/cgi-bin/jump.cgi?a=x'), 'http://stats.i2p/cgi-bin/jump.cgi?a=x');
    expect(r('  i2pforum.i2p  '), 'http://i2pforum.i2p');
    expect(r('abc123.b32.i2p'), 'http://abc123.b32.i2p');
  });

  test('other dotted names are opened over https', () {
    expect(r('example.com'), 'https://example.com');
    expect(r('example.com/a?b=c'), 'https://example.com/a?b=c');
    expect(r('check.torproject.org'), 'https://check.torproject.org');
  });

  test('full addresses are kept; dangerous schemes are refused', () {
    expect(r('http://a.i2p/x'), 'http://a.i2p/x');
    expect(r('https://example.com/'), 'https://example.com/');
    expect(r('file:///etc/passwd'), isNull);
    expect(r('chrome://settings'), isNull);
    expect(r('javascript:alert(1)'), isNull);
    expect(r('data:text/html,hi'), isNull);
    expect(r('view-source:https://example.com'), isNull);
    expect(r('about:blank'), 'about:blank');
    expect(r(''), isNull);
  });

  test('host:port is a host', () {
    expect(r('127.0.0.1:7070'), 'https://127.0.0.1:7070');
    expect(r('localhost:8080/x'), 'https://localhost:8080/x');
  });

  test('searches never go to Google: DuckDuckGo, or the I2P engine when only I2P is on', () {
    expect(r('hello world'), 'https://duckduckgo.com/?q=hello+world');
    expect(r('hello world', tor: false, i2p: true), 'http://legwork.i2p/yacysearch.html?query=hello+world');
    expect(r('hello world', tor: true, i2p: true), 'https://duckduckgo.com/?q=hello+world');
    expect(r('onion', tor: true, i2p: false), 'https://duckduckgo.com/?q=onion');
    expect(r('hello world')!.contains('google'), isFalse);
  });

  test('quick links are all http(s) and the I2P ones are .i2p', () {
    for (final l in kI2pQuickLinks) {
      expect(Uri.parse(l.url).host.endsWith('.i2p'), isTrue, reason: l.url);
    }
    for (final l in [...kI2pQuickLinks, ...kTorQuickLinks]) {
      expect(resolveAddress(l.url, useTor: true, useI2p: true), l.url);
    }
  });

  test('the address bar shows the address the way you would type it', () {
    expect(displayAddress('http://i2pforum.i2p/'), 'i2pforum.i2p');
    expect(displayAddress('https://example.com/'), 'example.com');
    expect(displayAddress('https://example.com/a/b?c=d'), 'example.com/a/b?c=d');
    expect(displayAddress('http://stats.i2p/cgi-bin/jump.cgi?a=x'), 'stats.i2p/cgi-bin/jump.cgi?a=x');
    expect(displayAddress('i2p-projekt.i2p'), 'i2p-projekt.i2p');
    expect(displayAddress('about:blank'), 'about:blank');
  });
}

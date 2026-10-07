import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:oniondesk/browser_mux.dart';

/// A fake SOCKS5 upstream: records "host:port" of every CONNECT, then behaves as an echo server (or refuses).
class FakeSocks {
  final seen = <String>[];
  late ServerSocket server;
  int get port => server.port;
  Future<void> start() async {
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((c) {
      final buf = <int>[];
      var step = 0;
      c.done.catchError((_) {});
      c.listen((d) {
        buf.addAll(d);
        if (step == 0 && buf.length >= 3) { buf.removeRange(0, 3); c.add([5, 0]); step = 1; }
        if (step == 1 && buf.length >= 5) {
          final n = buf[4];
          if (buf.length >= 7 + n) {
            seen.add('${String.fromCharCodes(buf.sublist(5, 5 + n))}:${(buf[5 + n] << 8) | buf[6 + n]}');
            buf.removeRange(0, 7 + n);
            c.add([5, 0, 0, 1, 0, 0, 0, 0, 0, 0]);
            step = 2;
          }
        }
        if (step == 2 && buf.isNotEmpty) {
          // echo, so tests can see exactly what arrived after the tunnel was set up
          final txt = latin1.decode(buf);
          buf.clear();
          if (txt.contains('\r\n\r\n')) {
            c.add(latin1.encode('HTTP/1.1 200 OK\r\nContent-Length: ${txt.length}\r\nConnection: close\r\n\r\n$txt'));
            c.close();
          } else {
            c.add(latin1.encode(txt));
          }
        }
      }, onError: (_) {});
    }, onError: (_) {});
  }
}

/// A fake i2pd HTTP proxy: records the raw request it gets and answers it (keeps the connection open).
class FakeHttpProxy {
  final requests = <String>[];
  late ServerSocket server;
  int get port => server.port;
  Future<void> start() async {
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((c) {
      c.done.catchError((_) {});
      final buf = <int>[];
      c.listen((d) {
        buf.addAll(d);
        for (;;) {
          final txt = latin1.decode(buf);
          final i = txt.indexOf('\r\n\r\n');
          if (i < 0) break;
          requests.add(txt.substring(0, i));
          buf.removeRange(0, i + 4);
          c.add(latin1.encode('HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nI2Pok'));
        }
      }, onError: (_) {});
    }, onError: (_) {});
  }
}

/// Talk to the proxy like a browser does; returns everything it sends back until it closes (or [wait] passes).
Future<String> viaProxy(int port, String raw, {Duration wait = const Duration(seconds: 2)}) async {
  final s = await Socket.connect('127.0.0.1', port);
  final got = <int>[];
  final done = Completer<void>();
  s.listen(got.addAll, onDone: () => done.complete(), onError: (_) => done.complete());
  s.add(latin1.encode(raw));
  await done.future.timeout(wait, onTimeout: () {});
  s.destroy();
  return latin1.decode(got);
}

void main() {
  late FakeSocks tor, i2pSocks;
  late FakeHttpProxy i2pHttp;
  var torOn = true, i2pOn = true;
  late BrowserMux mux;
  late int port;

  setUp(() async {
    torOn = true;
    i2pOn = true;
    tor = FakeSocks();
    i2pSocks = FakeSocks();
    i2pHttp = FakeHttpProxy();
    await tor.start();
    await i2pSocks.start();
    await i2pHttp.start();
    mux = BrowserMux(torOn: () => torOn, i2pOn: () => i2pOn, torPort: tor.port, i2pSocksPort: i2pSocks.port, i2pHttpPort: i2pHttp.port);
    port = await mux.start();
  });

  tearDown(() async {
    await mux.stop();
    await tor.server.close();
    await i2pSocks.server.close();
    await i2pHttp.server.close();
  });

  test('routing: .i2p to I2P (HTTP proxy for plain pages, SOCKS for tunnels), the rest to Tor, nothing when off', () {
    expect(routeFor('stats.i2p', torOn: true, i2pOn: true, http: true)!.port, 4444);
    expect(routeFor('stats.i2p', torOn: true, i2pOn: true)!.port, 4447);
    expect(routeFor('EXAMPLE.I2P', torOn: false, i2pOn: true)!.label, 'I2P');
    expect(routeFor('example.com', torOn: true, i2pOn: true)!.label, 'Tor');
    expect(routeFor('example.com', torOn: false, i2pOn: true), isNull, reason: 'I2P only: clearnet is refused');
    expect(routeFor('stats.i2p', torOn: true, i2pOn: false), isNull, reason: 'Tor only: .i2p is refused');
    expect(routeFor('notani2p.com', torOn: true, i2pOn: false)!.label, 'Tor');
  });

  test('a plain .i2p page goes to i2pd\'s HTTP proxy exactly as the browser sent it, and keep-alive works', () async {
    final s = await Socket.connect('127.0.0.1', port);
    final got = <int>[];
    s.listen(got.addAll);
    s.add(latin1.encode('GET http://stats.i2p/a HTTP/1.1\r\nHost: stats.i2p\r\nUser-Agent: Chrome\r\n\r\n'));
    await Future.delayed(const Duration(milliseconds: 400));
    s.add(latin1.encode('GET http://stats.i2p/b HTTP/1.1\r\nHost: stats.i2p\r\n\r\n'));
    await Future.delayed(const Duration(milliseconds: 400));
    s.destroy();
    expect(latin1.decode(got), 'HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nI2PokHTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nI2Pok');
    expect(i2pHttp.requests, hasLength(2));
    expect(i2pHttp.requests.first, startsWith('GET http://stats.i2p/a HTTP/1.1'));
    expect(tor.seen, isEmpty);
    expect(i2pSocks.seen, isEmpty);
  });

  test('a plain clearnet page goes through Tor as an origin-form request with Connection: close', () async {
    final r = await viaProxy(port, 'GET http://example.com/x?y=1 HTTP/1.1\r\nHost: example.com\r\nProxy-Connection: keep-alive\r\nConnection: keep-alive\r\n\r\n');
    expect(tor.seen, ['example.com:80']);
    expect(r, contains('GET /x?y=1 HTTP/1.1'));
    expect(r, contains('Host: example.com'));
    expect(r, contains('Connection: close'));
    expect(r, isNot(contains('Proxy-Connection')));
    expect(r, isNot(contains('keep-alive')));
    expect(i2pHttp.requests, isEmpty);
  });

  test('CONNECT (https) goes to the right SOCKS port with the host name, then the tunnel carries data', () async {
    final a = await viaProxy(port, 'CONNECT www.example.org:443 HTTP/1.1\r\nHost: www.example.org:443\r\n\r\n');
    expect(a, startsWith('HTTP/1.1 200 Connection Established'));
    expect(tor.seen, ['www.example.org:443']);
    final b = await viaProxy(port, 'CONNECT stats.i2p:443 HTTP/1.1\r\n\r\n');
    expect(b, startsWith('HTTP/1.1 200 Connection Established'));
    expect(i2pSocks.seen, ['stats.i2p:443']);
  });

  test('fails closed: a network that is off is refused and nothing reaches any upstream', () async {
    torOn = false;
    expect(await viaProxy(port, 'GET http://example.com/ HTTP/1.1\r\nHost: example.com\r\n\r\n'), isEmpty, reason: 'the connection is just dropped');
    expect(await viaProxy(port, 'CONNECT example.com:443 HTTP/1.1\r\n\r\n'), startsWith('HTTP/1.1 403'));
    i2pOn = false;
    expect(await viaProxy(port, 'GET http://stats.i2p/ HTTP/1.1\r\nHost: stats.i2p\r\n\r\n'), isEmpty);
    expect(await viaProxy(port, 'CONNECT stats.i2p:443 HTTP/1.1\r\n\r\n'), startsWith('HTTP/1.1 403'));
    expect(tor.seen, isEmpty);
    expect(i2pSocks.seen, isEmpty);
    expect(i2pHttp.requests, isEmpty);
    expect(mux.refused, 4);
    expect(mux.lastRefused, 'stats.i2p');
  });

  test('toggling takes effect on the next request', () async {
    torOn = false;
    expect(await viaProxy(port, 'CONNECT example.com:443 HTTP/1.1\r\n\r\n'), startsWith('HTTP/1.1 403'));
    torOn = true;
    expect(await viaProxy(port, 'CONNECT example.com:443 HTTP/1.1\r\n\r\n'), startsWith('HTTP/1.1 200'));
  });

  test('anything that is not a proxy request is dropped (no direct fetching, no origin-form, no https absolute URIs)', () async {
    expect(await viaProxy(port, 'GET /local HTTP/1.1\r\nHost: example.com\r\n\r\n'), isEmpty);
    expect(await viaProxy(port, 'GET https://example.com/ HTTP/1.1\r\n\r\n'), isEmpty);
    expect(await viaProxy(port, 'garbage\r\n\r\n'), isEmpty);
    expect(tor.seen, isEmpty);
  });

  test('an upstream that is not running closes the connection cleanly (no hang, no direct connection)', () async {
    final dead = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final deadPort = dead.port;
    await dead.close();
    final m2 = BrowserMux(torOn: () => true, i2pOn: () => true, torPort: deadPort, i2pHttpPort: deadPort, i2pSocksPort: deadPort);
    final p2 = await m2.start();
    addTearDown(m2.stop);
    expect(await viaProxy(p2, 'GET http://example.com/ HTTP/1.1\r\nHost: example.com\r\n\r\n'), isEmpty);
    expect(await viaProxy(p2, 'GET http://stats.i2p/ HTTP/1.1\r\nHost: stats.i2p\r\n\r\n'), isEmpty);
  });
}

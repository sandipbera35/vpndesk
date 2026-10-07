import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// The OnionDesk Browser's one and only route to the network: a local HTTP proxy that the embedded browser engine is
/// pointed at. For every request it decides, by host name, where the traffic goes:
///   * `name.i2p`      -> i2pd (plain pages through i2pd's own HTTP proxy, which also gives the I2P user agent, jump
///                        pages and "host not found" help; https/CONNECT through i2pd's SOCKS port)
///   * everything else -> Tor's SOCKS port
/// and otherwise the request is REFUSED. Nothing ever goes out directly, so switching Tor or I2P off, or a router that
/// is not up yet, can never leak a request to the clear internet (it fails closed). Names (never addresses) are handed
/// to the upstream, so Tor / I2P resolve them.

/// Where one request goes.
class MuxTarget {
  const MuxTarget(this.host, this.port, this.label);
  final String host;
  final int port;
  final String label; // 'Tor' or 'I2P'
}

/// Pure routing rule. [torOn]/[i2pOn]: that network is connected and usable. [http]: a plain (non-CONNECT) request,
/// which for I2P goes to i2pd's HTTP proxy instead of its SOCKS port.
MuxTarget? routeFor(String host, {required bool torOn, required bool i2pOn, bool http = false, int torPort = 9050, int i2pSocksPort = 4447, int i2pHttpPort = 4444}) {
  final h = host.toLowerCase();
  if (h == 'i2p' || h.endsWith('.i2p')) return i2pOn ? MuxTarget('127.0.0.1', http ? i2pHttpPort : i2pSocksPort, 'I2P') : null;
  return torOn ? MuxTarget('127.0.0.1', torPort, 'Tor') : null;
}

/// Reads a socket in pieces, then can hand the connection over to a plain pipe.
class _Buf {
  _Buf(this.socket) {
    _sub = socket.listen((d) {
      _b.addAll(d);
      _wake();
    }, onDone: () {
      _closed = true;
      _wake();
    }, onError: (_) {
      _closed = true;
      _wake();
    }, cancelOnError: true);
  }
  final Socket socket;
  late final StreamSubscription<Uint8List> _sub;
  final List<int> _b = [];
  bool _closed = false;
  Completer<void>? _w;

  void _wake() {
    final w = _w;
    _w = null;
    if (w != null && !w.isCompleted) w.complete();
  }

  Future<void> _wait(DateTime end) async {
    if (_closed) throw const SocketException('closed');
    final left = end.difference(DateTime.now());
    if (left.isNegative) throw TimeoutException('read');
    _w = Completer<void>();
    await _w!.future.timeout(left, onTimeout: () {});
  }

  /// Exactly [n] bytes, or throws if the peer closed first (or [timeout] passed).
  Future<List<int>> take(int n, {Duration timeout = const Duration(seconds: 20)}) async {
    final end = DateTime.now().add(timeout);
    while (_b.length < n) { await _wait(end); }
    final out = _b.sublist(0, n);
    _b.removeRange(0, n);
    return out;
  }

  /// Everything up to and including the blank line that ends an HTTP head; what follows stays buffered.
  Future<List<int>> takeHead({int max = 64 * 1024, Duration timeout = const Duration(seconds: 30)}) async {
    final end = DateTime.now().add(timeout);
    for (;;) {
      final i = _indexOfHeadEnd();
      if (i >= 0) {
        final out = _b.sublist(0, i + 4);
        _b.removeRange(0, i + 4);
        return out;
      }
      if (_b.length > max) throw const FormatException('request head too large');
      await _wait(end);
    }
  }

  int _indexOfHeadEnd() {
    for (var i = 0; i + 3 < _b.length; i++) {
      if (_b[i] == 13 && _b[i + 1] == 10 && _b[i + 2] == 13 && _b[i + 3] == 10) return i;
    }
    return -1;
  }

  /// From now on everything this socket sends goes to [other]; whatever is already buffered goes first.
  void pipeTo(Socket other) {
    if (_b.isNotEmpty) {
      other.add(List<int>.from(_b));
      _b.clear();
    }
    _sub.onData((d) => other.add(d));
    _sub.onDone(() {
      other.close().catchError((_) {});
    });
    _sub.onError((_) {
      other.destroy();
    });
    if (_closed) other.close().catchError((_) {});
  }
}

class MuxEvents {
  final List<void Function()> _l = [];
  void addListener(void Function() f) => _l.add(f);
  void removeListener(void Function() f) => _l.remove(f);
  void notify() {
    for (final f in List.of(_l)) {
      f();
    }
  }
}

class BrowserMux {
  BrowserMux({required this.torOn, required this.i2pOn, this.torPort = 9050, this.i2pSocksPort = 4447, this.i2pHttpPort = 4444});

  /// Asked for every new request (so connecting / disconnecting a network takes effect at once).
  final bool Function() torOn, i2pOn;
  final int torPort, i2pSocksPort, i2pHttpPort;

  ServerSocket? _server;
  int get port => _server?.port ?? 0;
  bool get running => _server != null;

  /// Refused requests since start, and the last refused name (shown to the user: "turn on Tor to open this").
  int refused = 0;
  String? lastRefused;
  final MuxEvents changed = MuxEvents();

  /// Start listening on a free loopback port (IPv4 only) and return it.
  Future<int> start() async {
    if (_server != null) return _server!.port;
    final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _server = s;
    s.listen((c) => _handle(c).catchError((_) {}), onError: (_) {});
    return s.port;
  }

  Future<void> stop() async {
    final s = _server;
    _server = null;
    await s?.close();
  }

  void _refuse(String host) {
    refused++;
    lastRefused = host;
    changed.notify();
  }

  Future<void> _handle(Socket client) async {
    client.setOption(SocketOption.tcpNoDelay, true);
    final c = _Buf(client);
    Socket? up;
    try {
      final head = latin1.decode(await c.takeHead());
      final lines = head.split('\r\n');
      final first = lines.first.split(' ');
      if (first.length < 3) throw const FormatException('bad request line');
      final method = first[0].toUpperCase();
      final target = first[1];

      if (method == 'CONNECT') {
        final i = target.lastIndexOf(':');
        final host = (i > 0 ? target.substring(0, i) : target).replaceAll(RegExp(r'^\[|\]$'), '');
        final port = i > 0 ? int.tryParse(target.substring(i + 1)) ?? 443 : 443;
        final t = routeFor(host, torOn: torOn(), i2pOn: i2pOn(), torPort: torPort, i2pSocksPort: i2pSocksPort, i2pHttpPort: i2pHttpPort);
        if (t == null) {
          _refuse(host);
          client.add(latin1.encode('HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\n\r\n'));
          throw const FormatException('refused');
        }
        final tun = await _socksConnect(t, host, port);
        client.add(latin1.encode('HTTP/1.1 200 Connection Established\r\n\r\n'));
        c.pipeTo(tun.$1);
        tun.$2.pipeTo(client);
        return;
      }

      // A plain request in absolute form: "GET http://host/path HTTP/1.1".
      final uri = Uri.tryParse(target);
      if (uri == null || !uri.hasAuthority || (uri.scheme != 'http')) throw const FormatException('not an absolute http request');
      final host = uri.host;
      final t = routeFor(host, torOn: torOn(), i2pOn: i2pOn(), http: true, torPort: torPort, i2pSocksPort: i2pSocksPort, i2pHttpPort: i2pHttpPort);
      if (t == null) {
        _refuse(host);
        throw const FormatException('refused'); // the connection is dropped: the browser shows its own "cannot be opened" page
      }
      if (t.label == 'I2P') {
        // i2pd's HTTP proxy does the rest: it rewrites the headers like every I2P browser and understands jump pages.
        up = await Socket.connect(t.host, t.port, timeout: const Duration(seconds: 8));
        up.setOption(SocketOption.tcpNoDelay, true);
        up.add(latin1.encode(head));
        final s = up;
        c.pipeTo(s);
        _Buf(s).pipeTo(client);
        up = null;
        return;
      }
      // Tor: a plain HTTP request over a SOCKS tunnel, as origin-form, one request per connection.
      final port = uri.hasPort ? uri.port : 80;
      final tun = await _socksConnect(t, host, port);
      final path = '${uri.path.isEmpty ? '/' : uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
      final hs = <String>['$method $path ${first[2]}'];
      var hasHost = false;
      for (final l in lines.skip(1)) {
        if (l.isEmpty) continue;
        final k = l.split(':').first.toLowerCase();
        if (k == 'proxy-connection' || k == 'connection' || k == 'proxy-authorization') continue;
        if (k == 'host') hasHost = true;
        hs.add(l);
      }
      if (!hasHost) hs.add('Host: ${uri.hasPort ? '$host:${uri.port}' : host}');
      hs.add('Connection: close');
      tun.$1.add(latin1.encode('${hs.join('\r\n')}\r\n\r\n'));
      c.pipeTo(tun.$1);
      tun.$2.pipeTo(client);
    } catch (_) {
      up?.destroy();
      client.destroy();
    }
  }

  /// A SOCKS5 tunnel to [host]:[port] through [t]; the name is sent as a name. Returns the socket and its reader.
  Future<(Socket, _Buf)> _socksConnect(MuxTarget t, String host, int port) async {
    final s = await Socket.connect(t.host, t.label == 'I2P' ? i2pSocksPort : t.port, timeout: const Duration(seconds: 8));
    s.setOption(SocketOption.tcpNoDelay, true);
    final u = _Buf(s);
    try {
      s.add([5, 1, 0]);
      final g = await u.take(2);
      if (g[0] != 5 || g[1] != 0) throw const FormatException('upstream refused');
      final name = host.codeUnits;
      s.add([5, 1, 0, 3, name.length, ...name, port >> 8, port & 255]);
      final r = await u.take(4, timeout: const Duration(seconds: 90)); // Tor / I2P can take a while to build a circuit
      if (r[1] != 0) throw FormatException('upstream failed (${r[1]})');
      if (r[3] == 1) {
        await u.take(6);
      } else if (r[3] == 4) {
        await u.take(18);
      } else if (r[3] == 3) {
        final n = (await u.take(1))[0];
        await u.take(n + 2);
      }
      return (s, u);
    } catch (e) {
      s.destroy();
      rethrow;
    }
  }
}

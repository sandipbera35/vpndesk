import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'blocklist.dart';

/// Local SOCKS5 filter in front of Tor. Listens on 127.0.0.1:[listenPort]; CONNECT requests whose hostname
/// is on the blocklist get reply 0x02 (not allowed by ruleset), everything else is piped to Tor on
/// 127.0.0.1:[torPort]. Only domain-name requests are filtered (apps resolving locally are not covered).
class SocksFilter {
  SocksFilter({required this.list, required this.torPort, this.listenPort = 9050});

  final Blocklist list;
  final int torPort;
  final int listenPort;
  int blocked = 0;
  void Function()? onBlocked;
  ServerSocket? _server;
  int get port => _server!.port;
  final Set<Socket> _open = {};

  Future<void> start() async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, listenPort);
    _server!.listen(_handle);
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
    for (final s in _open.toList()) {
      s.destroy();
    }
    _open.clear();
  }

  void _handle(Socket client) {
    _open.add(client);
    client.done.whenComplete(() => _open.remove(client)).catchError((_) {});
    final buf = BytesBuilder();
    late StreamSubscription<Uint8List> sub;
    var greeted = false;
    sub = client.listen((data) async {
      buf.add(data);
      final b = buf.toBytes();
      if (!greeted) {
        if (b.length < 2) return;
        if (b[0] != 5) { client.destroy(); return; }
        final need = 2 + b[1];
        if (b.length < need) return;
        greeted = true;
        buf.clear();
        buf.add(b.sublist(need));
        client.add([5, 0]); // no authentication
        if (buf.length == 0) return;
      }
      final r = buf.toBytes();
      final req = _parseRequest(r);
      if (req == null) return; // need more bytes
      sub.pause();
      if (req.host != null && list.isBlocked(req.host!)) {
        blocked++;
        onBlocked?.call();
        client.add([5, 2, 0, 1, 0, 0, 0, 0, 0, 0]);
        await client.flush().catchError((_) {});
        client.destroy();
        return;
      }
      try {
        final tor = await Socket.connect(InternetAddress.loopbackIPv4, torPort);
        _open.add(tor);
        tor.done.whenComplete(() => _open.remove(tor)).catchError((_) {});
        tor.add([5, 1, 0]); // greet Tor, then replay the buffered request
        final torIn = StreamIterator<Uint8List>(tor);
        if (!await torIn.moveNext()) throw const SocketException('tor closed');
        tor.add(r);
        // From here on, relay both ways; the first reply bytes already read from Tor are the greeting reply
        // (2 bytes) followed by possibly part of the connect reply.
        final first = torIn.current;
        if (first.length > 2) client.add(first.sublist(2));
        sub.resume();
        sub.onData((d) => tor.add(d));
        sub.onDone(() => tor.destroy());
        unawaited(() async {
          try {
            while (await torIn.moveNext()) {
              client.add(torIn.current);
            }
          } catch (_) {}
          client.destroy();
        }());
      } catch (_) {
        client.add([5, 1, 0, 1, 0, 0, 0, 0, 0, 0]);
        client.destroy();
      }
    }, onError: (_) => client.destroy(), cancelOnError: true);
  }

  /// Returns null while the request is incomplete. host is null for IP-address requests.
  static ({String? host})? _parseRequest(Uint8List r) {
    if (r.length < 5) return null;
    if (r[0] != 5) return (host: null);
    switch (r[3]) {
      case 3:
        final n = r[4];
        if (r.length < 5 + n + 2) return null;
        return (host: String.fromCharCodes(r.sublist(5, 5 + n)));
      case 1:
        return r.length < 10 ? null : (host: null);
      case 4:
        return r.length < 22 ? null : (host: null);
    }
    return (host: null);
  }
}

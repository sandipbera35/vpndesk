import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oniondesk/blocklist.dart';
import 'package:oniondesk/socks_filter.dart';

void main() {
  test('matches listed domains and subdomains, not look-alikes or TLDs', () {
    final b = Blocklist()..addAll('# c\n0.0.0.0 ads.example.com # x\ntracker.net\nlocalhost\n');
    expect(b.isBlocked('ads.example.com'), isTrue);
    expect(b.isBlocked('X.Ads.Example.com.'), isTrue);
    expect(b.isBlocked('example.com'), isFalse);
    expect(b.isBlocked('notads.example.com'), isFalse);
    expect(b.isBlocked('a.tracker.net'), isTrue);
    expect(b.isBlocked('net'), isFalse);
  });

  test('filter rejects blocked hosts and relays others to a fake tor', () async {
    // Fake "tor": accepts greeting, then the request, and answers success + echoes data.
    final fake = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    fake.listen((s) {
      var step = 0;
      s.listen((d) {
        if (step++ == 0) { s.add([5, 0]); } else if (step == 2) { s.add([5, 0, 0, 1, 0, 0, 0, 0, 0, 0]); } else { s.add(d); }
      });
    });
    final f = SocksFilter(list: Blocklist()..addAll('ads.example.com'), torPort: fake.port, listenPort: 0);
    await f.start();
    final port = f.port;

    Future<List<int>> ask(String host) async {
      final s = await Socket.connect(InternetAddress.loopbackIPv4, port);
      final out = <int>[];
      final done = Completer<void>();
      s.listen(out.addAll, onDone: done.complete, onError: (_) => done.complete());
      s.add([5, 1, 0]);
      await Future.delayed(const Duration(milliseconds: 100));
      s.add([5, 1, 0, 3, host.length, ...host.codeUnits, 0, 80]);
      await Future.delayed(const Duration(milliseconds: 300));
      s.destroy();
      return out;
    }

    final blocked = await ask('x.ads.example.com');
    expect(blocked.sublist(0, 4), [5, 0, 5, 2]);
    expect(f.blocked, 1);
    final ok = await ask('good.org');
    expect(ok.sublist(0, 4), [5, 0, 5, 0]);
    expect(f.blocked, 1);
    await f.stop();
    await fake.close();
  });
}

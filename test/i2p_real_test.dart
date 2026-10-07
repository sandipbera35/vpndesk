// Runs the real i2pd. Only when I2PD_REAL points at it; skipped otherwise.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:oniondesk/i2p.dart';

void main() {
  final bin = Platform.environment['I2PD_REAL'];
  test('real i2pd', () async {
    final dir = Directory.systemTemp.createTempSync('i2preal');
    final r = I2pRouter(dirOverride: dir)..customPath = bin;
    r.detect();
    await r.start();
    final end = DateTime.now().add(const Duration(minutes: 4));
    while (DateTime.now().isBefore(end)) {
      await Future.delayed(const Duration(seconds: 8));
      await r.refresh();
      final s = r.status;
      stdout.writeln('${DateTime.now().difference(r.startedAt!).inSeconds}s state=${r.state} ver=${s.version} net=${s.netText} routers=${s.routers} tunnels=${s.clientTunnels} succ=${s.successRate} bw=${s.bwIn}/${s.bwOut}');
      if (r.state == I2pState.running) break;
    }
    expect(r.state, I2pState.running);
    for (var i = 0; i < 12; i++) {
      await Future.delayed(const Duration(seconds: 10));
      await r.refresh();
      stdout.writeln('later: succ=${r.status.successRate} tunnels=${r.status.clientTunnels} routers=${r.status.routers}');
    }
    final c = HttpClient();
    c.findProxy = (_) => 'PROXY 127.0.0.1:4444';
    try {
      final req = await c.getUrl(Uri.parse('http://stats.i2p/')).timeout(const Duration(seconds: 90));
      final res = await req.close().timeout(const Duration(seconds: 90));
      stdout.writeln('PROXY GET stats.i2p -> ${res.statusCode}');
      final body = await res.transform(const SystemEncoding().decoder).join();
      stdout.writeln(body.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').substring(0, body.length > 300 ? 300 : body.length));
    } catch (e) {
      stdout.writeln('PROXY GET failed: $e');
    }
    await r.stop();
    expect(r.state, I2pState.stopped);
    dir.deleteSync(recursive: true);
  }, skip: bin == null ? 'set I2PD_REAL' : null, timeout: const Timeout(Duration(minutes: 8)));
}

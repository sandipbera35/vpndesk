import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oniondesk/torrc.dart';

String golden(String name) => File('test/golden/$name').readAsStringSync();

void main() {
  const geoip = 'GeoIPFile /opt/oniondesk/tor/geoip\nGeoIPv6File /opt/oniondesk/tor/geoip6\n';

  test('pinned exit + guards (golden)', () {
    expect(
        buildTorrc(dataDir: '/home/u/.config/oniondesk', exitNodes: r'$AAAA', geoipLines: geoip, controlLines: '', entryNodes: r'$G1,$G2', ownerPid: 4242),
        golden('torrc_pinned.txt'));
  });

  test('whole-country exit, no guards (golden)', () {
    expect(buildTorrc(dataDir: '/home/u/.config/oniondesk', exitNodes: '{de}', geoipLines: geoip, controlLines: '', entryNodes: '', ownerPid: 4242),
        golden('torrc_country.txt'));
  });

  test('hard constraints are always present', () {
    for (final exit in [r'$AAAA', '{de}', '1.2.3.4']) {
      final t = buildTorrc(dataDir: '/d', exitNodes: exit, geoipLines: '', controlLines: '', entryNodes: '', ownerPid: 1);
      expect(t, contains('StrictNodes 1\n'));
      expect(t, contains('__OwningControllerProcess 1\n'));
      expect(t, contains('ExitNodes $exit\n'));
    }
  });
}

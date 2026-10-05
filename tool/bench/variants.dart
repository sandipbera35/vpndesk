/// Tor configuration variants under test. One entry per experiment (instruction.md Phase 2);
/// `baseline` mirrors what lib/main.dart `_writeTorrc` produces today.
class Ctx {
  final String dataDir, geoip, geoip6;
  final int socksPort, controlPort;
  final List<String> exits; // fingerprints of the top exit relays in the country, best first
  final List<String> guards; // fingerprints of the top guards, best first
  final String country; // lower-case cc
  final int ownerPid;
  Ctx({required this.dataDir, required this.geoip, required this.geoip6, required this.socksPort, required this.controlPort,
      required this.exits, required this.guards, required this.country, required this.ownerPid});
}

const socksFlagsBaseline = 'NoIsolateSOCKSAuth NoIsolateClientAuth NoIsolateClientProtocol NoIsolateDestPort NoIsolateDestAddr';

/// Directives every variant gets (bench plumbing, not part of any experiment).
String _common(Ctx c) => 'DataDirectory ${c.dataDir}\n'
    'GeoIPFile ${c.geoip}\nGeoIPv6File ${c.geoip6}\n'
    'ControlPort 127.0.0.1:${c.controlPort}\nCookieAuthentication 1\n'
    'ClientOnly 1\nLog notice stdout\n__OwningControllerProcess ${c.ownerPid}\n';

String _entry(Ctx c) => c.guards.isEmpty ? '' : 'EntryNodes ${c.guards.take(12).map((f) => '\$$f').join(',')}\n';

typedef Builder = String Function(Ctx c);

final Map<String, Builder> variants = {
  // Current app behaviour: one pinned exit, 12 pinned guards, one shared circuit.
  'baseline': (c) => 'SocksPort ${c.socksPort} $socksFlagsBaseline\n'
      'ExitNodes ${c.exits.isEmpty ? '{${c.country}}' : '\$${c.exits.first}'}\nStrictNodes 1\n'
      '${_entry(c)}MaxCircuitDirtiness 86400\nNewCircuitPeriod 86400\n${_common(c)}',

  // 2.2: pin the top N exits by consensus weight instead of a single relay (StrictNodes stays 1).
  'exitset3': (c) => _withExit(c, _exitList(c, 3)),
  'exitset5': (c) => _withExit(c, _exitList(c, 5)),
  'exitset8': (c) => _withExit(c, _exitList(c, 8)),
  // 2.2: every exit in the country, Tor's own bandwidth weighting.
  'exitcc': (c) => _withExit(c, '{${c.country}}'),

  // 2.3: streams to different destinations get different circuits (baseline: one shared circuit).
  'isolatedest': (c) => 'SocksPort ${c.socksPort} NoIsolateSOCKSAuth NoIsolateClientAuth NoIsolateClientProtocol NoIsolateDestPort IsolateDestAddr\n'
      'ExitNodes ${c.exits.isEmpty ? '{${c.country}}' : '\$${c.exits.first}'}\nStrictNodes 1\n'
      '${_entry(c)}MaxCircuitDirtiness 86400\nNewCircuitPeriod 86400\n${_common(c)}',
  // 2.5: no connection/circuit padding (privacy trade-off, measured only).
  'nopad': (c) => '${variants['baseline']!(c)}ConnectionPadding 0\nCircuitPadding 0\n',
  // 2.6: Tor's own circuit lifetime defaults instead of the app's 86400 s.
  'defaultcirc': (c) => 'SocksPort ${c.socksPort} $socksFlagsBaseline\n'
      'ExitNodes ${c.exits.isEmpty ? '{${c.country}}' : '\$${c.exits.first}'}\nStrictNodes 1\n'
      '${_entry(c)}MaxCircuitDirtiness 600\n${_common(c)}',
  // H1: whole-country exit + re-roll of a slow circuit (policy lives in bench.dart `rerollVariants`).
  'reroll': (c) => _withExit(c, '{${c.country}}'),
};

/// Variants that re-roll a slow circuit (SIGNAL NEWNYM) after bootstrap: probe, and if slower than the threshold ask for a new circuit.
const rerollVariants = {'reroll'};

String _exitList(Ctx c, int n) => c.exits.take(n).map((f) => '\$$f').join(',');

/// Baseline with a different ExitNodes value (everything else identical, so the A/B isolates one change).
String _withExit(Ctx c, String exitNodes) => 'SocksPort ${c.socksPort} $socksFlagsBaseline\n'
    'ExitNodes $exitNodes\nStrictNodes 1\n'
    '${_entry(c)}MaxCircuitDirtiness 86400\nNewCircuitPeriod 86400\n${_common(c)}';

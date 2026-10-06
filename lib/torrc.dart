/// torrc generation for the default (user-level) mode.
///
/// `IsolateDestAddr`: streams to different destination addresses use different circuits. Measured over 20
/// interleaved A/B pairs (docs/bench/DECISIONS.md, 2.3): +4 Mbps aggregate with 4 different destinations, no change
/// for one stream, +0.17 s TTFB for a first request to a new host. System-wide mode (TransPort, oniondesk-net) is unmeasured
/// and unchanged. Pure function so the exact output is pinned by a golden test.
///
/// Hard constraints (instruction.md): `StrictNodes 1` (never silently fall back to another country) and
/// `__OwningControllerProcess` (tor exits when the app dies). Every directive here is validated with
/// `tor --verify-config` by the benchmark harness and must stay in the oniondesk-net allowlist if it is ever
/// used in system-wide mode.
String buildTorrc({
  required String dataDir,
  required String exitNodes,
  required String geoipLines,
  required String controlLines,
  required String entryNodes,
  required int ownerPid,
  int socksPort = 9050, // 9052 when the ad blocker's filter owns 9050
  String bridgeLines = '', // 'UseBridges 1' + transport + Bridge lines from bridges.dart ('' = direct)
}) =>
    'SocksPort $socksPort NoIsolateSOCKSAuth NoIsolateClientAuth NoIsolateClientProtocol NoIsolateDestPort IsolateDestAddr\n'
    'DataDirectory $dataDir/data\nExitNodes $exitNodes\nStrictNodes 1\n'
    '$geoipLines$controlLines'
    '${entryNodes.isEmpty ? '' : 'EntryNodes $entryNodes\n'}'
    '$bridgeLines'
    'MaxCircuitDirtiness 86400\nNewCircuitPeriod 86400\n__OwningControllerProcess $ownerPid\n';

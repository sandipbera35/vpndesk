// Parsing for Tor control-port answers (pure, so it is unit-tested without a running tor).

class Hop {
  const Hop(this.fingerprint, this.nickname);
  final String fingerprint; // 40 hex chars, no '$'
  final String nickname;
}

class Circuit {
  const Circuit(this.id, this.status, this.purpose, this.hops);
  final String id, status, purpose;
  final List<Hop> hops;
}

/// `GETINFO circuit-status` lines: `12 BUILT $FP~nick,$FP~nick,$FP~nick BUILD_FLAGS=... PURPOSE=GENERAL ...`
List<Circuit> parseCircuitStatus(String out) {
  final res = <Circuit>[];
  final line = RegExp(r'^(\d+) (LAUNCHED|BUILT|GUARD_WAIT|EXTENDED|FAILED|CLOSED)(?: (\S+))?(.*)$', multiLine: true);
  for (final m in line.allMatches(out)) {
    final path = m.group(3) ?? '';
    final hops = <Hop>[];
    for (final h in path.split(',')) {
      final hm = RegExp(r'^\$?([0-9A-Fa-f]{40})(?:[~=](\w+))?$').firstMatch(h);
      if (hm != null) hops.add(Hop(hm.group(1)!.toUpperCase(), hm.group(2) ?? ''));
    }
    final purpose = RegExp(r'PURPOSE=(\w+)').firstMatch(m.group(4) ?? '')?.group(1) ?? '';
    res.add(Circuit(m.group(1)!, m.group(2)!, purpose, hops));
  }
  return res;
}

/// The circuit user traffic is most likely on: a built general-purpose 3-hop circuit. Tor numbers circuits upwards,
/// so the newest one is preferred.
Circuit? pickUserCircuit(List<Circuit> all) {
  final ok = all.where((c) => c.status == 'BUILT' && c.purpose == 'GENERAL' && c.hops.length >= 3).toList();
  if (ok.isEmpty) return null;
  ok.sort((a, b) => (int.tryParse(b.id) ?? 0).compareTo(int.tryParse(a.id) ?? 0));
  return ok.first;
}

/// `GETINFO ns/id/<FP>` answer: the `r` line is `r nick id digest date time IP orport dirport`. Returns fingerprint -> IP.
/// The id in the r-line is base64 of the identity digest, so answers are matched to requests by order.
List<String> parseNsIps(String out) => [
      for (final m in RegExp(r'^r \S+ \S+ \S+ \S+ \S+ (\d{1,3}(?:\.\d{1,3}){3}) \d+ \d+', multiLine: true).allMatches(out)) m.group(1)!
    ];

/// `GETINFO ip-to-country/<IP>` answers: `250-ip-to-country/1.2.3.4=de` -> {1.2.3.4: de}.
Map<String, String> parseIpCountry(String out) => {
      for (final m in RegExp(r'ip-to-country/(\d{1,3}(?:\.\d{1,3}){3})=([a-z?]{2})', multiLine: true).allMatches(out)) m.group(1)!: m.group(2)!
    };

class StreamInfo {
  const StreamInfo(this.id, this.status, this.circuitId, this.target);
  final String id, status, circuitId, target; // target = "host:port"
}

/// `GETINFO stream-status` lines: `id STATUS circuitID target[:port] ...` (circuit 0 = not attached yet).
List<StreamInfo> parseStreamStatus(String out) => [
      for (final m in RegExp(r'^(\d+) (NEW|NEWRESOLVE|REMAP|SENTCONNECT|SENTRESOLVE|SUCCEEDED|FAILED|CLOSED|DETACHED) (\d+) (\S+)', multiLine: true).allMatches(out))
        StreamInfo(m.group(1)!, m.group(2)!, m.group(3)!, m.group(4)!)
    ];

/// Hostnames (without port) of the streams riding each circuit, in order, no duplicates. Circuit 0 is dropped.
Map<String, List<String>> targetsByCircuit(List<StreamInfo> streams) {
  final out = <String, List<String>>{};
  for (final s in streams) {
    if (s.circuitId == '0' || s.status == 'CLOSED' || s.status == 'FAILED') continue;
    final host = s.target.replaceFirst(RegExp(r':\d+$'), '');
    final l = out.putIfAbsent(s.circuitId, () => []);
    if (!l.contains(host)) l.add(host);
  }
  return out;
}

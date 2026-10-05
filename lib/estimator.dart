/// Smoothed, time-stamped per-key samples (e.g. measured Mbps per country).
///
/// Each key keeps its recent samples; anything older than [maxAge] is dropped, and the value is an
/// exponentially weighted moving average (newest samples weigh most) so one noisy measurement cannot
/// flip a decision.
class Smoothed {
  final double alpha;
  final Duration maxAge;
  final int keep;
  final Map<String, List<(DateTime, double)>> _s = {};

  Smoothed({this.alpha = 0.4, this.maxAge = const Duration(hours: 1), this.keep = 12});

  void add(String key, double v, DateTime now) {
    final l = _s.putIfAbsent(key, () => []);
    l.add((now, v));
    _prune(l, now);
  }

  void _prune(List<(DateTime, double)> l, DateTime now) {
    l.removeWhere((e) => now.difference(e.$1) > maxAge);
    while (l.length > keep) { l.removeAt(0); }
  }

  /// EWMA of the key's fresh samples, or null if it has none.
  double? value(String key, DateTime now) {
    final l = _s[key];
    if (l == null) return null;
    _prune(l, now);
    if (l.isEmpty) return null;
    var v = l.first.$2;
    for (final e in l.skip(1)) { v = alpha * e.$2 + (1 - alpha) * v; }
    return v;
  }

  bool has(String key, DateTime now) => value(key, now) != null;

  Map<String, Object?> toJson() => {
        for (final e in _s.entries) e.key: [for (final s in e.value) [s.$1.millisecondsSinceEpoch, s.$2]]
      };

  void load(Object? json, DateTime now) {
    if (json is! Map) return;
    for (final e in json.entries) {
      final l = <(DateTime, double)>[];
      for (final s in (e.value as List)) {
        l.add((DateTime.fromMillisecondsSinceEpoch((s[0] as num).toInt()), (s[1] as num).toDouble()));
      }
      _s['${e.key}'] = l;
      _prune(l, now);
    }
  }
}

/// Decides whether auto-fastest should leave [current] for [best].
///
/// The two countries are compared in the SAME domain: smoothed measurements when both have one,
/// otherwise the calibrated estimates of both. A live measurement of the current country is never
/// compared with an estimate for the candidate (that mixes two different scales and biases the switch).
class AutoSwitch {
  final double margin;
  final Duration cooldown;
  AutoSwitch({this.margin = 1.25, this.cooldown = const Duration(minutes: 5)});

  /// Returns the candidate to switch to, or null to stay.
  String? pick({
    required String current,
    required Iterable<String> candidates,
    required double? Function(String) measured,
    required double? Function(String) estimate,
    required DateTime now,
    required DateTime lastSwitch,
    bool force = false,
  }) {
    if (!force && now.difference(lastSwitch) <= cooldown) return null;
    double? score(String c, bool useMeasured) => useMeasured ? measured(c) : estimate(c);
    String? best;
    double bestScore = 0;
    for (final c in candidates) {
      if (c == current) continue;
      final bothMeasured = measured(c) != null && measured(current) != null;
      final a = score(c, bothMeasured), b = score(current, bothMeasured);
      if (a == null || b == null) continue;
      if (a > b * margin && a > bestScore) { best = c; bestScore = a; }
    }
    return best;
  }
}

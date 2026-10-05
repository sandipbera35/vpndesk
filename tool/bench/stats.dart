import 'dart:math';

/// Summary of a list of samples. p90 uses linear interpolation; stddev is the sample standard deviation.
class Stats {
  final int n;
  final double median, p90, stddev, min, max;
  Stats._(this.n, this.median, this.p90, this.stddev, this.min, this.max);

  factory Stats(List<double> xs) {
    if (xs.isEmpty) return Stats._(0, double.nan, double.nan, double.nan, double.nan, double.nan);
    final s = [...xs]..sort();
    final mean = s.reduce((a, b) => a + b) / s.length;
    final sd = s.length < 2 ? 0.0 : sqrt(s.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / (s.length - 1));
    return Stats._(s.length, quantile(s, 0.5), quantile(s, 0.9), sd, s.first, s.last);
  }

  static double quantile(List<double> sorted, double q) {
    if (sorted.length == 1) return sorted.first;
    final pos = (sorted.length - 1) * q;
    final lo = pos.floor(), hi = pos.ceil();
    return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
  }

  Map<String, Object?> toJson() => {'n': n, 'median': _r(median), 'p90': _r(p90), 'stddev': _r(stddev), 'min': _r(min), 'max': _r(max)};
  static double? _r(double v) => v.isNaN ? null : double.parse(v.toStringAsFixed(3));
}

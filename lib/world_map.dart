import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// (latitude, longitude) in degrees.
typedef LatLon = ({double lat, double lon});

class _Country {
  _Country(this.code, this.rings);
  final String code;
  final List<List<Offset>> rings; // x = lon, y = lat
  late final Offset center = _center();
  Offset _center() {
    // Centre of the bounding box of the largest ring.
    var best = rings.first, area = -1.0;
    for (final r in rings) {
      var a = 0.0, minX = 999.0, maxX = -999.0, minY = 999.0, maxY = -999.0;
      for (final p in r) {
        minX = math.min(minX, p.dx); maxX = math.max(maxX, p.dx);
        minY = math.min(minY, p.dy); maxY = math.max(maxY, p.dy);
      }
      a = (maxX - minX) * (maxY - minY);
      if (a > area) { area = a; best = r; }
    }
    final xs = best.map((p) => p.dx), ys = best.map((p) => p.dy);
    return Offset((xs.reduce(math.min) + xs.reduce(math.max)) / 2, (ys.reduce(math.min) + ys.reduce(math.max)) / 2);
  }
}

/// Offline world map: highlights the selected country, pins the real and exit locations
/// with animated pulses, and draws an animated link between them while connected.
class WorldMap extends StatefulWidget {
  const WorldMap({super.key, required this.country, required this.connected, this.real, this.exit, this.realLabel, this.exitLabel, this.height});
  final String country; // lower-case ISO-2
  final bool connected;
  final LatLon? real, exit;
  final String? realLabel, exitLabel; // e.g. '1.2.3.4 · Haldia, India'
  final double? height; // null = fill the parent
  @override
  State<WorldMap> createState() => _WorldMapState();
}

class _WorldMapState extends State<WorldMap> with TickerProviderStateMixin {
  static List<_Country>? _cache;
  List<_Country>? _countries = _cache;
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(seconds: 2));
  late final AnimationController _dropReal = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  late final AnimationController _dropExit = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void initState() {
    super.initState();
    if (_countries == null) {
      rootBundle.loadString('assets/world.json').then((s) {
        _cache = [
          for (final c in jsonDecode(s) as List)
            _Country(c['c'] as String, [
              for (final r in c['r'] as List) [for (final p in r as List) Offset((p[0] as num).toDouble(), (p[1] as num).toDouble())]
            ])
        ];
        if (mounted) setState(() => _countries = _cache);
      });
    }
    if (widget.connected) _loop.repeat();
    if (widget.real != null) _dropReal.forward();
    if (widget.exit != null) _dropExit.forward();
  }

  @override
  void didUpdateWidget(WorldMap old) {
    super.didUpdateWidget(old);
    // Ripples/link animation only matter while connected; an idle ticker would repaint the window forever.
    if (widget.connected && !_loop.isAnimating) {
      _loop.repeat();
    } else if (!widget.connected && _loop.isAnimating) {
      _loop.animateTo(1).whenComplete(() { if (mounted && !widget.connected) _loop.value = 0; });
    }
    if (widget.real != old.real) widget.real == null ? _dropReal.reset() : _dropReal.forward(from: 0);
    if (widget.exit != old.exit) widget.exit == null ? _dropExit.reset() : _dropExit.forward(from: 0);
  }

  @override
  void dispose() {
    _loop.dispose();
    _dropReal.dispose();
    _dropExit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), border: Border.all(color: Colors.white.withValues(alpha: 0.09)), borderRadius: BorderRadius.circular(20)),
          child: Stack(fit: StackFit.expand, children: [
            // Land + grid never animate: paint once per size/selection instead of 60 times a second.
            RepaintBoundary(child: CustomPaint(painter: _MapPainter(base: true, countries: _countries, country: widget.country, connected: widget.connected, t: 0, dropReal: 0, dropExit: 0))),
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([_loop, _dropReal, _dropExit]),
                builder: (_, __) => CustomPaint(
                  painter: _MapPainter(
                    base: false,
                    countries: _countries,
                    country: widget.country,
                    connected: widget.connected,
                    real: widget.real,
                    exit: widget.exit,
                    realLabel: widget.realLabel,
                    exitLabel: widget.exitLabel,
                    t: _loop.value,
                    dropReal: Curves.bounceOut.transform(_dropReal.value),
                    dropExit: Curves.bounceOut.transform(_dropExit.value),
                  ),
                ),
              ),
            ),
          ]),
        ),
      );
}

class _MapPainter extends CustomPainter {
  _MapPainter({required this.base, required this.countries, required this.country, required this.connected, this.real, this.exit, this.realLabel, this.exitLabel, required this.t, required this.dropReal, required this.dropExit});
  final bool base; // true: static land layer, false: highlight/pins/link layer
  final List<_Country>? countries;
  final String country;
  final bool connected;
  final LatLon? real, exit;
  final String? realLabel, exitLabel;
  final double t, dropReal, dropExit;

  static List<_Country>? _pcCountries;
  static Size? _pcSize;
  static List<Path>? _pcPaths;

  /// Projected country outlines, rebuilt only when the map size (or data) changes.
  static List<Path> _pathsFor(List<_Country> cs, Size size, Offset Function(double, double) proj) {
    if (identical(_pcCountries, cs) && _pcSize == size && _pcPaths != null) return _pcPaths!;
    final out = <Path>[];
    for (final c in cs) {
      final path = Path();
      for (final r in c.rings) {
        for (var i = 0; i < r.length; i++) {
          final p = proj(r[i].dx, r[i].dy);
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        path.close();
      }
      out.add(path);
    }
    _pcCountries = cs;
    _pcSize = size;
    return _pcPaths = out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Equirectangular, lat clipped to [-58, 84] to drop empty Antarctica.
    const minLat = -58.0, maxLat = 84.0;
    final scale = math.min(size.width / 360, size.height / (maxLat - minLat));
    final w = 360 * scale, h = (maxLat - minLat) * scale;
    final ox = (size.width - w) / 2, oy = (size.height - h) / 2;
    Offset proj(double lon, double lat) => Offset(ox + (lon + 180) * scale, oy + (maxLat - lat) * scale);

    final cs = countries ?? const <_Country>[];
    final paths = _pathsFor(cs, size, proj);

    if (base) {
      final grid = Paint()..color = const Color(0xFF16233A)..strokeWidth = 0.6;
      for (var lon = -180; lon <= 180; lon += 30) { canvas.drawLine(proj(lon.toDouble(), maxLat), proj(lon.toDouble(), minLat), grid); }
      for (var lat = -60; lat <= 80; lat += 20) { canvas.drawLine(proj(-180, lat.toDouble()), proj(180, lat.toDouble()), grid); }
      final land = Paint()..color = const Color(0xFF3A5278).withValues(alpha: 0.45);
      final edge = Paint()..color = const Color(0xFF6E8DBA).withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 0.5;
      for (var i = 0; i < cs.length; i++) {
        if (cs[i].code == country) continue;
        canvas.drawPath(paths[i], land);
        canvas.drawPath(paths[i], edge);
      }
      return;
    }

    final hi = Paint()..color = (connected ? Colors.tealAccent : Colors.amberAccent).withValues(alpha: 0.35 + 0.2 * math.sin(t * 2 * math.pi));
    final hiEdge = Paint()..color = connected ? Colors.tealAccent : Colors.amberAccent..style = PaintingStyle.stroke..strokeWidth = 1.2;

    Offset? fallback;
    for (var i = 0; i < cs.length; i++) {
      if (cs[i].code != country) continue;
      canvas.drawPath(paths[i], hi);
      canvas.drawPath(paths[i], hiEdge);
      fallback = proj(cs[i].center.dx, cs[i].center.dy);
    }

    final realP = real == null ? null : proj(real!.lon, real!.lat);
    final exitP = exit != null ? proj(exit!.lon, exit!.lat) : (connected ? fallback : null);

    // Animated link real -> exit.
    if (realP != null && exitP != null && connected) {
      final mid = Offset((realP.dx + exitP.dx) / 2, math.min(realP.dy, exitP.dy) - (realP - exitP).distance * 0.25);
      final path = Path()..moveTo(realP.dx, realP.dy)..quadraticBezierTo(mid.dx, mid.dy, exitP.dx, exitP.dy);
      final line = Paint()..color = Colors.tealAccent.withValues(alpha: 0.35)..style = PaintingStyle.stroke..strokeWidth = 1.2;
      for (final m in path.computeMetrics()) {
        for (var d = -t * 14; d < m.length; d += 14) {
          final a = math.max(0.0, d), b = math.min(m.length, d + 7);
          if (b > a) canvas.drawPath(m.extractPath(a, b), line);
        }
        final tan = m.getTangentForOffset(m.length * t);
        if (tan != null) canvas.drawCircle(tan.position, 2.5, Paint()..color = Colors.white);
      }
    }

    if (realP != null) _pin(canvas, realP, Colors.amberAccent, dropReal, t);
    if (exitP != null && connected) _pin(canvas, exitP, Colors.tealAccent, exit != null ? dropExit : 1, (t + 0.5) % 1);
    // Labels last so they sit on top; if the pins are close, stack the second one below.
    final close = realP != null && exitP != null && connected && (realP - exitP).distance < 90;
    if (realP != null && realLabel != null) _label(canvas, size, realP, 'REAL  $realLabel', Colors.amberAccent, false);
    if (exitP != null && connected && exitLabel != null) _label(canvas, size, exitP, 'EXIT  $exitLabel', Colors.tealAccent, close);
  }

  void _label(Canvas canvas, Size size, Offset p, String text, Color color, bool below) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, shadows: [Shadow(color: color, blurRadius: 6), const Shadow(color: Colors.black87, blurRadius: 2)])),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = tp.width + 12, h = tp.height + 6;
    var x = p.dx - w / 2;
    x = x.clamp(4.0, math.max(4.0, size.width - w - 4));
    final y = below ? p.dy + 10 : (p.dy - 34 - h).clamp(4.0, size.height - h - 4);
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(8));
    canvas.drawRRect(r, Paint()..color = const Color(0xFF0B1424).withValues(alpha: 0.45));
    canvas.drawRRect(r, Paint()..color = color.withValues(alpha: 0.8)..style = PaintingStyle.stroke..strokeWidth = 1.2);
    tp.paint(canvas, Offset(x + 6, y + 3));
  }

  void _pin(Canvas canvas, Offset p, Color color, double drop, double phase) {
    // Expanding ripples.
    for (var k = 0; k < 2; k++) {
      final f = (phase + k * 0.5) % 1;
      canvas.drawCircle(p, 4 + 16 * f, Paint()..color = color.withValues(alpha: 0.5 * (1 - f))..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }
    canvas.drawCircle(p, 3, Paint()..color = color.withValues(alpha: 0.9));
    // Teardrop pin that drops in with a bounce.
    final head = p.translate(0, -14 - (1 - drop) * 40);
    final path = Path()
      ..moveTo(p.dx, p.dy - (1 - drop) * 40)
      ..cubicTo(head.dx - 9, head.dy + 3, head.dx - 7, head.dy - 9, head.dx, head.dy - 9)
      ..cubicTo(head.dx + 7, head.dy - 9, head.dx + 9, head.dy + 3, p.dx, p.dy - (1 - drop) * 40)
      ..close();
    canvas.drawShadow(path, Colors.black, 3, true);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawCircle(head.translate(0, -2), 2.6, Paint()..color = const Color(0xFF0B1424));
  }

  @override
  bool shouldRepaint(_MapPainter o) => !base || o.country != country || !identical(o.countries, countries);
}

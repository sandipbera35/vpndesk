import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'l10n.dart' show L10n;

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
  const WorldMap({super.key, required this.country, required this.connected, this.real, this.exit, this.realLabel, this.exitLabel, this.height, this.hops = const [], this.countryNames = const {}});
  final String country; // lower-case ISO-2
  final bool connected;
  final LatLon? real, exit;
  final String? realLabel, exitLabel; // e.g. '1.2.3.4 · Haldia, India'
  final double? height; // null = fill the parent
  /// Relays of the circuit in use, guard first: [cc] is the relay's country (country-level, never a street address).
  final List<({String cc, String nick})> hops;
  /// Lower-case ISO code -> display name, for the guard/middle labels.
  final Map<String, String> countryNames;
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

  // ---- zoom / pan (mouse wheel, drag, pinch, double-click, +/- buttons) ----
  static const _minZoom = 1.0, _maxZoom = 14.0;
  double _zoom = 1;
  Offset _pan = Offset.zero;
  double _gZoom = 1;
  Offset _gPan = Offset.zero, _gFocal = Offset.zero;

  /// Keep the map covering the view: it can be dragged, never off into empty space.
  Offset _clampPan(Offset p, double z, Size s) => Offset(p.dx.clamp(s.width * (1 - z), 0.0).toDouble(), p.dy.clamp(s.height * (1 - z), 0.0).toDouble());

  /// Zoom to [z] keeping the map point under [focal] where it is.
  void _zoomAt(double z, Offset focal, Size s) {
    final nz = z.clamp(_minZoom, _maxZoom).toDouble();
    final k = nz / _zoom;
    setState(() {
      _pan = _clampPan(focal - (focal - _pan) * k, nz, s);
      _zoom = nz;
    });
  }

  void _resetView() => setState(() { _zoom = 1; _pan = Offset.zero; });

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (ctx, box) => _mapBox(box.biggest));

  Widget _mapBox(Size size) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), border: Border.all(color: Colors.white.withValues(alpha: 0.09)), borderRadius: BorderRadius.circular(20)),
          child: Listener(
            onPointerSignal: (e) {
              if (e is PointerScrollEvent) _zoomAt(_zoom * math.exp(-e.scrollDelta.dy / 400), e.localPosition, size);
            },
            child: MouseRegion(
              cursor: _zoom > 1 ? SystemMouseCursors.grab : MouseCursor.defer,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: (d) { _gZoom = _zoom; _gPan = _pan; _gFocal = d.localFocalPoint; },
                onScaleUpdate: (d) {
                  final nz = (_gZoom * d.scale).clamp(_minZoom, _maxZoom).toDouble();
                  // the map point that was under the first touch follows the fingers/cursor (pan) and scales (pinch)
                  setState(() {
                    _pan = _clampPan(d.localFocalPoint - (_gFocal - _gPan) * (nz / _gZoom), nz, size);
                    _zoom = nz;
                  });
                },
                onDoubleTapDown: (d) => _zoomAt(_zoom * 2, d.localPosition, size),
                child: Stack(fit: StackFit.expand, children: [
            // Land + grid never animate: paint once per size/selection instead of 60 times a second.
            RepaintBoundary(child: CustomPaint(painter: _MapPainter(base: true, countries: _countries, country: widget.country, connected: widget.connected, zoom: _zoom, pan: _pan, t: 0, dropReal: 0, dropExit: 0))),
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([_loop, _dropReal, _dropExit]),
                builder: (_, _) => CustomPaint(
                  painter: _MapPainter(
                    base: false,
                    countries: _countries,
                    country: widget.country,
                    connected: widget.connected,
                    real: widget.real,
                    exit: widget.exit,
                    realLabel: widget.realLabel,
                    exitLabel: widget.exitLabel,
                    hops: widget.hops,
                    countryNames: widget.countryNames,
                    zoom: _zoom,
                    pan: _pan,
                    t: _loop.value,
                    dropReal: Curves.bounceOut.transform(_dropReal.value),
                    dropExit: Curves.bounceOut.transform(_dropExit.value),
                  ),
                ),
              ),
            ),
            // zoom controls (top right, under the expand button)
            Positioned(
              right: 12,
              top: 50,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _ZoomButton(icon: Icons.add_rounded, tooltip: 'Zoom in', onTap: () => _zoomAt(_zoom * 1.6, size.center(Offset.zero), size)),
                const SizedBox(height: 6),
                _ZoomButton(icon: Icons.remove_rounded, tooltip: 'Zoom out', onTap: _zoom > 1 ? () => _zoomAt(_zoom / 1.6, size.center(Offset.zero), size) : null),
                if (_zoom > 1) ...[
                  const SizedBox(height: 6),
                  _ZoomButton(icon: Icons.fit_screen_rounded, tooltip: 'Reset view', onTap: _resetView),
                ],
              ]),
            ),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// Small round glass button for the map's zoom controls.
class _ZoomButton extends StatefulWidget {
  const _ZoomButton({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  @override
  State<_ZoomButton> createState() => _ZoomButtonState();
}

class _ZoomButtonState extends State<_ZoomButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final on = widget.onTap != null;
    return Tooltip(
      message: L10n.tr(widget.tooltip),
      child: MouseRegion(
        cursor: on ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0B1424).withValues(alpha: 0.85),
              border: Border.all(color: const Color(0xFF2DE2C4).withValues(alpha: on ? (_hover ? 0.95 : 0.5) : 0.2)),
              boxShadow: [BoxShadow(color: const Color(0xFF2DE2C4).withValues(alpha: on && _hover ? 0.35 : 0), blurRadius: 10)],
            ),
            child: Icon(widget.icon, size: 16, color: on ? const Color(0xFF2DE2C4) : Colors.white24),
          ),
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({required this.base, required this.countries, required this.country, required this.connected, this.real, this.exit, this.realLabel, this.exitLabel, this.hops = const [], this.countryNames = const {}, this.zoom = 1, this.pan = Offset.zero, required this.t, required this.dropReal, required this.dropExit});
  final bool base; // true: static land layer, false: highlight/pins/link layer
  final List<_Country>? countries;
  final String country;
  final bool connected;
  final LatLon? real, exit;
  final String? realLabel, exitLabel;
  final List<({String cc, String nick})> hops;
  final Map<String, String> countryNames;
  final double zoom; // 1 = whole world fits the view
  final Offset pan; // screen offset of the zoomed map
  final double t, dropReal, dropExit;

  Offset _sp(Offset p) => p * zoom + pan; // map coordinates -> screen

  static const Map<String, LatLon> _pointCountries = {
    'sg': (lat: 1.35, lon: 103.82),
    'hk': (lat: 22.32, lon: 114.17),
    'tw': (lat: 23.7, lon: 121.0),
  };

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
      // Land is vector: drawn through the zoom transform (crisp at any zoom), hairlines kept hairlines.
      canvas.save();
      canvas.translate(pan.dx, pan.dy);
      canvas.scale(zoom);
      final grid = Paint()..color = const Color(0xFF16233A)..strokeWidth = 0.6 / zoom;
      for (var lon = -180; lon <= 180; lon += 30) { canvas.drawLine(proj(lon.toDouble(), maxLat), proj(lon.toDouble(), minLat), grid); }
      for (var lat = -60; lat <= 80; lat += 20) { canvas.drawLine(proj(-180, lat.toDouble()), proj(180, lat.toDouble()), grid); }
      final land = Paint()..color = const Color(0xFF3A5278).withValues(alpha: 0.45);
      final edge = Paint()..color = const Color(0xFF6E8DBA).withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 0.5 / zoom;
      for (var i = 0; i < cs.length; i++) {
        if (cs[i].code == country) continue;
        canvas.drawPath(paths[i], land);
        canvas.drawPath(paths[i], edge);
      }
      canvas.restore();
      return;
    }

    final hi = Paint()..color = (connected ? Colors.tealAccent : Colors.amberAccent).withValues(alpha: 0.35 + 0.2 * math.sin(t * 2 * math.pi));
    final hiEdge = Paint()..color = connected ? Colors.tealAccent : Colors.amberAccent..style = PaintingStyle.stroke..strokeWidth = 1.2 / zoom;

    Offset? fallback;
    canvas.save();
    canvas.translate(pan.dx, pan.dy);
    canvas.scale(zoom);
    for (var i = 0; i < cs.length; i++) {
      if (cs[i].code != country) continue;
      canvas.drawPath(paths[i], hi);
      canvas.drawPath(paths[i], hiEdge);
      fallback = proj(cs[i].center.dx, cs[i].center.dy);
    }
    canvas.restore();

    // Countries too small for the bundled outlines (no polygon) still get a pin at a fixed point.
    if (fallback == null) {
      final c = _pointCountries[country];
      if (c != null) fallback = proj(c.lon, c.lat);
    }

    // From here on everything (pins, labels, route) is in screen space: sizes stay constant while the map zooms.
    final realP = real == null ? null : _sp(proj(real!.lon, real!.lat));
    final exitP = exit != null ? _sp(proj(exit!.lon, exit!.lat)) : (connected && fallback != null ? _sp(fallback) : null);

    // Animated link real -> (guard -> middle ->) exit. Relay positions are country centres: tor does not tell us more,
    // and showing less is the safer default.
    if (realP != null && exitP != null && connected) {
      Offset? hopAt(String cc) {
        for (final c in cs) { if (c.code == cc) return _sp(proj(c.center.dx, c.center.dy)); }
        final q = _pointCountries[cc];
        return q == null ? null : _sp(proj(q.lon, q.lat));
      }
      final relays = [for (final h in hops) hopAt(h.cc)];
      final line = Paint()..color = Colors.tealAccent.withValues(alpha: 0.35)..style = PaintingStyle.stroke..strokeWidth = 1.2;
      if (hops.length >= 3 && relays.every((e) => e != null)) {
        // hops = guard, middle, exit; the exit uses the real pin position
        final pts = [realP, relays[0]!, relays[1]!, exitP];
        for (var i = 0; i + 1 < pts.length; i++) { _flow(canvas, pts[i], pts[i + 1], (t + i / 3) % 1, line); }
        for (var i = 0; i < 2; i++) {
          canvas.drawCircle(pts[i + 1], 4.5, Paint()..color = const Color(0xFF0B1424));
          canvas.drawCircle(pts[i + 1], 3.4, Paint()..color = i == 0 ? Colors.amberAccent : Colors.white70);
          final role = L10n.tr(i == 0 ? 'guard' : 'middle');
          final where = countryNames[hops[i].cc] ?? hops[i].cc.toUpperCase();
          // Guard label goes below its dot, middle label above, so two close dots do not cover each other.
          _hopLabel(canvas, size, pts[i + 1], '$role · $where', i == 0 ? Colors.amberAccent : Colors.white70, above: i == 1);
        }
      } else {
        _flow(canvas, realP, exitP, t, line);
      }
    }

    if (realP != null) _pin(canvas, realP, Colors.amberAccent, dropReal, t);
    if (exitP != null && connected) _pin(canvas, exitP, Colors.tealAccent, exit != null ? dropExit : 1, (t + 0.5) % 1);
    // Labels last so they sit on top; if the pins are close, stack the second one below.
    final close = realP != null && exitP != null && connected && (realP - exitP).distance < 90;
    if (realP != null && realLabel != null) _label(canvas, size, realP, '${L10n.tr('REAL')}  $realLabel', Colors.amberAccent, false);
    if (exitP != null && connected && exitLabel != null) _label(canvas, size, exitP, '${L10n.tr('EXIT')}  $exitLabel', Colors.tealAccent, close);
  }

  void _hopLabel(Canvas canvas, Size size, Offset p, String text, Color color, {required bool above}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = tp.width + 12, h = tp.height + 5;
    final x = (p.dx - w / 2).clamp(4.0, math.max(4.0, size.width - w - 4)).toDouble();
    final y = (above ? p.dy - 10 - h : p.dy + 9).clamp(4.0, math.max(4.0, size.height - h - 4)).toDouble();
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(8));
    canvas.drawRRect(r, Paint()..color = const Color(0xFF0B1424).withValues(alpha: 0.78));
    canvas.drawRRect(r, Paint()..color = color.withValues(alpha: 0.85)..style = PaintingStyle.stroke..strokeWidth = 1);
    tp.paint(canvas, Offset(x + 6, y + 2.5));
  }

  /// One arc from [a] to [b] with moving dashes and a travelling dot.
  void _flow(Canvas canvas, Offset a, Offset b, double t, Paint line) {
    final mid = Offset((a.dx + b.dx) / 2, math.min(a.dy, b.dy) - (a - b).distance * 0.25);
    final path = Path()..moveTo(a.dx, a.dy)..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);
    for (final m in path.computeMetrics()) {
      for (var d = -t * 14; d < m.length; d += 14) {
        final s0 = math.max(0.0, d), e0 = math.min(m.length, d + 7);
        if (e0 > s0) canvas.drawPath(m.extractPath(s0, e0), line);
      }
      final tan = m.getTangentForOffset(m.length * t);
      if (tan != null) canvas.drawCircle(tan.position, 2.5, Paint()..color = Colors.white);
    }
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
  bool shouldRepaint(_MapPainter o) => !base || o.country != country || !identical(o.countries, countries) || o.zoom != zoom || o.pan != pan;
}

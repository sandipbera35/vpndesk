import 'dart:math' as math;

import 'package:flutter/material.dart';

const _teal = Color(0xFF2DE2C4), _violet = Color(0xFF7C9CFF);

/// A progress ring around the status orb while Tor builds its circuit, with a short burst when it completes.
/// The spinning ticker runs only while connecting and the burst only once, so an idle or connected window costs nothing.
class ConnectRing extends StatefulWidget {
  const ConnectRing({super.key, required this.connecting, required this.running, required this.progress, required this.child, this.size = 64});
  final bool connecting, running;
  final double progress; // 0..1 (Tor's "Bootstrapped N%")
  final Widget child; // the orb in the middle
  final double size;
  @override
  State<ConnectRing> createState() => _ConnectRingState();
}

class _ConnectRingState extends State<ConnectRing> with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  late final AnimationController _burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    if (widget.connecting) _spin.repeat();
    _burst.addStatusListener((_) { if (mounted) setState(() {}); });
  }

  @override
  void didUpdateWidget(ConnectRing old) {
    super.didUpdateWidget(old);
    if (widget.connecting && !_spin.isAnimating) _spin.repeat();
    if (!widget.connecting && _spin.isAnimating) _spin.stop();
    // connecting -> connected: play the completion effect once
    if (old.connecting && !widget.connecting && widget.running) _burst.forward(from: 0);
    // a failed/cancelled attempt must not leave a half effect behind
    if (!widget.running && !widget.connecting && _burst.isAnimating) _burst.stop();
  }

  @override
  void dispose() {
    _spin.dispose();
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bursting = _burst.isAnimating;
    final show = widget.connecting || bursting;
    final target = widget.running ? 1.0 : widget.progress.clamp(0.0, 1.0);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
        if (show)
          Positioned.fill(
            child: IgnorePointer(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: target),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                builder: (_, p, _) => AnimatedBuilder(
                  animation: Listenable.merge([_spin, _burst]),
                  builder: (_, _) => CustomPaint(
                    painter: _RingPainter(progress: p, spin: widget.connecting ? _spin.value : 0, burst: bursting ? _burst.value : 0, connecting: widget.connecting),
                  ),
                ),
              ),
            ),
          ),
        widget.child,
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.spin, required this.burst, required this.connecting});
  final double progress, spin, burst;
  final bool connecting;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 1.5;
    final rect = Rect.fromCircle(center: c, radius: r);
    const start = -math.pi / 2;

    // faint track
    canvas.drawCircle(c, r, Paint()..color = Colors.white.withValues(alpha: 0.09)..style = PaintingStyle.stroke..strokeWidth = 3.5);

    final sweep = 2 * math.pi * progress;
    if (sweep > 0.01) {
      final shader = SweepGradient(startAngle: 0, endAngle: 2 * math.pi, colors: const [_teal, _violet, _teal], transform: const GradientRotation(start)).createShader(rect);
      // glow under the arc, then the arc itself
      canvas.drawArc(rect, start, sweep, false, Paint()..shader = shader..style = PaintingStyle.stroke..strokeWidth = 7..strokeCap = StrokeCap.round..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)..color = _teal.withValues(alpha: 0.5));
      canvas.drawArc(rect, start, sweep, false, Paint()..shader = shader..style = PaintingStyle.stroke..strokeWidth = 3.5..strokeCap = StrokeCap.round);
      // bright head
      final a = start + sweep;
      final head = c + Offset(math.cos(a), math.sin(a)) * r;
      canvas.drawCircle(head, 5, Paint()..color = Colors.white.withValues(alpha: 0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawCircle(head, 2.4, Paint()..color = Colors.white);
    }

    // a comet circling the ring keeps it alive even when Tor sits on one percentage for a while
    if (connecting) {
      final a0 = start + spin * 2 * math.pi;
      canvas.drawArc(rect, a0, 0.55, false, Paint()..color = Colors.white.withValues(alpha: 0.28)..style = PaintingStyle.stroke..strokeWidth = 2.2..strokeCap = StrokeCap.round);
    }

    if (burst > 0) _paintBurst(canvas, c, r);
  }

  void _paintBurst(Canvas canvas, Offset c, double r) {
    final e = Curves.easeOutCubic.transform(burst);
    final fade = (1 - burst).clamp(0.0, 1.0);
    // soft flash
    canvas.drawCircle(c, r + 4, Paint()..color = _teal.withValues(alpha: 0.22 * fade)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    // expanding shock ring
    canvas.drawCircle(c, r + 26 * e, Paint()..color = _teal.withValues(alpha: 0.85 * fade)..style = PaintingStyle.stroke..strokeWidth = 3.2 * fade + 0.4);
    // sparks flying outwards
    for (var i = 0; i < 14; i++) {
      final ang = i * 2 * math.pi / 14 + 0.3;
      final d = r + 4 + (10 + (i.isEven ? 22 : 14)) * e;
      final p = c + Offset(math.cos(ang), math.sin(ang)) * d;
      canvas.drawCircle(p, (i.isEven ? 2.6 : 1.8) * fade + 0.2, Paint()..color = (i % 3 == 0 ? _violet : _teal).withValues(alpha: fade));
    }
    // a check mark drawing itself, then fading
    final t = (burst / 0.45).clamp(0.0, 1.0);
    final alpha = burst < 0.6 ? 1.0 : (1 - (burst - 0.6) / 0.4).clamp(0.0, 1.0);
    final p1 = c + const Offset(-9, 1), p2 = c + const Offset(-3, 7), p3 = c + const Offset(10, -7);
    final path = Path()..moveTo(p1.dx, p1.dy);
    if (t < 0.5) {
      final k = t / 0.5;
      path.lineTo(p1.dx + (p2.dx - p1.dx) * k, p1.dy + (p2.dy - p1.dy) * k);
    } else {
      final k = (t - 0.5) / 0.5;
      path..lineTo(p2.dx, p2.dy)..lineTo(p2.dx + (p3.dx - p2.dx) * k, p2.dy + (p3.dy - p2.dy) * k);
    }
    canvas.drawPath(path, Paint()..color = const Color(0xFF07101F).withValues(alpha: alpha)..style = PaintingStyle.stroke..strokeWidth = 3.4..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.progress != progress || o.spin != spin || o.burst != burst || o.connecting != connecting;
}

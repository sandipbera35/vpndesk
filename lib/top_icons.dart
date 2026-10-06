import 'dart:async';
import 'dart:math' as math;

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart' hide Text;
import 'l10n.dart';

const _teal = Color(0xFF2DE2C4), _violet = Color(0xFF7C9CFF);

/// Round glass button for the title bar. Animates only while hovered/pressed (plus one short intro), so an idle window
/// costs nothing (no always-on ticker).
class _GlassIcon extends StatefulWidget {
  const _GlassIcon({required this.tooltip, required this.onTap, required this.child, this.ring = false, this.intro = false});
  final String tooltip;
  final VoidCallback onTap;
  final Widget Function(bool hover, double t) child; // t: 0..1 animation phase
  final bool ring, intro;
  @override
  State<_GlassIcon> createState() => _GlassIconState();
}

class _GlassIconState extends State<_GlassIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  bool _hover = false, _down = false;
  Timer? _introTimer;

  @override
  void initState() {
    super.initState();
    if (widget.intro) {
      _c.repeat();
      _introTimer = Timer(const Duration(milliseconds: 2600), () { if (mounted && !_hover) _c.stop(); });
    }
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _hoverChanged(bool h) {
    setState(() => _hover = h);
    if (h) {
      _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  Widget build(BuildContext context) => Tooltip(
        message: L10n.tr(widget.tooltip),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => _hoverChanged(true),
          onExit: (_) => _hoverChanged(false),
          child: GestureDetector(
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _down = true),
            onTapUp: (_) => setState(() => _down = false),
            onTapCancel: () => setState(() => _down = false),
            child: AnimatedScale(
              scale: _down ? 0.9 : (_hover ? 1.12 : 1),
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: _hover ? 0.12 : 0.06),
                  boxShadow: [BoxShadow(color: _teal.withValues(alpha: _hover ? 0.45 : 0.0), blurRadius: _hover ? 16 : 0)],
                ),
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (_, _) => Stack(alignment: Alignment.center, children: [
                    if (widget.ring) CustomPaint(size: const Size(30, 30), painter: _RingPainter(_c.value, _hover || _c.isAnimating)),
                    widget.child(_hover, _c.value),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Thin sweep-gradient ring that turns while the button is active.
class _RingPainter extends CustomPainter {
  _RingPainter(this.t, this.active);
  final double t;
  final bool active;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shader = SweepGradient(
      colors: const [_teal, _violet, Color(0x002DE2C4), _teal],
      stops: const [0, 0.35, 0.7, 1],
      transform: GradientRotation(t * 2 * math.pi),
    ).createShader(rect);
    canvas.drawCircle(size.center(Offset.zero), size.width / 2 - 1.2, Paint()..shader = shader..style = PaintingStyle.stroke..strokeWidth = active ? 1.9 : 1.2);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.t != t || o.active != active;
}

/// About: the app icon inside a turning gradient ring.
class AboutIconButton extends StatelessWidget {
  const AboutIconButton({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _GlassIcon(
        tooltip: 'About OnionDesk',
        onTap: onTap,
        ring: true,
        intro: true,
        child: (hover, t) => ClipOval(
          child: Image.asset('assets/icon.png', width: 19, height: 19, filterQuality: FilterQuality.medium),
        ),
      );
}

/// Settings: a gear that turns a quarter when hovered.
class SettingsIconButton extends StatelessWidget {
  const SettingsIconButton({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _GlassIcon(
        tooltip: 'Settings',
        onTap: onTap,
        child: (hover, t) => AnimatedRotation(
          turns: hover ? 0.25 : 0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          child: Icon(Icons.settings_rounded, size: 16, color: hover ? _teal : Colors.white70),
        ),
      );
}


/// Makes a header area drag the window (and double-tap maximise), like the home page's title bar. Buttons inside
/// still receive their own taps.
class DragBar extends StatelessWidget {
  const DragBar({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => appWindow.startDragging(),
        onDoubleTap: () => appWindow.maximizeOrRestore(),
        child: child,
      );
}

/// "New identity": a gradient pill whose icon spins while a fresh relay is being set up. Animates only while busy or
/// hovered.
class NewIdentityButton extends StatefulWidget {
  const NewIdentityButton({super.key, required this.onTap, required this.busy, required this.tooltip});
  final VoidCallback? onTap; // null = disabled
  final bool busy;
  final String tooltip;
  @override
  State<NewIdentityButton> createState() => _NewIdentityButtonState();
}

class _NewIdentityButtonState extends State<NewIdentityButton> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  bool _hover = false, _down = false;

  @override
  void initState() {
    super.initState();
    if (widget.busy) _spin.repeat();
  }

  @override
  void didUpdateWidget(NewIdentityButton old) {
    super.didUpdateWidget(old);
    if (widget.busy && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.busy && _spin.isAnimating) {
      _spin.animateTo(1).whenComplete(() { if (mounted && !widget.busy) _spin.value = 0; }); // finish the turn smoothly
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null && !widget.busy;
    final lit = enabled && _hover;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() { _hover = false; _down = false; }),
        child: GestureDetector(
          onTap: enabled ? widget.onTap : null,
          onTapDown: (_) => setState(() => _down = enabled),
          onTapUp: (_) => setState(() => _down = false),
          onTapCancel: () => setState(() => _down = false),
          child: AnimatedScale(
            scale: _down ? 0.94 : (lit ? 1.04 : 1),
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: widget.onTap == null ? 0.5 : 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(colors: [
                    _teal.withValues(alpha: lit || widget.busy ? 0.34 : 0.2),
                    _violet.withValues(alpha: lit || widget.busy ? 0.34 : 0.2),
                  ]),
                  border: Border.all(color: _teal.withValues(alpha: lit || widget.busy ? 0.95 : 0.55)),
                  boxShadow: [BoxShadow(color: _teal.withValues(alpha: lit || widget.busy ? 0.4 : 0), blurRadius: 14)],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  RotationTransition(turns: _spin, child: const Icon(Icons.fingerprint_rounded, size: 15, color: _teal)),
                  const SizedBox(width: 6),
                  const Text('New identity', maxLines: 1, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


/// Expand / restore the map (corner button). Animates only while hovered.
class MapExpandButton extends StatefulWidget {
  const MapExpandButton({super.key, required this.expanded, required this.onTap});
  final bool expanded;
  final VoidCallback onTap;
  @override
  State<MapExpandButton> createState() => _MapExpandButtonState();
}

class _MapExpandButtonState extends State<MapExpandButton> {
  bool _hover = false, _down = false;
  @override
  Widget build(BuildContext context) => Tooltip(
        message: L10n.tr(widget.expanded ? 'Restore the map (Esc)' : 'Expand the map'),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() { _hover = false; _down = false; }),
          child: GestureDetector(
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _down = true),
            onTapUp: (_) => setState(() => _down = false),
            onTapCancel: () => setState(() => _down = false),
            child: AnimatedScale(
              scale: _down ? 0.9 : (_hover ? 1.1 : 1),
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0B1424).withValues(alpha: 0.85),
                  border: Border.all(color: _teal.withValues(alpha: _hover ? 0.95 : 0.5)),
                  boxShadow: [BoxShadow(color: _teal.withValues(alpha: _hover ? 0.4 : 0), blurRadius: 12)],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: RotationTransition(turns: Tween(begin: 0.25, end: 0.0).animate(a), child: c)),
                  child: Icon(widget.expanded ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded, key: ValueKey(widget.expanded), size: 15, color: _teal),
                ),
              ),
            ),
          ),
        ),
      );
}

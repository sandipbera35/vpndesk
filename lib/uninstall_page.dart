import 'dart:async';
import 'dart:math' as math;

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';

import 'uninstall.dart';

const _teal = Color(0xFF2DE2C4), _violet = Color(0xFF7C9CFF), _coral = Color(0xFFFF6B6B), _amber = Color(0xFFFFC857);

/// "Are you sure?" dialog. Returns whether to also delete the user's data, or null if cancelled.
Future<bool?> showUninstallConfirm(BuildContext context, {required UninstallPlan Function(bool deleteData) planFor, bool dryRun = false}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cancel',
    barrierColor: Colors.black.withValues(alpha: 0.62),
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (ctx, _, _) => _ConfirmDialog(planFor: planFor, dryRun: dryRun),
    transitionBuilder: (ctx, anim, _, child) {
      final c = CurvedAnimation(parent: anim, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(c), child: child),
      );
    },
  );
}

class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({required this.planFor, required this.dryRun});
  final UninstallPlan Function(bool) planFor;
  final bool dryRun;
  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  bool _deleteData = true;

  @override
  Widget build(BuildContext context) {
    final plan = widget.planFor(_deleteData);
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 480,
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: const Color(0xFF0E1830),
            border: Border.all(color: _coral.withValues(alpha: 0.35)),
            boxShadow: [BoxShadow(color: _coral.withValues(alpha: 0.18), blurRadius: 48, spreadRadius: 2)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _coral.withValues(alpha: 0.14),
                      border: Border.all(color: _coral.withValues(alpha: 0.5)),
                    ),
                    child: const Icon(Icons.delete_sweep_rounded, color: _coral),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text('Uninstall VPN Desk?', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                widget.dryRun ? 'Preview mode: nothing will actually be removed.' : 'This will completely remove VPN Desk from this computer:',
                style: TextStyle(color: widget.dryRun ? _amber : Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 10),
              for (final line in plan.willRemove)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.remove_circle_outline_rounded, size: 16, color: _coral),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(line, style: const TextStyle(color: Colors.white, height: 1.35, fontSize: 13.5)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 2),
              Text(plan.leavesBehind, style: const TextStyle(color: Colors.white54, fontSize: 12.5, height: 1.4)),
              const SizedBox(height: 14),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _deleteData = !_deleteData),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(7),
                          color: _deleteData ? _coral : Colors.transparent,
                          border: Border.all(color: _deleteData ? _coral : Colors.white38, width: 1.6),
                        ),
                        child: AnimatedOpacity(
                          opacity: _deleteData ? 1 : 0,
                          duration: const Duration(milliseconds: 160),
                          child: const Icon(Icons.check_rounded, size: 16, color: Color(0xFF07101F)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Also delete my settings and saved data', style: TextStyle(fontSize: 13.5))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context, _deleteData),
                    style: FilledButton.styleFrom(backgroundColor: _coral, foregroundColor: const Color(0xFF07101F), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                    icon: const Icon(Icons.delete_forever_rounded, size: 19),
                    label: Text(widget.dryRun ? 'Preview' : 'Uninstall', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen page that cannot be dismissed while the uninstall is running.
Route<void> uninstallRoute({required UninstallPlan plan, required Stream<UninstallEvent> Function() start, required VoidCallback onBack, required VoidCallback onExit, bool dryRun = false}) =>
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (_, _, _) => UninstallPage(plan: plan, start: start, onBack: onBack, onExit: onExit, dryRun: dryRun),
      transitionsBuilder: (_, anim, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: child,
      ),
    );

class UninstallPage extends StatefulWidget {
  const UninstallPage({super.key, required this.plan, required this.start, required this.onBack, required this.onExit, this.dryRun = false, this.closeAfter = const Duration(seconds: 5)});
  final UninstallPlan plan;
  final Stream<UninstallEvent> Function() start;
  final VoidCallback onBack, onExit;
  final bool dryRun;
  final Duration closeAfter;
  @override
  State<UninstallPage> createState() => _UninstallPageState();
}

enum _Phase { running, done, failed }

class _UninstallPageState extends State<UninstallPage> with TickerProviderStateMixin {
  late final AnimationController _ambient = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat();
  late final AnimationController _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..forward();
  late final AnimationController _prog = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
  late final AnimationController _done = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

  late Map<String, UStepState> _state;
  late List<UStep> _steps;
  _Phase _phase = _Phase.running;
  String? _error;
  bool _cancelled = false;
  double _from = 0, _to = 0;
  StreamSubscription<UninstallEvent>? _sub;
  Timer? _countdown;
  int _left = 0;

  @override
  void initState() {
    super.initState();
    _steps = widget.plan.steps;
    _begin();
  }

  void _begin() {
    _state = {for (final s in _steps) s.id: UStepState.pending};
    _phase = _Phase.running;
    _error = null;
    _cancelled = false;
    _setTarget(0, instant: true);
    _done.value = 0;
    _sub?.cancel();
    _sub = widget.start().listen(_onEvent, onError: (Object e) => _fail('Unexpected error: $e'));
  }

  void _setTarget(double v, {bool instant = false}) {
    _from = instant ? v : _currentProgress;
    _to = v;
    if (instant) {
      _prog.value = 1;
    } else {
      _prog.forward(from: 0);
    }
  }

  double get _currentProgress => _from + (_to - _from) * Curves.easeOutCubic.transform(_prog.value);

  double _target() {
    var done = 0.0;
    for (final s in _steps) {
      final st = _state[s.id];
      if (st == UStepState.done) done += 1;
      if (st == UStepState.running) done += 0.5;
    }
    return _steps.isEmpty ? 1 : done / _steps.length;
  }

  void _onEvent(UninstallEvent e) {
    if (!mounted) return;
    if (e.finished) {
      setState(() {
        for (final s in _steps) {
          _state[s.id] = UStepState.done;
        }
        _phase = _Phase.done;
        _setTarget(1);
      });
      _done.forward(from: 0);
      _startCountdown();
      return;
    }
    if (e.state == UStepState.failed) {
      _fail(e.error ?? 'Something went wrong.', step: e.stepId, cancelled: e.cancelled);
      return;
    }
    setState(() {
      if (e.stepId != null && _state.containsKey(e.stepId)) _state[e.stepId!] = e.state!;
      _setTarget(_target());
    });
  }

  void _fail(String message, {String? step, bool cancelled = false}) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.failed;
      _error = message;
      _cancelled = cancelled;
      if (step != null && _state.containsKey(step)) _state[step] = UStepState.failed;
    });
    _shake.forward(from: 0);
  }

  void _startCountdown() {
    if (widget.dryRun) return;
    _left = widget.closeAfter.inSeconds;
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _left--);
      if (_left <= 0) {
        t.cancel();
        widget.onExit();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _countdown?.cancel();
    _ambient.dispose();
    _in.dispose();
    _prog.dispose();
    _done.dispose();
    _shake.dispose();
    super.dispose();
  }

  Widget _stagger(int i, Widget child) {
    final start = (0.1 * i).clamp(0.0, 0.7);
    final a = CurvedAnimation(
      parent: _in,
      curve: Interval(start, (start + 0.4).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.14), end: Offset.zero).animate(a),
        child: child,
      ),
    );
  }

  String get _title => switch (_phase) {
    _Phase.running => 'Uninstalling VPN Desk',
    _Phase.done => widget.dryRun ? 'Preview finished' : 'VPN Desk has been uninstalled',
    _Phase.failed => _cancelled ? 'Uninstall cancelled' : 'Uninstall stopped',
  };

  String get _subtitle {
    switch (_phase) {
      case _Phase.running:
        final run = _steps.where((s) => _state[s.id] == UStepState.running);
        return run.isEmpty ? 'Getting ready…' : run.first.label;
      case _Phase.done:
        return widget.dryRun ? 'Nothing was removed. This was only a preview.' : 'Everything was removed from this computer. Thank you for trying it.';
      case _Phase.failed:
        return _error ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final failed = _phase == _Phase.failed, ok = _phase == _Phase.done;
    final accent = failed ? _coral : (ok ? _teal : _violet);
    return PopScope(
      canPop: _phase != _Phase.running,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF070D1A), Color(0xFF0E1830), Color(0xFF070D1A)]),
          ),
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _ambient,
                builder: (_, _) => Stack(
                  children: [
                    _blob(Alignment(-1 + 0.5 * math.sin(_ambient.value * 2 * math.pi), -1), accent, 560),
                    _blob(Alignment(1, 1 - 0.5 * math.cos(_ambient.value * 2 * math.pi)), const Color(0xFF7C5CFF), 600),
                  ],
                ),
              ),
              Column(
                children: [
                  SizedBox(height: 40, child: MoveWindow()),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        // The hero gets whatever height is left after the text and step list; scrolls if the window is tiny.
                        final heroSize = (box.maxHeight - 380).clamp(150.0, 220.0);
                        return Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _stagger(0, _hero(accent, heroSize)),
                                  const SizedBox(height: 14),
                                  _stagger(
                                    1,
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 420),
                                      transitionBuilder: (c, a) => FadeTransition(
                                        opacity: a,
                                        child: SlideTransition(
                                          position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(a),
                                          child: c,
                                        ),
                                      ),
                                      child: Text(
                                        _title,
                                        key: ValueKey(_title),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 0.2),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _stagger(
                                    2,
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 300),
                                      child: Text(
                                        _subtitle,
                                        key: ValueKey('$_phase$_subtitle'),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: failed ? _coral : Colors.white60, fontSize: 14, height: 1.4),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _stagger(3, _bar(accent)),
                                  const SizedBox(height: 12),
                                  _stagger(4, _stepList()),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Pinned outside the scroll area so the action buttons are always reachable, whatever the message length.
                  Padding(padding: const EdgeInsets.only(top: 6, bottom: 20), child: _footer()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blob(Alignment a, Color c, double size) => Align(
    alignment: a,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [c.withValues(alpha: 0.18), c.withValues(alpha: 0)]),
      ),
    ),
  );

  Widget _hero(Color accent, double size) => SizedBox(
    width: size,
    height: size,
    child: AnimatedBuilder(
      animation: Listenable.merge([_ambient, _prog, _done, _shake]),
      builder: (_, _) => CustomPaint(
        painter: _HeroPainter(
          progress: _currentProgress,
          ambient: _ambient.value,
          done: Curves.easeOutCubic.transform(_done.value),
          failed: _phase == _Phase.failed,
          shake: _shake.value,
          accent: accent,
        ),
      ),
    ),
  );

  Widget _bar(Color accent) => AnimatedBuilder(
    animation: Listenable.merge([_prog, _ambient]),
    builder: (_, _) {
      final p = _currentProgress.clamp(0.0, 1.0);
      return Column(
        children: [
          Container(
            height: 8,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.white.withValues(alpha: 0.08)),
            child: LayoutBuilder(
              builder: (_, c) {
                final w = c.maxWidth * p;
                return Stack(
                  children: [
                    Container(
                      width: w,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(colors: [accent, Color.lerp(accent, Colors.white, 0.35)!]),
                      ),
                    ),
                    if (_phase == _Phase.running && w > 12)
                      Positioned(
                        left: (w + 80) * _ambient.value * 3 % (w + 80) - 80,
                        width: 80,
                        top: 0,
                        bottom: 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0)])),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(p * 100).round()}%',
              style: const TextStyle(color: Colors.white38, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
        ],
      );
    },
  );

  Widget _stepList() => Column(
    children: [for (var i = 0; i < _steps.length; i++) _StepRow(label: _steps[i].label, state: _state[_steps[i].id] ?? UStepState.pending, ambient: _ambient)],
  );

  Widget _footer() {
    switch (_phase) {
      case _Phase.running:
        return const Text('Please keep this window open.', style: TextStyle(color: Colors.white38, fontSize: 12.5));
      case _Phase.done:
        return AnimatedBuilder(
          animation: _done,
          builder: (_, _) => Opacity(
            opacity: Curves.easeIn.transform(((_done.value - 0.5) * 2).clamp(0.0, 1.0)),
            child: widget.dryRun
                ? FilledButton(
                    onPressed: widget.onBack,
                    style: FilledButton.styleFrom(backgroundColor: _teal, foregroundColor: const Color(0xFF07101F)),
                    child: const Text('Back to VPN Desk'),
                  )
                : Text('Closing in ${_left.clamp(0, 99)}…', style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ),
        );
      case _Phase.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(onPressed: widget.onBack, child: Text(_cancelled ? 'Back to VPN Desk' : 'Close')),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () => setState(_begin),
              style: FilledButton.styleFrom(backgroundColor: _coral, foregroundColor: const Color(0xFF07101F)),
              child: const Text('Try again'),
            ),
          ],
        );
    }
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.state, required this.ambient});
  final String label;
  final UStepState state;
  final Animation<double> ambient;

  @override
  Widget build(BuildContext context) {
    final active = state == UStepState.running;
    final color = switch (state) {
      UStepState.done => _teal,
      UStepState.running => Colors.white,
      UStepState.failed => _coral,
      UStepState.pending => Colors.white38,
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: active ? Colors.white.withValues(alpha: 0.07) : Colors.white.withValues(alpha: 0.025),
        border: Border.all(color: active ? _violet.withValues(alpha: 0.55) : (state == UStepState.failed ? _coral.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.06))),
        boxShadow: active ? [BoxShadow(color: _violet.withValues(alpha: 0.22), blurRadius: 18)] : const [],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: TweenAnimationBuilder<double>(
              key: ValueKey(state),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutCubic,
              builder: (_, t, _) => AnimatedBuilder(
                animation: ambient,
                builder: (_, _) => CustomPaint(painter: _StepIconPainter(state, t, ambient.value)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              // derive from the ambient style so the app's font is kept
              style: DefaultTextStyle.of(context).style.copyWith(color: color, fontSize: 14, fontWeight: active ? FontWeight.w700 : FontWeight.w500),
              child: Text(label),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIconPainter extends CustomPainter {
  _StepIconPainter(this.state, this.t, this.spin);
  final UStepState state;
  final double t, spin;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), r = size.width / 2 - 1.5;
    switch (state) {
      case UStepState.pending:
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = Colors.white24,
        );
      case UStepState.running:
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = Colors.white12,
        );
        final rect = Rect.fromCircle(center: c, radius: r);
        canvas.drawArc(
          rect,
          spin * 2 * math.pi * 5,
          math.pi * 1.2,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round
            ..color = _violet,
        );
      case UStepState.done:
        canvas.drawCircle(c, r * (0.4 + 0.6 * t), Paint()..color = _teal.withValues(alpha: 0.18 + 0.82 * t));
        _check(canvas, c, r, t, const Color(0xFF07101F));
      case UStepState.failed:
        canvas.drawCircle(c, r, Paint()..color = _coral);
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF07101F);
        canvas.drawLine(c + Offset(-r * .38, -r * .38), c + Offset(r * .38, r * .38), p);
        canvas.drawLine(c + Offset(r * .38, -r * .38), c + Offset(-r * .38, r * .38), p);
    }
  }

  static void _check(Canvas canvas, Offset c, double r, double t, Color color) {
    final path = Path()
      ..moveTo(c.dx - r * .42, c.dy + r * .02)
      ..lineTo(c.dx - r * .1, c.dy + r * .34)
      ..lineTo(c.dx + r * .46, c.dy - r * .3);
    final m = path.computeMetrics().first;
    canvas.drawPath(
      m.extractPath(0, m.length * t.clamp(0.0, 1.0)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_StepIconPainter old) => old.state != state || old.t != t || (state == UStepState.running && old.spin != spin);
}

/// The hero graphic: a shield that dissolves into particles as the progress ring fills, then a check mark.
class _HeroPainter extends CustomPainter {
  _HeroPainter({required this.progress, required this.ambient, required this.done, required this.failed, required this.shake, required this.accent});
  final double progress, ambient, done, shake;
  final bool failed;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    var c = size.center(Offset.zero);
    if (failed) c += Offset(math.sin(shake * math.pi * 7) * 9 * (1 - shake), 0);
    final R = size.width / 2 - 12;

    // soft glow behind everything
    canvas.drawCircle(
      c,
      R * 1.25,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: 0.30 + 0.15 * done),
            accent.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: R * 1.25)),
    );

    // track + progress arc
    final ring = Rect.fromCircle(center: c, radius: R);
    canvas.drawCircle(
      c,
      R,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..color = Colors.white.withValues(alpha: 0.07),
    );
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    if (sweep > 0.001) {
      canvas.drawArc(
        ring,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: 0,
            endAngle: 2 * math.pi,
            colors: [accent, Color.lerp(accent, Colors.white, 0.5)!, accent],
            transform: const GradientRotation(-math.pi / 2),
          ).createShader(ring),
      );
    }

    // expanding completion pulse
    if (done > 0 && done < 1) {
      canvas.drawCircle(
        c,
        R * (1 + 0.45 * done),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = accent.withValues(alpha: 0.6 * (1 - done)),
      );
    }

    // dissolving shield
    final shieldAlpha = (failed ? 1.0 : (1 - 0.92 * progress)) * (1 - done);
    if (shieldAlpha > 0.02) {
      final s = R * 0.62;
      final path = Path()
        ..moveTo(c.dx, c.dy - s)
        ..cubicTo(c.dx + s * 0.55, c.dy - s * 0.82, c.dx + s * 0.9, c.dy - s * 0.78, c.dx + s * 0.9, c.dy - s * 0.72)
        ..cubicTo(c.dx + s * 0.9, c.dy + s * 0.2, c.dx + s * 0.55, c.dy + s * 0.72, c.dx, c.dy + s)
        ..cubicTo(c.dx - s * 0.55, c.dy + s * 0.72, c.dx - s * 0.9, c.dy + s * 0.2, c.dx - s * 0.9, c.dy - s * 0.72)
        ..cubicTo(c.dx - s * 0.9, c.dy - s * 0.78, c.dx - s * 0.55, c.dy - s * 0.82, c.dx, c.dy - s)
        ..close();
      final bounds = Rect.fromCircle(center: c, radius: s);
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.55 * shieldAlpha),
              const Color(0xFF7C5CFF).withValues(alpha: 0.35 * shieldAlpha),
            ],
          ).createShader(bounds),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = Colors.white.withValues(alpha: 0.55 * shieldAlpha),
      );
      if (failed) {
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.9);
        canvas.drawLine(c + Offset(0, -s * .38), c + Offset(0, s * .12), p);
        canvas.drawCircle(c + Offset(0, s * .42), 2.6, Paint()..color = Colors.white.withValues(alpha: 0.9));
      }
    }

    // particles drifting out of the shield; denser and brighter as the uninstall advances
    if (!failed) {
      final intensity = (0.2 + 0.8 * progress) * (1 - done);
      for (var i = 0; i < 46; i++) {
        final h = _hash(i);
        final ang = h * 2 * math.pi;
        final t = (ambient * (0.8 + 0.6 * _hash(i + 100)) + _hash(i + 200)) % 1.0;
        final dist = R * (0.18 + 0.78 * t);
        final a = math.sin(math.pi * t) * intensity * (0.35 + 0.65 * _hash(i + 300));
        if (a < 0.02) continue;
        canvas.drawCircle(c + Offset(math.cos(ang), math.sin(ang)) * dist, 1.3 + 2.2 * _hash(i + 400), Paint()..color = Color.lerp(accent, Colors.white, _hash(i + 500) * .6)!.withValues(alpha: a));
      }
    }

    // check mark draws itself on completion
    if (done > 0) {
      final k = Curves.easeOutBack.transform(((done - 0.15) / 0.85).clamp(0.0, 1.0));
      canvas.drawCircle(c, R * 0.52 * k, Paint()..color = accent.withValues(alpha: 0.22 * done));
      final path = Path()
        ..moveTo(c.dx - R * .26, c.dy + R * .02)
        ..lineTo(c.dx - R * .07, c.dy + R * .22)
        ..lineTo(c.dx + R * .29, c.dy - R * .2);
      final m = path.computeMetrics().first;
      canvas.drawPath(
        m.extractPath(0, m.length * ((done - 0.1) / 0.6).clamp(0.0, 1.0)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white,
      );
    }
  }

  /// Deterministic pseudo-random in [0, 1) so the particles look the same on every frame and in tests.
  static double _hash(int n) {
    final x = math.sin(n * 12.9898 + 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  bool shouldRepaint(_HeroPainter o) => o.progress != progress || o.ambient != ambient || o.done != done || o.failed != failed || o.shake != shake || o.accent != accent;
}

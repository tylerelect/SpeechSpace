import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'space_art.dart';

/// Kids-mode pointer fun. With a mouse, a little rocket follows the cursor
/// and leaves a trail of sparkles. Taps on a touch screen burst into stars.
///
/// The whole effect sits on top of [child] and never takes pointer events.
/// The ticker runs only while something is moving, so the effect costs
/// nothing when the screen is still and doesn't hold up `pumpAndSettle`.
class SpaceCursorTrail extends StatefulWidget {
  const SpaceCursorTrail({super.key, required this.enabled, required this.child});
  final bool enabled;
  final Widget child;

  @override
  State<SpaceCursorTrail> createState() => _SpaceCursorTrailState();
}

class _SpaceCursorTrailState extends State<SpaceCursorTrail> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _scene = _TrailScene();
  Duration _last = Duration.zero;

  bool get _active => widget.enabled && !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);

  void _wake() {
    if (_ticker.isActive) return;
    _last = Duration.zero;
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, .05);
    _last = elapsed;
    if (!_scene.step(dt)) _ticker.stop();
  }

  void _hover(PointerEvent e) {
    if (!_active || e.kind != PointerDeviceKind.mouse) return;
    _scene.aim(e.localPosition);
    _wake();
  }

  void _down(PointerDownEvent e) {
    if (!_active) return;
    _scene.burst(e.localPosition, e.kind == PointerDeviceKind.mouse ? 7 : 12);
    _wake();
  }

  @override
  void didUpdateWidget(SpaceCursorTrail old) {
    super.didUpdateWidget(old);
    if (!widget.enabled) _scene.clear();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scene.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    opaque: false,
    hitTestBehavior: HitTestBehavior.translucent,
    onExit: (_) => _scene.leave(),
    child: Listener(
      behavior: HitTestBehavior.translucent,
      onPointerHover: _hover,
      onPointerMove: _hover,
      onPointerDown: _down,
      child: Stack(alignment: Alignment.topLeft, children: [
        RepaintBoundary(child: widget.child),
        Positioned.fill(child: IgnorePointer(child: RepaintBoundary(
            child: CustomPaint(painter: _TrailPainter(_scene))))),
      ]),
    ),
  );
}

class _Spark {
  _Spark(this.pos, this.vel, this.life, this.size, this.color, this.spin);
  Offset pos;
  final Offset vel;
  final double life;
  double age = 0;
  final double size;
  final Color color;
  final double spin;
}

class _TrailScene extends ChangeNotifier {
  static const _colors = [Color(0xFFFFE066), Color(0xFFFF8FAB), Color(0xFF7DE2D1), Color(0xFFB8A9FF), Colors.white];
  // Rides just below-right of the pointer so it never covers what you click.
  static const _offset = Offset(20, 22);
  static const _maxSparks = 90;

  final _rng = math.Random();
  final sparks = <_Spark>[];
  Offset? target;
  Offset? rocket;
  double heading = -math.pi / 4; // up and to the right
  double _travel = 0;

  void aim(Offset pointer) {
    target = pointer + _offset;
    rocket ??= target;
  }

  void leave() {
    target = null;
    rocket = null;
    notifyListeners();
  }

  void clear() {
    sparks.clear();
    leave();
  }

  void burst(Offset at, int n) {
    for (var i = 0; i < n; i++) {
      final a = _rng.nextDouble() * math.pi * 2;
      final speed = 60 + _rng.nextDouble() * 140;
      _add(_Spark(at, Offset(math.cos(a), math.sin(a)) * speed, .45 + _rng.nextDouble() * .4,
          4 + _rng.nextDouble() * 5, _colors[_rng.nextInt(_colors.length)], _rng.nextDouble() * 6 - 3));
    }
  }

  void _add(_Spark s) {
    if (sparks.length >= _maxSparks) sparks.removeAt(0);
    sparks.add(s);
  }

  /// Advances the scene; returns whether anything is still moving.
  bool step(double dt) {
    var moving = false;
    final t = target, r = rocket;
    if (t != null && r != null) {
      final next = Offset.lerp(r, t, 1 - math.exp(-dt * 10))!;
      final delta = next - r;
      if (delta.distance > .05) {
        heading = _turn(heading, math.atan2(delta.dy, delta.dx), 1 - math.exp(-dt * 14));
        _travel += delta.distance;
        // One sparkle every few pixels, puffed out of the tail.
        while (_travel > 7) {
          _travel -= 7;
          final back = Offset(-math.cos(heading), -math.sin(heading));
          final side = Offset(-back.dy, back.dx) * (_rng.nextDouble() * 2 - 1);
          _add(_Spark(next + back * 14, (back * 40) + side * 30, .5 + _rng.nextDouble() * .35,
              2.5 + _rng.nextDouble() * 3.5, _colors[_rng.nextInt(_colors.length)], _rng.nextDouble() * 4 - 2));
        }
      }
      rocket = next;
      moving = (t - next).distance > .5;
    }
    for (final s in sparks) {
      s.age += dt;
      s.pos += s.vel * dt * (1 - s.age / s.life).clamp(0, 1);
    }
    sparks.removeWhere((s) => s.age >= s.life);
    notifyListeners();
    return moving || sparks.isNotEmpty;
  }

  static double _turn(double from, double to, double k) {
    var d = to - from;
    while (d > math.pi) { d -= 2 * math.pi; }
    while (d < -math.pi) { d += 2 * math.pi; }
    return from + d * k;
  }
}

class _TrailPainter extends CustomPainter {
  _TrailPainter(this.scene) : super(repaint: scene);
  final _TrailScene scene;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in scene.sparks) {
      final fade = (1 - s.age / s.life).clamp(0.0, 1.0);
      final r = s.size * (.4 + .6 * fade);
      canvas.save();
      canvas.translate(s.pos.dx, s.pos.dy);
      canvas.rotate(s.spin * s.age);
      canvas.drawPath(starPath(Offset.zero, r, r * .32, points: 4, rotation: 0),
          Paint()..color = s.color.withValues(alpha: fade));
      canvas.restore();
    }
    final r = scene.rocket;
    if (r != null) {
      const side = 34.0;
      canvas.save();
      canvas.translate(r.dx, r.dy);
      canvas.rotate(scene.heading + math.pi / 2); // the art points up
      canvas.translate(-side / 2, -side / 2);
      paintRocket(canvas, const Size.square(side));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) => old.scene != scene;
}

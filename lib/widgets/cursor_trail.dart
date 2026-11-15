import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'space_art.dart';

/// Kids-mode pointer fun, themed: a rocket with star sparkles in Space, a fish
/// with rising bubbles in Ocean, a butterfly with flower petals in Sunshine.
/// With a mouse the rider follows the cursor; taps (or touches) burst.
///
/// The whole effect sits on top of [child] and never takes pointer events.
/// The ticker runs only while something is moving, so the effect costs
/// nothing when the screen is still and doesn't hold up `pumpAndSettle`.
class SpaceCursorTrail extends StatefulWidget {
  const SpaceCursorTrail({super.key, required this.enabled, required this.child, this.themeId = 'space'});
  final bool enabled;
  final String themeId;
  final Widget child;

  @override
  State<SpaceCursorTrail> createState() => _SpaceCursorTrailState();
}

class _SpaceCursorTrailState extends State<SpaceCursorTrail> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _scene = _TrailScene();
  late TrailStyle _style = TrailStyle.of(widget.themeId);
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
    if (old.themeId != widget.themeId) {
      _style = TrailStyle.of(widget.themeId);
      _scene.style = _style;
      _scene.sparks.clear();
    }
  }

  @override
  void initState() {
    super.initState();
    _scene.style = _style;
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

enum SparkShape { star, bubble, petal }

class TrailStyle {
  const TrailStyle(this.colors, this.shape, this.rider, {this.rise = 0, this.flaps = false});
  final List<Color> colors;
  final SparkShape shape;
  final SpaceArtKind rider;
  final double rise; // upward drift in px/s (bubbles float up)
  final bool flaps;

  static TrailStyle of(String themeId) => switch (themeId) {
    'ocean' => const TrailStyle([Color(0xFFFFFFFF), Color(0xFF7FD6F7), Color(0xFF3FB4E8), Color(0xFFB8F0FF)],
        SparkShape.bubble, SpaceArtKind.fish, rise: -55),
    'sunshine' => const TrailStyle([Color(0xFFFF8FB8), Color(0xFFFFC94D), Color(0xFFFFA0C8), Color(0xFFFFE066)],
        SparkShape.petal, SpaceArtKind.butterfly, flaps: true),
    _ => const TrailStyle([Color(0xFFFFE066), Color(0xFFFF8FAB), Color(0xFF7DE2D1), Color(0xFFB8A9FF), Colors.white],
        SparkShape.star, SpaceArtKind.rocket),
  };
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
  TrailStyle style = TrailStyle.of('space');
  List<Color> get _colors => style.colors;
  double clock = 0;
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
      _add(_Spark(at, Offset(math.cos(a), math.sin(a)) * speed + Offset(0, style.rise), .45 + _rng.nextDouble() * .4,
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
    clock += dt;
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
          _add(_Spark(next + back * 14, (back * 40) + side * 30 + Offset(0, style.rise), .5 + _rng.nextDouble() * .35,
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

  // Paints every frame while moving, so reuse paint objects and one unit star
  // (scaled per spark) instead of allocating them for every spark.
  static final _unitStar = starPath(Offset.zero, 1, .32, points: 4, rotation: 0);
  final _fill = Paint();
  final _stroke = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in scene.sparks) {
      final fade = (1 - s.age / s.life).clamp(0.0, 1.0);
      final r = s.size * (.4 + .6 * fade);
      canvas.save();
      canvas.translate(s.pos.dx, s.pos.dy);
      canvas.rotate(s.spin * s.age);
      switch (scene.style.shape) {
        case SparkShape.star:
          canvas.scale(r);
          canvas.drawPath(_unitStar, _fill..color = s.color.withValues(alpha: fade));
        case SparkShape.bubble:
          canvas.drawCircle(Offset.zero, r, _fill..color = s.color.withValues(alpha: fade * .25));
          canvas.drawCircle(Offset.zero, r, _stroke..color = s.color.withValues(alpha: fade));
        case SparkShape.petal:
          canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 1.1, height: r * 2.1),
              _fill..color = s.color.withValues(alpha: fade));
      }
      canvas.restore();
    }
    final r = scene.rocket;
    if (r != null) {
      const side = 34.0;
      canvas.save();
      canvas.translate(r.dx, r.dy);
      // Rocket and butterfly point up; the fish faces right.
      canvas.rotate(scene.heading + (scene.style.rider == SpaceArtKind.fish ? 0 : math.pi / 2));
      canvas.translate(-side / 2, -side / 2);
      switch (scene.style.rider) {
        case SpaceArtKind.fish: paintFish(canvas, const Size.square(side));
        case SpaceArtKind.butterfly: paintButterfly(canvas, const Size.square(side), flap: .5 + .5 * math.cos(scene.clock * 16).abs());
        default: paintRocket(canvas, const Size.square(side));
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) => old.scene != scene;
}

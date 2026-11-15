import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Hand-drawn space pictures for Kids mode. Everything is painted in code so
/// there are no image assets to license or ship, and it stays sharp at any size.
enum SpaceArtKind { rocket, planet, moon, star }

class SpaceArt extends StatelessWidget {
  const SpaceArt(this.kind, {super.key, this.size = 48, this.semanticLabel});
  final SpaceArtKind kind;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final art = SizedBox.square(dimension: size, child: CustomPaint(painter: _ArtPainter(kind)));
    return semanticLabel == null ? ExcludeSemantics(child: art) : Semantics(label: semanticLabel, image: true, child: art);
  }
}

class _ArtPainter extends CustomPainter {
  const _ArtPainter(this.kind);
  final SpaceArtKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case SpaceArtKind.rocket: paintRocket(canvas, size);
      case SpaceArtKind.planet: paintPlanet(canvas, size);
      case SpaceArtKind.moon: paintMoon(canvas, size);
      case SpaceArtKind.star: paintStarFace(canvas, size);
    }
  }

  @override
  bool shouldRepaint(_ArtPainter old) => old.kind != kind;
}

// All shapes are drawn on a 100×100 grid and scaled to the target size.
void _unit(Canvas canvas, Size size) => canvas.scale(size.width / 100, size.height / 100);

const _ink = Color(0xFF2B2160);

/// A chunky cartoon rocket pointing up.
void paintRocket(Canvas canvas, Size size, {bool flame = true}) {
  canvas.save();
  _unit(canvas, size);
  final outline = Paint()..style = PaintingStyle.stroke..strokeWidth = 3..strokeJoin = StrokeJoin.round..color = _ink;

  if (flame) {
    final f = Path()..moveTo(39, 76)..quadraticBezierTo(42, 92, 50, 99)..quadraticBezierTo(58, 92, 61, 76)..close();
    canvas.drawPath(f, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFFFFE066), Color(0xFFFF7A3D)]).createShader(const Rect.fromLTWH(39, 76, 22, 23)));
    final inner = Path()..moveTo(45, 76)..quadraticBezierTo(47, 86, 50, 90)..quadraticBezierTo(53, 86, 55, 76)..close();
    canvas.drawPath(inner, Paint()..color = const Color(0xFFFFF6C2));
  }

  final finPaint = Paint()..color = const Color(0xFFFF5D8F);
  final leftFin = Path()..moveTo(35, 52)..quadraticBezierTo(20, 62, 20, 80)..lineTo(36, 72)..close();
  final rightFin = Path()..moveTo(65, 52)..quadraticBezierTo(80, 62, 80, 80)..lineTo(64, 72)..close();
  for (final fin in [leftFin, rightFin]) { canvas.drawPath(fin, finPaint); canvas.drawPath(fin, outline); }

  final body = Path()
    ..moveTo(50, 4)
    ..cubicTo(68, 16, 70, 44, 65, 76)
    ..lineTo(35, 76)
    ..cubicTo(30, 44, 32, 16, 50, 4)
    ..close();
  canvas.drawPath(body, Paint()..shader = const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFD9D4FF)])
      .createShader(const Rect.fromLTWH(32, 4, 38, 72)));
  canvas.save();
  canvas.clipPath(body);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 22), Paint()..color = const Color(0xFFFF5D8F));
  canvas.drawRect(const Rect.fromLTWH(0, 66, 100, 4), Paint()..color = const Color(0xFFFFC94D));
  canvas.restore();
  canvas.drawPath(body, outline);

  canvas.drawRect(const Rect.fromLTWH(47.5, 60, 5, 16), finPaint);
  canvas.drawCircle(const Offset(50, 41), 10, Paint()..color = const Color(0xFFFFC94D));
  canvas.drawCircle(const Offset(50, 41), 7, Paint()..color = const Color(0xFF4CC9F0));
  canvas.drawCircle(const Offset(50, 41), 10, outline);
  canvas.drawCircle(const Offset(47, 38), 2.4, Paint()..color = Colors.white);
  canvas.restore();
}

/// A tilted, ringed planet in warm candy colors.
void paintPlanet(Canvas canvas, Size size, {Color a = const Color(0xFFFFB86B), Color b = const Color(0xFFFF6F91)}) {
  canvas.save();
  _unit(canvas, size);
  canvas.translate(50, 50);
  canvas.rotate(-.35);
  final ringRect = Rect.fromCenter(center: Offset.zero, width: 96, height: 28);
  final ring = Paint()..style = PaintingStyle.stroke..strokeWidth = 6..color = const Color(0xFFB8A9FF);
  final ringLine = Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = _ink;
  // Back half of the ring, behind the planet.
  canvas.drawArc(ringRect, math.pi, math.pi, false, ring);

  const r = 30.0;
  final ball = Rect.fromCircle(center: Offset.zero, radius: r);
  canvas.drawCircle(Offset.zero, r, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [a, b]).createShader(ball));
  canvas.save();
  canvas.clipPath(Path()..addOval(ball));
  final band = Paint()..color = Colors.white.withValues(alpha: .22);
  canvas.drawRect(const Rect.fromLTWH(-40, -12, 80, 6), band);
  canvas.drawRect(const Rect.fromLTWH(-40, 6, 80, 4), band);
  canvas.drawCircle(const Offset(12, 16), 22, Paint()..color = _ink.withValues(alpha: .14));
  canvas.restore();
  canvas.drawCircle(Offset.zero, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = _ink);
  canvas.drawCircle(const Offset(-12, -14), 5, Paint()..color = Colors.white.withValues(alpha: .6));

  // Front half of the ring, over the planet.
  canvas.drawArc(ringRect, 0, math.pi, false, ring);
  canvas.drawArc(ringRect.inflate(3), 0, math.pi, false, ringLine);
  canvas.restore();
}

/// A friendly cratered moon.
void paintMoon(Canvas canvas, Size size) {
  canvas.save();
  _unit(canvas, size);
  const c = Offset(50, 50);
  final rect = Rect.fromCircle(center: c, radius: 40);
  canvas.drawCircle(c, 40, Paint()..shader = const RadialGradient(center: Alignment(-.35, -.4),
      colors: [Color(0xFFFFFBEA), Color(0xFFE3DCC4)]).createShader(rect));
  final crater = Paint()..color = const Color(0xFFCFC6A8);
  canvas.drawCircle(const Offset(64, 36), 8, crater);
  canvas.drawCircle(const Offset(36, 64), 10, crater);
  canvas.drawCircle(const Offset(66, 66), 5, crater);
  canvas.drawCircle(const Offset(34, 34), 4, crater);
  canvas.drawCircle(c, 40, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = _ink);
  canvas.restore();
}

Path starPath(Offset c, double outer, double inner, {int points = 5, double rotation = -math.pi / 2}) {
  final path = Path();
  for (var i = 0; i < points * 2; i++) {
    final r = i.isEven ? outer : inner;
    final a = rotation + i * math.pi / points;
    final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

/// A smiling gold star sticker.
void paintStarFace(Canvas canvas, Size size) {
  canvas.save();
  _unit(canvas, size);
  final star = starPath(const Offset(50, 54), 46, 22);
  canvas.drawPath(star, Paint()..color = const Color(0xFFFFD23F));
  canvas.drawPath(star, Paint()..style = PaintingStyle.stroke..strokeWidth = 4..strokeJoin = StrokeJoin.round..color = _ink);
  final eye = Paint()..color = _ink;
  canvas.drawCircle(const Offset(42, 50), 3.6, eye);
  canvas.drawCircle(const Offset(58, 50), 3.6, eye);
  canvas.drawArc(Rect.fromCenter(center: const Offset(50, 58), width: 14, height: 10), .2, math.pi - .4, false,
      Paint()..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round..color = _ink);
  final blush = Paint()..color = const Color(0xFFFF8FAB).withValues(alpha: .8);
  canvas.drawCircle(const Offset(36, 59), 3.5, blush);
  canvas.drawCircle(const Offset(64, 59), 3.5, blush);
  canvas.restore();
}

/// Full-screen night sky behind the Space theme: soft nebulae, scattered stars,
/// and a couple of planets peeking in from the edges. Static, so it costs
/// nothing after the first frame.
class SpaceBackdrop extends StatelessWidget {
  const SpaceBackdrop({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(child: ExcludeSemantics(child: RepaintBoundary(
    child: LayoutBuilder(builder: (context, c) {
      final narrow = c.maxWidth < 600;
      return Stack(clipBehavior: Clip.hardEdge, children: [
        const Positioned.fill(child: CustomPaint(painter: _SkyPainter())),
        Positioned(right: narrow ? -46 : -30, top: narrow ? 150 : 90,
            child: Opacity(opacity: .55, child: SpaceArt(SpaceArtKind.planet, size: narrow ? 130 : 190))),
        Positioned(left: narrow ? -34 : 24, bottom: narrow ? 70 : 60,
            child: Opacity(opacity: .4, child: SpaceArt(SpaceArtKind.moon, size: narrow ? 90 : 120))),
      ]);
    }),
  )));
}

class _SkyPainter extends CustomPainter {
  const _SkyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    canvas.drawRect(full, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF0B0D2E), Color(0xFF151245), Color(0xFF1E1250)]).createShader(full));

    void nebula(Offset c, double r, Color color) => canvas.drawCircle(c, r, Paint()
      ..shader = RadialGradient(colors: [color.withValues(alpha: .28), color.withValues(alpha: 0)])
          .createShader(Rect.fromCircle(center: c, radius: r)));
    nebula(Offset(size.width * .15, size.height * .22), size.shortestSide * .55, const Color(0xFF7C4DFF));
    nebula(Offset(size.width * .9, size.height * .7), size.shortestSide * .6, const Color(0xFFFF4F9A));
    nebula(Offset(size.width * .5, size.height * 1.05), size.shortestSide * .5, const Color(0xFF2EC4F1));

    // Fixed seed: the sky looks the same every time, like a real one.
    final rng = math.Random(7);
    final count = (size.width * size.height / 5200).clamp(40, 320).round();
    for (var i = 0; i < count; i++) {
      final p = Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height);
      final big = rng.nextDouble() < .08;
      final tint = [Colors.white, const Color(0xFFFFE8A3), const Color(0xFFBFD7FF)][rng.nextInt(3)];
      final alpha = .35 + rng.nextDouble() * .55;
      if (big) {
        // A few bright sparkle stars.
        final s = 3.5 + rng.nextDouble() * 3;
        canvas.drawPath(starPath(p, s, s * .28, points: 4, rotation: 0), Paint()..color = tint.withValues(alpha: alpha));
      } else {
        canvas.drawCircle(p, .6 + rng.nextDouble() * 1.1, Paint()..color = tint.withValues(alpha: alpha));
      }
    }
  }

  @override
  bool shouldRepaint(_SkyPainter oldDelegate) => false;
}

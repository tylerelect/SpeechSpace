import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Hand-drawn pictures for Kids mode, one family per theme (space, ocean,
/// sunshine). Everything is painted in code so there are no image assets to
/// license or ship, and it stays sharp at any size.
enum SpaceArtKind { rocket, planet, moon, star, fish, shell, bubble, starfish, sun, rainbow, cloud, flower, butterfly }

/// What a picture is for. Screens ask for a role and the theme picks the art,
/// so the same layout reads as space, underwater or a sunny meadow.
enum ArtRole { hero, big, calm, sticker }

SpaceArtKind artFor(String themeId, ArtRole role) => switch (themeId) {
  'ocean' => switch (role) {
    ArtRole.hero => SpaceArtKind.fish, ArtRole.big => SpaceArtKind.shell,
    ArtRole.calm => SpaceArtKind.bubble, ArtRole.sticker => SpaceArtKind.starfish },
  'sunshine' => switch (role) {
    ArtRole.hero => SpaceArtKind.sun, ArtRole.big => SpaceArtKind.rainbow,
    ArtRole.calm => SpaceArtKind.cloud, ArtRole.sticker => SpaceArtKind.flower },
  _ => switch (role) {
    ArtRole.hero => SpaceArtKind.rocket, ArtRole.big => SpaceArtKind.planet,
    ArtRole.calm => SpaceArtKind.moon, ArtRole.sticker => SpaceArtKind.star },
};

/// Small per-theme touches for calendar cells, stat tiles and the story map.
class KidsDecor {
  const KidsDecor({required this.marker, required this.markerColor, required this.milestone,
      required this.milestoneColor, required this.accents, required this.mapName, required this.noun,
      required this.nouns, required this.navIcon, required this.navIconSelected});
  final IconData marker, milestone, navIcon, navIconSelected;
  final Color markerColor, milestoneColor;
  final List<Color> accents;
  /// The Kids name for the mind map and what its dots are called.
  final String mapName, noun, nouns;

  static KidsDecor of(String themeId) => switch (themeId) {
    'ocean' => const KidsDecor(marker: Icons.water_drop_rounded, markerColor: Color(0xFF1E9BD7),
        milestone: Icons.sailing_rounded, milestoneColor: Color(0xFFFF7A59),
        accents: [Color(0xFF4CC9F0), Color(0xFFFF8A65), Color(0xFF7BE0B0)],
        mapName: 'Sea map', noun: 'bubble', nouns: 'bubbles',
        navIcon: Icons.waves_outlined, navIconSelected: Icons.waves),
    'sunshine' => const KidsDecor(marker: Icons.wb_sunny_rounded, markerColor: Color(0xFFF2A516),
        milestone: Icons.local_florist_rounded, milestoneColor: Color(0xFFE85D9A),
        accents: [Color(0xFFFFC94D), Color(0xFFFF8FAB), Color(0xFF8BD66B)],
        mapName: 'Garden map', noun: 'flower', nouns: 'flowers',
        navIcon: Icons.local_florist_outlined, navIconSelected: Icons.local_florist),
    _ => const KidsDecor(marker: Icons.star_rounded, markerColor: Color(0xFFFFD23F),
        milestone: Icons.rocket_launch_rounded, milestoneColor: Color(0xFFFF8FAB),
        accents: [Color(0xFFFFD23F), Color(0xFFFF8FAB), Color(0xFF7DE2D1)],
        mapName: 'Star map', noun: 'star', nouns: 'stars',
        navIcon: Icons.auto_awesome_outlined, navIconSelected: Icons.auto_awesome),
  };
}

class SpaceArt extends StatelessWidget {
  const SpaceArt(this.kind, {super.key, this.size = 48, this.semanticLabel});
  SpaceArt.of(String themeId, ArtRole role, {Key? key, double size = 48})
      : this(artFor(themeId, role), key: key, size: size);
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
      case SpaceArtKind.fish: paintFish(canvas, size);
      case SpaceArtKind.shell: paintShell(canvas, size);
      case SpaceArtKind.bubble: paintBubbles(canvas, size);
      case SpaceArtKind.starfish: paintStarFace(canvas, size, fill: const Color(0xFFFF8A65), inner: 28, dots: true);
      case SpaceArtKind.sun: paintSun(canvas, size);
      case SpaceArtKind.rainbow: paintRainbow(canvas, size);
      case SpaceArtKind.cloud: paintCloud(canvas, size);
      case SpaceArtKind.flower: paintFlower(canvas, size);
      case SpaceArtKind.butterfly: paintButterfly(canvas, size);
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
void paintStarFace(Canvas canvas, Size size, {Color fill = const Color(0xFFFFD23F), double inner = 22, bool dots = false}) {
  canvas.save();
  _unit(canvas, size);
  final star = starPath(const Offset(50, 54), 46, inner);
  canvas.drawPath(star, Paint()..color = fill);
  if (dots) {
    final dot = Paint()..color = Colors.white.withValues(alpha: .55);
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      canvas.drawCircle(Offset(50 + math.cos(a) * 32, 54 + math.sin(a) * 32), 2.4, dot);
    }
  }
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


// ---- Ocean ----------------------------------------------------------------

/// A round orange fish facing right.
void paintFish(Canvas canvas, Size size) {
  canvas.save();
  _unit(canvas, size);
  final outline = Paint()..style = PaintingStyle.stroke..strokeWidth = 3..strokeJoin = StrokeJoin.round..color = _ink;
  final finPaint = Paint()..color = const Color(0xFFFF5D8F);
  final tail = Path()..moveTo(26, 50)..quadraticBezierTo(12, 46, 3, 30)..quadraticBezierTo(8, 50, 3, 70)..quadraticBezierTo(12, 54, 26, 50)..close();
  final top = Path()..moveTo(36, 32)..quadraticBezierTo(46, 14, 62, 30)..close();
  final bottom = Path()..moveTo(44, 68)..quadraticBezierTo(50, 82, 60, 68)..close();
  for (final f in [tail, top, bottom]) { canvas.drawPath(f, finPaint); canvas.drawPath(f, outline); }
  final body = Rect.fromCenter(center: const Offset(52, 50), width: 76, height: 50);
  canvas.drawOval(body, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0xFFFFB347), Color(0xFFFF7A3D)]).createShader(body));
  canvas.save();
  canvas.clipPath(Path()..addOval(body));
  final stripe = Paint()..color = Colors.white.withValues(alpha: .7);
  canvas.drawRect(const Rect.fromLTWH(38, 20, 6, 60), stripe);
  canvas.drawRect(const Rect.fromLTWH(52, 20, 5, 60), stripe);
  canvas.restore();
  canvas.drawOval(body, outline);
  canvas.drawCircle(const Offset(72, 44), 6.5, Paint()..color = Colors.white);
  canvas.drawCircle(const Offset(73.5, 44), 3.2, Paint()..color = _ink);
  canvas.drawArc(Rect.fromCenter(center: const Offset(78, 56), width: 12, height: 9), .3, 2.3, false,
      Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round..color = _ink);
  canvas.restore();
}

/// A pink scallop shell.
void paintShell(Canvas canvas, Size size) {
  canvas.save();
  _unit(canvas, size);
  final outline = Paint()..style = PaintingStyle.stroke..strokeWidth = 3..strokeJoin = StrokeJoin.round..color = _ink;
  const c = Offset(50, 78);
  final fan = Path()..moveTo(c.dx, c.dy);
  const n = 7;
  for (var i = 0; i <= n; i++) {
    final a = math.pi + i * math.pi / n;
    final r = i.isEven ? 44.0 : 38.0;
    fan.lineTo(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
  }
  fan.close();
  final rect = Rect.fromCircle(center: c, radius: 44);
  canvas.drawPath(fan, Paint()..shader = const RadialGradient(center: Alignment(0, 1), radius: 1.1,
      colors: [Color(0xFFFFE3EC), Color(0xFFFF9EBB)]).createShader(rect));
  final rib = Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color(0xFFE0668A);
  for (var i = 1; i < n; i++) {
    final a = math.pi + i * math.pi / n;
    canvas.drawLine(c, Offset(c.dx + math.cos(a) * 36, c.dy + math.sin(a) * 36), rib);
  }
  canvas.drawPath(fan, outline);
  final base = RRect.fromRectAndRadius(const Rect.fromLTWH(40, 74, 20, 12), const Radius.circular(5));
  canvas.drawRRect(base, Paint()..color = const Color(0xFFFFC2D4));
  canvas.drawRRect(base, outline);
  canvas.restore();
}

/// A cluster of shiny bubbles.
void paintBubbles(Canvas canvas, Size size) {
  canvas.save();
  _unit(canvas, size);
  void bubble(Offset c, double r) {
    canvas.drawCircle(c, r, Paint()..shader = RadialGradient(center: const Alignment(-.4, -.4),
        colors: [Colors.white.withValues(alpha: .85), const Color(0xFF9BE3FF).withValues(alpha: .55)])
        .createShader(Rect.fromCircle(center: c, radius: r)));
    canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5..color = const Color(0xFF2E9BD0));
    canvas.drawCircle(c + Offset(-r * .35, -r * .35), r * .16, Paint()..color = Colors.white);
  }
  bubble(const Offset(42, 60), 30);
  bubble(const Offset(72, 28), 17);
  bubble(const Offset(80, 74), 10);
  canvas.restore();
}

// ---- Sunshine -------------------------------------------------------------

/// A smiling sun with a ring of rays.
void paintSun(Canvas canvas, Size size) {
  canvas.save();
  _unit(canvas, size);
  const c = Offset(50, 50);
  final rays = starPath(c, 48, 33, points: 12);
  canvas.drawPath(rays, Paint()..color = const Color(0xFFFFA62B));
  canvas.drawPath(rays, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..strokeJoin = StrokeJoin.round..color = _ink);
  final face = Rect.fromCircle(center: c, radius: 28);
  canvas.drawCircle(c, 28, Paint()..shader = const RadialGradient(center: Alignment(-.3, -.3),
      colors: [Color(0xFFFFF3A0), Color(0xFFFFD23F)]).createShader(face));
  canvas.drawCircle(c, 28, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = _ink);
  final eye = Paint()..color = _ink;
  canvas.drawCircle(const Offset(40, 46), 3.4, eye);
  canvas.drawCircle(const Offset(60, 46), 3.4, eye);
  canvas.drawArc(Rect.fromCenter(center: const Offset(50, 55), width: 20, height: 14), .2, math.pi - .4, false,
      Paint()..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round..color = _ink);
  final blush = Paint()..color = const Color(0xFFFF8FAB).withValues(alpha: .8);
  canvas.drawCircle(const Offset(33, 56), 4, blush);
  canvas.drawCircle(const Offset(67, 56), 4, blush);
  canvas.restore();
}

/// A puffy cloud.
void paintCloud(Canvas canvas, Size size) {
  canvas.save();
  _unit(canvas, size);
  final path = Path()
    ..addOval(Rect.fromCircle(center: const Offset(32, 62), radius: 20))
    ..addOval(Rect.fromCircle(center: const Offset(52, 44), radius: 26))
    ..addOval(Rect.fromCircle(center: const Offset(74, 60), radius: 21))
    ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(30, 58, 46, 24), const Radius.circular(12)));
  canvas.drawPath(path, Paint()..color = Colors.white);
  canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = const Color(0xFF8CC8F0));
  // Re-cover the inner outlines so it reads as one cloud.
  canvas.save();
  canvas.clipPath(path);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), Paint()..color = Colors.white);
  canvas.restore();
  final eye = Paint()..color = _ink;
  canvas.drawCircle(const Offset(44, 62), 2.8, eye);
  canvas.drawCircle(const Offset(60, 62), 2.8, eye);
  canvas.drawArc(Rect.fromCenter(center: const Offset(52, 68), width: 10, height: 7), .2, math.pi - .4, false,
      Paint()..style = PaintingStyle.stroke..strokeWidth = 2.4..strokeCap = StrokeCap.round..color = _ink);
  canvas.restore();
}

/// A four-band rainbow arch with a cloud at each foot.
void paintRainbow(Canvas canvas, Size size) {
  canvas.save();
  _unit(canvas, size);
  const colors = [Color(0xFFFF5D5D), Color(0xFFFFB347), Color(0xFFFFE066), Color(0xFF7BD88F), Color(0xFF59B8F0)];
  for (var i = 0; i < colors.length; i++) {
    final r = 42.0 - i * 7;
    canvas.drawArc(Rect.fromCircle(center: const Offset(50, 72), radius: r), math.pi, math.pi, false,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 7.5..color = colors[i]);
  }
  void puff(Offset c) {
    final p = Paint()..color = Colors.white;
    canvas.drawCircle(c, 9, p);
    canvas.drawCircle(c + const Offset(9, 3), 7, p);
    canvas.drawCircle(c + const Offset(-9, 3), 7, p);
  }
  puff(const Offset(14, 76));
  puff(const Offset(86, 76));
  canvas.restore();
}

/// A smiling pink flower.
void paintFlower(Canvas canvas, Size size) {
  canvas.save();
  _unit(canvas, size);
  const c = Offset(50, 50);
  final petal = Paint()..color = const Color(0xFFFF8FB8);
  final line = Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = _ink;
  for (var i = 0; i < 6; i++) {
    final a = i * math.pi / 3;
    final pc = c + Offset(math.cos(a), math.sin(a)) * 25;
    canvas.drawCircle(pc, 17, petal);
    canvas.drawCircle(pc, 17, line);
  }
  canvas.drawCircle(c, 20, Paint()..color = petal.color);
  canvas.drawCircle(c, 17, Paint()..color = const Color(0xFFFFD23F));
  canvas.drawCircle(c, 17, line);
  final eye = Paint()..color = _ink;
  canvas.drawCircle(const Offset(44, 47), 2.8, eye);
  canvas.drawCircle(const Offset(56, 47), 2.8, eye);
  canvas.drawArc(Rect.fromCenter(center: const Offset(50, 54), width: 11, height: 8), .2, math.pi - .4, false,
      Paint()..style = PaintingStyle.stroke..strokeWidth = 2.4..strokeCap = StrokeCap.round..color = _ink);
  canvas.restore();
}

/// A butterfly seen from above, head up. [flap] 0..1 closes the wings a little.
void paintButterfly(Canvas canvas, Size size, {double flap = 1}) {
  canvas.save();
  _unit(canvas, size);
  canvas.translate(50, 50);
  canvas.scale(.5 + .5 * flap, 1);
  final line = Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = _ink;
  void wing(double x, double y, double w, double h, double tilt, Color color) {
    for (final sx in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(x * sx, y);
      canvas.rotate(sx * tilt);
      final r = Rect.fromCenter(center: Offset.zero, width: w, height: h);
      canvas.drawOval(r, Paint()..color = color);
      canvas.drawOval(r, line);
      canvas.drawCircle(Offset.zero, w * .18, Paint()..color = Colors.white.withValues(alpha: .7));
      canvas.restore();
    }
  }
  wing(22, -14, 36, 46, .5, const Color(0xFFB07CFF));
  wing(16, 20, 26, 32, -.4, const Color(0xFFFF8FB8));
  canvas.restore();
  // Body and feelers stay narrow however far the wings close.
  canvas.save();
  _unit(canvas, size);
  canvas.drawLine(const Offset(48, 24), const Offset(40, 8), line..strokeWidth = 2.4);
  canvas.drawLine(const Offset(52, 24), const Offset(60, 8), line);
  canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(45, 22, 10, 56), const Radius.circular(5)), Paint()..color = _ink);
  canvas.restore();
}

// ---- Backdrops -------------------------------------------------------------

/// Picks the full-screen backdrop for a Kids theme.
class ThemeBackdrop extends StatelessWidget {
  const ThemeBackdrop(this.themeId, {super.key});
  final String themeId;

  @override
  Widget build(BuildContext context) => switch (themeId) {
    'ocean' => const OceanBackdrop(),
    'sunshine' => const SunshineBackdrop(),
    _ => const SpaceBackdrop(),
  };
}

class OceanBackdrop extends StatelessWidget {
  const OceanBackdrop({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(child: ExcludeSemantics(child: RepaintBoundary(
    child: LayoutBuilder(builder: (context, c) {
      final narrow = c.maxWidth < 600;
      return Stack(clipBehavior: Clip.hardEdge, children: [
        const Positioned.fill(child: CustomPaint(painter: _OceanPainter())),
        Positioned(right: narrow ? -20 : 40, top: narrow ? 170 : 110, child: Opacity(opacity: .8,
            child: SpaceArt(SpaceArtKind.fish, size: narrow ? 84 : 120))),
        Positioned(left: narrow ? 10 : 70, top: narrow ? 330 : 300, child: Transform.flip(flipX: true, child: Opacity(opacity: .6,
            child: SpaceArt(SpaceArtKind.fish, size: narrow ? 52 : 74)))),
        Positioned(left: narrow ? -14 : 20, bottom: narrow ? 74 : 40, child: Opacity(opacity: .85,
            child: SpaceArt(SpaceArtKind.shell, size: narrow ? 84 : 120))),
        Positioned(right: narrow ? 6 : 50, bottom: narrow ? 78 : 44, child: Opacity(opacity: .85,
            child: SpaceArt(SpaceArtKind.starfish, size: narrow ? 56 : 80))),
      ]);
    }),
  )));
}

class _OceanPainter extends CustomPainter {
  const _OceanPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    canvas.drawRect(full, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFFE6F8FF), Color(0xFFB5E6FA), Color(0xFF7CCDF0)]).createShader(full));
    // Soft light rays from the surface.
    for (var i = 0; i < 4; i++) {
      final x = size.width * (.1 + i * .27);
      canvas.drawPath(Path()..moveTo(x, 0)..lineTo(x + 70, 0)..lineTo(x + 190, size.height * .8)..lineTo(x + 40, size.height * .8)..close(),
          Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.white.withValues(alpha: .35), Colors.white.withValues(alpha: 0)]).createShader(full));
    }
    // Bubbles drifting up.
    final rng = math.Random(11);
    final count = (size.width * size.height / 14000).clamp(14, 70).round();
    for (var i = 0; i < count; i++) {
      final p = Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height);
      final r = 3 + rng.nextDouble() * 9;
      canvas.drawCircle(p, r, Paint()..color = Colors.white.withValues(alpha: .18));
      canvas.drawCircle(p, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = Colors.white.withValues(alpha: .7));
      canvas.drawCircle(p + Offset(-r * .35, -r * .35), r * .2, Paint()..color = Colors.white.withValues(alpha: .9));
    }
    // Layered sand-and-wave bands along the bottom.
    for (var i = 0; i < 3; i++) {
      final base = size.height - 40 - i * 26.0;
      final path = Path()..moveTo(0, size.height);
      for (var x = 0.0; x <= size.width; x += 8) {
        path.lineTo(x, base + math.sin(x / 38 + i * 1.7) * 9);
      }
      path..lineTo(size.width, size.height)..close();
      canvas.drawPath(path, Paint()..color = [const Color(0xFF59B8E6), const Color(0xFF3FA3D8), const Color(0xFFF2D9A0)][i].withValues(alpha: .45));
    }
  }

  @override
  bool shouldRepaint(_OceanPainter oldDelegate) => false;
}

class SunshineBackdrop extends StatelessWidget {
  const SunshineBackdrop({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(child: ExcludeSemantics(child: RepaintBoundary(
    child: LayoutBuilder(builder: (context, c) {
      final narrow = c.maxWidth < 600;
      return Stack(clipBehavior: Clip.hardEdge, children: [
        const Positioned.fill(child: CustomPaint(painter: _SunshinePainter())),
        Positioned(right: narrow ? -26 : 30, top: narrow ? 120 : 70,
            child: SpaceArt(SpaceArtKind.sun, size: narrow ? 120 : 180)),
        Positioned(left: narrow ? -20 : 40, top: narrow ? 250 : 190, child: Opacity(opacity: .9,
            child: SpaceArt(SpaceArtKind.cloud, size: narrow ? 90 : 130))),
        Positioned(right: narrow ? 20 : 120, top: narrow ? 420 : 380, child: Opacity(opacity: .7,
            child: SpaceArt(SpaceArtKind.cloud, size: narrow ? 56 : 80))),
        Positioned(left: narrow ? 8 : 40, bottom: narrow ? 78 : 40, child: SpaceArt(SpaceArtKind.flower, size: narrow ? 56 : 80)),
        Positioned(right: narrow ? 14 : 70, bottom: narrow ? 90 : 56, child: SpaceArt(SpaceArtKind.flower, size: narrow ? 44 : 64)),
        Positioned(left: narrow ? 90 : 190, bottom: narrow ? 120 : 90, child: Transform.rotate(angle: .4,
            child: SpaceArt(SpaceArtKind.butterfly, size: narrow ? 34 : 48))),
      ]);
    }),
  )));
}

class _SunshinePainter extends CustomPainter {
  const _SunshinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    canvas.drawRect(full, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFFFFF1B8), Color(0xFFFFF8E6), Color(0xFFFFE9C2)]).createShader(full));
    // Warm glow behind the sun.
    final glow = Offset(size.width * .85, size.height * .12);
    canvas.drawCircle(glow, size.shortestSide * .7, Paint()..shader = RadialGradient(
        colors: [const Color(0xFFFFD23F).withValues(alpha: .4), const Color(0xFFFFD23F).withValues(alpha: 0)])
        .createShader(Rect.fromCircle(center: glow, radius: size.shortestSide * .7)));
    // Tiny sparkles and confetti dots.
    final rng = math.Random(5);
    final count = (size.width * size.height / 9000).clamp(20, 90).round();
    final colors = [const Color(0xFFFFB347), const Color(0xFFFF8FAB), const Color(0xFF7BD88F), const Color(0xFF59B8F0)];
    for (var i = 0; i < count; i++) {
      final p = Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height);
      canvas.drawCircle(p, 1.5 + rng.nextDouble() * 2.5, Paint()..color = colors[rng.nextInt(colors.length)].withValues(alpha: .35));
    }
    // Rolling hills.
    for (var i = 0; i < 2; i++) {
      final base = size.height - 46 - i * 30.0;
      final path = Path()..moveTo(0, size.height);
      for (var x = 0.0; x <= size.width; x += 8) {
        path.lineTo(x, base + math.sin(x / (70 + i * 25) + i * 2.1) * 14);
      }
      path..lineTo(size.width, size.height)..close();
      canvas.drawPath(path, Paint()..color = [const Color(0xFF8BD66B), const Color(0xFFB4E68A)][i].withValues(alpha: .5));
    }
  }

  @override
  bool shouldRepaint(_SunshinePainter oldDelegate) => false;
}


/// Fixed (not zoomed) scene for the story-map canvas, so the map itself feels
/// like part of the theme: twinkling sky, open water, or a sunny meadow.
class MapScenePainter extends CustomPainter {
  const MapScenePainter(this.themeId);
  final String themeId;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final (colors, dot, shape) = switch (themeId) {
      'ocean' => (const [Color(0xFFD9F3FF), Color(0xFF9FDDF7)], Colors.white, 1),
      'sunshine' => (const [Color(0xFFFFF4C9), Color(0xFFFFE6B0)], const Color(0xFFFFB347), 2),
      _ => (const [Color(0xFF0F1240), Color(0xFF211457)], Colors.white, 0),
    };
    canvas.drawRect(full, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: colors).createShader(full));
    final rng = math.Random(23);
    final n = (size.width * size.height / 7000).clamp(24, 160).round();
    for (var i = 0; i < n; i++) {
      final p = Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height);
      final r = .8 + rng.nextDouble() * (shape == 1 ? 6 : 2.4);
      final alpha = .3 + rng.nextDouble() * .5;
      switch (shape) {
        case 1: // bubbles
          canvas.drawCircle(p, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = dot.withValues(alpha: alpha));
        case 2: // confetti
          canvas.drawCircle(p, r, Paint()..color = [dot, const Color(0xFFFF8FAB), const Color(0xFF8BD66B)][i % 3].withValues(alpha: alpha * .6));
        default: // sparkle stars
          canvas.drawPath(starPath(p, r * 1.8, r * .6, points: 4, rotation: 0), Paint()..color = dot.withValues(alpha: alpha));
      }
    }
  }

  @override
  bool shouldRepaint(MapScenePainter old) => old.themeId != themeId;
}

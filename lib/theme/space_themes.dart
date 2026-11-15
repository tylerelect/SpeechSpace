import 'package:flutter/material.dart';

/// One selectable look for a profile. Kids and Adult profiles each get their own set.
class SpaceTheme {
  const SpaceTheme({
    required this.id,
    required this.label,
    required this.kind,
    required this.seed,
    required this.background,
    required this.icon,
    this.brightness = Brightness.light,
  });

  final String id;
  final String label;
  final String kind;
  final Color seed;
  final Color background;
  final IconData icon;
  final Brightness brightness;
}

const kidsThemes = <SpaceTheme>[
  SpaceTheme(id: 'space', label: 'Space', kind: 'kids', seed: Color(0xFF7C6CF2),
      background: Color(0xFF0E1033), icon: Icons.rocket_launch_rounded, brightness: Brightness.dark),
  SpaceTheme(id: 'ocean', label: 'Ocean', kind: 'kids', seed: Color(0xFF1E88C8),
      background: Color(0xFFEAF6FD), icon: Icons.water_rounded),
  SpaceTheme(id: 'sunshine', label: 'Sunshine', kind: 'kids', seed: Color(0xFFF2A516),
      background: Color(0xFFFFF8E6), icon: Icons.wb_sunny_rounded),
];

const adultThemes = <SpaceTheme>[
  SpaceTheme(id: 'indigo', label: 'Indigo', kind: 'adult', seed: Color(0xFF4F46E5),
      background: Color(0xFFF7F7FB), icon: Icons.circle),
  SpaceTheme(id: 'teal', label: 'Teal', kind: 'adult', seed: Color(0xFF0F8B8D),
      background: Color(0xFFF5FAFA), icon: Icons.circle),
  SpaceTheme(id: 'slate', label: 'Slate', kind: 'adult', seed: Color(0xFF475569),
      background: Color(0xFFF6F7F9), icon: Icons.circle),
];

List<SpaceTheme> themesFor(String kind) => kind == 'adult' ? adultThemes : kidsThemes;

/// Resolves a theme ID, falling back to the default for the profile kind
/// (`space` for Kids, `indigo` for Adult) when the ID is unknown or mismatched.
SpaceTheme resolveTheme(String? themeId, String kind) {
  final options = themesFor(kind);
  return options.firstWhere((t) => t.id == themeId, orElse: () => options.first);
}

ThemeData buildTheme(SpaceTheme t) {
  final dark = t.brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: t.seed, brightness: t.brightness);
  final kids = t.kind == 'kids';
  final radius = kids ? 26.0 : 14.0;
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: t.brightness);
  return base.copyWith(
    scaffoldBackgroundColor: t.background,
    appBarTheme: AppBarTheme(backgroundColor: t.background, surfaceTintColor: Colors.transparent),
    navigationRailTheme: NavigationRailThemeData(backgroundColor: t.background),
    cardTheme: CardThemeData(
      // Slightly see-through on dark so the night sky glows behind cards.
      color: dark ? const Color(0xE61A1D4A) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: dark ? const Color(0xFF2C3070) : scheme.outlineVariant.withValues(alpha: .6)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(kids ? 18 : 10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    // Kids get bigger, rounder tap targets. Both modes set the text style from the
    // same base so the theme can animate between them when switching profiles.
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      minimumSize: kids ? const Size(64, 56) : null,
      textStyle: kids
          ? base.textTheme.labelLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w700)
          : base.textTheme.labelLarge,
      shape: kids ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)) : null,
    )),
  );
}

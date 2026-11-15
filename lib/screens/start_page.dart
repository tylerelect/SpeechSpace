import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/app_controller.dart';
import '../theme/space_themes.dart';
import 'profile_setup_page.dart';

/// First screen on launch: pick an existing profile or set up a new one.
class StartPage extends StatelessWidget {
  const StartPage({super.key, required this.controller});
  final AppController controller;

  Future<void> _create(BuildContext context) async {
    final created = await openProfileSetup(context, controller);
    if (created != null) controller.enterApp(created.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profiles = controller.profiles;
    return Scaffold(body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(28), children: [
        Icon(Icons.rocket_launch_rounded, size: 56, color: theme.colorScheme.primary),
        const SizedBox(height: 14),
        Text(profiles.isEmpty ? 'Welcome to SpeechSpace' : 'Who\'s using SpeechSpace?',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(profiles.isEmpty ? 'Create a profile to get started.' : 'Choose a profile, or set up a new one.',
            textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        if (controller.demo) ...[
          const SizedBox(height: 10),
          const Center(child: Chip(label: Text('DEMO • profiles are not saved'), visualDensity: VisualDensity.compact)),
        ],
        const SizedBox(height: 28),
        LayoutBuilder(builder: (context, constraints) {
          // Fit up to 3 cards per row; scale down on narrow screens.
          const maxPerRow = 3;
          const spacing = 12.0;
          final totalSpacing = spacing * (maxPerRow - 1);
          final cardWidth = ((constraints.maxWidth - totalSpacing) / maxPerRow).clamp(100.0, 170.0);
          final cardHeight = cardWidth * 1.12;
          return Wrap(alignment: WrapAlignment.center, spacing: spacing, runSpacing: spacing, children: [
            for (final p in profiles) _ProfileCard(profile: p, onTap: () => controller.enterApp(p.id), width: cardWidth, height: cardHeight),
            _NewProfileCard(onTap: () => _create(context), width: cardWidth, height: cardHeight),
          ]);
        }),
      ]),
    ))));
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.onTap, required this.width, required this.height});
  final SpaceProfile profile;
  final VoidCallback onTap;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = resolveTheme(profile.themeId, profile.kind);
    final dark = t.brightness == Brightness.dark;
    return SizedBox(width: width, height: height, child: Card(
      color: t.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: t.seed.withValues(alpha: .5))),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: FittedBox(fit: BoxFit.scaleDown, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircleAvatar(radius: 34, backgroundColor: t.seed,
              child: Icon(profile.isKids ? Icons.rocket_launch_rounded : Icons.person_outline, size: 32, color: Colors.white)),
          const SizedBox(height: 14),
          Text(profile.name, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: dark ? Colors.white : Colors.black87)),
          const SizedBox(height: 2),
          Text('${profile.isKids ? 'Kids' : 'Adult'} • ${t.label}',
              style: TextStyle(color: dark ? Colors.white70 : Colors.black54)),
        ])),
      ),
    ));
  }
}

class _NewProfileCard extends StatelessWidget {
  const _NewProfileCard({required this.onTap, required this.width, required this.height});
  final VoidCallback onTap;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(width: width, height: height, child: Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: scheme.outlineVariant, width: 1.5)),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: FittedBox(fit: BoxFit.scaleDown, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircleAvatar(radius: 34, backgroundColor: scheme.primaryContainer,
              child: Icon(Icons.add, size: 34, color: scheme.onPrimaryContainer)),
          const SizedBox(height: 14),
          const Text('New profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text('Kids or Adult', style: TextStyle(color: scheme.onSurfaceVariant)),
        ])),
      ),
    ));
  }
}

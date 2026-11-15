import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/app_controller.dart';
import '../services/profile_questions.dart';
import '../widgets/entry_editor.dart';
import '../widgets/commander_video.dart';
import '../widgets/space_art.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final entries = controller.profileEntries;
    final copy = controller.copy;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final today = DateTime.now();
    final current = entries.where((e) => e.date.year == today.year && e.date.month == today.month && e.date.day == today.day).toList();
    final currentIds = {for (final e in current) e.id};
    final days = entries.map((e) => '${e.date.year}-${e.date.month}-${e.date.day}').toSet().length;
    final name = controller.profile?.name ?? '';

    final metrics = copy.isKids
        ? [
            _Metric(icon: Icons.star_rounded, count: '${entries.length}', label: copy.entryNounPlural, large: true),
            _Metric(icon: Icons.calendar_today_rounded, count: '$days', label: 'Days', large: true),
          ]
        : [
            _Metric(icon: Icons.book_outlined, count: '${entries.length}', label: copy.entryNounPlural),
            _Metric(icon: Icons.calendar_today_outlined, count: '$days', label: 'Days recorded'),
            _Metric(icon: Icons.hub_outlined, count: '${controller.profileLinks.length}', label: 'Connections'),
            _Metric(icon: Icons.flag_outlined, count: '${entries.where((e) => e.isMilestone).length}', label: 'Milestones'),
          ];

    final prompt = copy.isKids ? _KidsMission(controller: controller) : Card(
      child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(copy.questionLabel, style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2, color: muted)),
          const SizedBox(height: 4),
          Text(dailyQuestion(controller.profile, today, fallback: copy.question),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(copy.questionHelp, style: TextStyle(color: muted)),
        ])),
        const SizedBox(width: 12),
        FilledButton.icon(onPressed: () => openEntryEditor(context, controller),
            icon: const Icon(Icons.add), label: Text(copy.addToday)),
      ])),
    );

    return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1060), child: ListView(
      padding: const EdgeInsets.all(22), children: [
        Text(DateFormat('EEEE, MMMM d').format(today), style: TextStyle(color: muted)),
        const SizedBox(height: 6),
        Text(copy.headline, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(copy.subtitle(name), style: theme.textTheme.bodyLarge),
        const SizedBox(height: 20),
        // Adults see their numbers first; kids see the big mission card first.
        if (!copy.isKids) ...[Wrap(spacing: 12, runSpacing: 12, children: metrics), const SizedBox(height: 16)],
        prompt,
        if (copy.isKids) ...[const SizedBox(height: 16), Wrap(spacing: 12, runSpacing: 12, children: metrics)],
        const SizedBox(height: 24),
        Text(copy.todaySection, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (current.isEmpty) Card(child: Padding(padding: const EdgeInsets.all(24), child: Text(copy.todayEmpty))),
        ...current.map((e) => MemoryTile(entry: e, kids: copy.isKids, themeId: controller.spaceTheme.id, onTap: () => openEntryEditor(context, controller, entry: e))),
        const SizedBox(height: 20),
        Text(copy.recentSection, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...entries.where((e) => !currentIds.contains(e.id)).take(copy.isKids ? 3 : 5)
            .map((e) => MemoryTile(entry: e, kids: copy.isKids, themeId: controller.spaceTheme.id, onTap: () => openEntryEditor(context, controller, entry: e))),
        const SizedBox(height: 26),
      ],
    )));
  }
}

/// Big, simple Kids-mode prompt with the commander briefing.
class _KidsMission extends StatelessWidget {
  const _KidsMission({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final copy = controller.copy;
    final scheme = Theme.of(context).colorScheme;
    final t = controller.spaceTheme;
    final sound = controller.sound;
    return Card(color: scheme.primaryContainer, child: Padding(padding: const EdgeInsets.all(24), child: Wrap(
      spacing: 24, runSpacing: 20, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(width: 540, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(copy.questionLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5,
              color: scheme.onPrimaryContainer)),
          const SizedBox(height: 10),
          // Personalized from the profile's "About me" details when there are any.
          Text(dailyQuestion(controller.profile, DateTime.now(), fallback: copy.question),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800, color: scheme.onPrimaryContainer)),
          const SizedBox(height: 10),
          Text(copy.questionHelp, style: TextStyle(color: scheme.onPrimaryContainer)),
          const SizedBox(height: 18),
          Wrap(spacing: 12, runSpacing: 12, children: [
            FilledButton.icon(onPressed: () => openEntryEditor(context, controller),
                icon: const Icon(Icons.mic_rounded, size: 26), label: Text(copy.addToday)),
            ListenableBuilder(listenable: sound, builder: (context, _) => OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 56),
                  foregroundColor: scheme.onPrimaryContainer, side: BorderSide(color: scheme.onPrimaryContainer.withValues(alpha: .5))),
              onPressed: () => showCommanderBriefing(context, sound),
              icon: const Icon(Icons.smart_display_rounded),
              label: const Text('Watch the Commander'),
            )),
          ]),
        ])),
        // The hero picture follows the theme: rocket, fish or sun.
        Transform.rotate(angle: t.id == 'space' ? .35 : 0, child: SpaceArt.of(t.id, ArtRole.hero, size: 120)),
      ],
    )));
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.count, required this.label, this.large = false});
  final bool large;
  final IconData icon;
  final String count;
  final String label;

  @override
  Widget build(BuildContext context) => Card(child: SizedBox(width: large ? 200 : 166, child: Padding(
    padding: const EdgeInsets.all(17),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary, size: large ? 34 : 24),
      const SizedBox(height: 10),
      Text(count, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
      Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]),
  )));
}

class MemoryTile extends StatelessWidget {
  const MemoryTile({super.key, required this.entry, required this.onTap, this.kids = false, this.themeId = 'space'});
  final JournalEntry entry;
  final bool kids;
  final String themeId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(child: InkWell(
    borderRadius: BorderRadius.circular(20), onTap: onTap,
    child: Padding(padding: const EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      kids
          ? Padding(padding: const EdgeInsets.all(2), child: SpaceArt.of(themeId, ArtRole.sticker, size: 44))
          : Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(
              color: scheme.primaryContainer, borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.auto_stories_outlined, color: scheme.onPrimaryContainer)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Flexible(child: Text(entry.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
          if (entry.isMilestone) Padding(padding: const EdgeInsets.only(left: 8), child: Icon(Icons.flag_outlined, size: 17, color: scheme.primary)),
        ]),
        const SizedBox(height: 3),
        Text(DateFormat.yMMMd().format(entry.date), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 7),
        Text(entry.highlight.isNotEmpty ? entry.highlight : entry.body,
          maxLines: 2, overflow: TextOverflow.ellipsis),
        if (entry.tags.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Wrap(
          spacing: 6, runSpacing: 5,
          children: entry.tags.take(4).map((tag) => Chip(
            label: Text(tag), visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)).toList(),
        )),
      ])),
      const Icon(Icons.chevron_right),
    ])),
  ));
  }
}

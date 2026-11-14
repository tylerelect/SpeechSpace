import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/app_controller.dart';
import '../widgets/entry_editor.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final entries = controller.childEntries;
    final today = DateTime.now();
    final current = entries.where((e) => e.date.year == today.year && e.date.month == today.month && e.date.day == today.day).toList();
    final days = entries.map((e) => '${e.date.year}-${e.date.month}-${e.date.day}').toSet().length;
    return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1060), child: ListView(
      padding: const EdgeInsets.all(22), children: [
        Text(DateFormat('EEEE, MMMM d').format(today), style: TextStyle(color: Colors.grey.shade700)),
        const SizedBox(height: 6),
        Text('Every day tells a story.', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text('A private place to remember ${controller.child?.name ?? 'your child'}\'s little moments.',
          style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 20),
        Card(color: const Color(0xFFF0ECFF), child: Padding(padding: const EdgeInsets.all(24), child: Wrap(
          spacing: 24, runSpacing: 20, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 540, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('TODAY\'S QUESTION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
              const SizedBox(height: 10),
              Text('What was your favorite thing today?', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              const Text('Speak into the microphone or type your answer. You can always change it later.'),
              const SizedBox(height: 18),
              FilledButton.icon(onPressed: () => openEntryEditor(context, controller),
                icon: const Icon(Icons.mic_none_rounded), label: const Text('Add today\'s memory')),
            ])),
            const Icon(Icons.sunny, size: 88, color: Color(0xFFE3B958)),
          ],
        ))),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _Metric(icon: Icons.book_outlined, count: '${entries.length}', label: 'Memories'),
          _Metric(icon: Icons.calendar_today_outlined, count: '$days', label: 'Days recorded'),
          _Metric(icon: Icons.hub_outlined, count: '${controller.childLinks.length}', label: 'Connections'),
          _Metric(icon: Icons.flag_outlined, count: '${entries.where((e) => e.isMilestone).length}', label: 'Milestones'),
        ]),
        const SizedBox(height: 24),
        Text('Today\'s memories', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (current.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24),
          child: Text('No memories for today yet. Add the first one when you are ready.'))),
        ...current.map((e) => MemoryTile(entry: e, onTap: () => openEntryEditor(context, controller, entry: e))),
        const SizedBox(height: 20),
        Text('Recently remembered', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...entries.where((e) => !current.any((c) => c.id == e.id)).take(3)
            .map((e) => MemoryTile(entry: e, onTap: () => openEntryEditor(context, controller, entry: e))),
        const SizedBox(height: 26),
      ],
    )));
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.count, required this.label});
  final IconData icon;
  final String count;
  final String label;

  @override
  Widget build(BuildContext context) => Card(child: SizedBox(width: 166, child: Padding(
    padding: const EdgeInsets.all(17),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 10),
      Text(count, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
      Text(label, style: TextStyle(color: Colors.grey.shade700)),
    ]),
  )));
}

class MemoryTile extends StatelessWidget {
  const MemoryTile({super.key, required this.entry, required this.onTap});
  final JournalEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(child: InkWell(
    borderRadius: BorderRadius.circular(20), onTap: onTap,
    child: Padding(padding: const EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(
        color: const Color(0xFFEFEAFF), borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.auto_stories_outlined, color: Color(0xFF7565AF))),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Flexible(child: Text(entry.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
          if (entry.isMilestone) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.flag_outlined, size: 17, color: Color(0xFF7565AF))),
        ]),
        const SizedBox(height: 3),
        Text(DateFormat.yMMMd().format(entry.date), style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
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

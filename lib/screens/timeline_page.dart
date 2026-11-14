import 'package:flutter/material.dart';

import '../services/app_controller.dart';
import '../widgets/entry_editor.dart';
import 'today_page.dart';

class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key, required this.controller});
  final AppController controller;
  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  String _query = '';
  bool _milestonesOnly = false;

  @override
  Widget build(BuildContext context) {
    final entries = widget.controller.childEntries.where((e) {
      if (_milestonesOnly && !e.isMilestone) return false;
      final text = '${e.title} ${e.body} ${e.highlight} ${e.favorite} ${e.tags.join(' ')}'.toLowerCase();
      return text.contains(_query.toLowerCase());
    }).toList();
    return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 940), child: ListView(
      padding: const EdgeInsets.all(22), children: [
        Row(children: [
          Expanded(child: Text('Memory timeline',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800))),
          FilledButton.icon(onPressed: () => openEntryEditor(context, widget.controller),
            icon: const Icon(Icons.add), label: const Text('Add')),
        ]),
        const SizedBox(height: 6),
        const Text('Search favorite things, milestones you choose to document, and everyday stories.'),
        const SizedBox(height: 14),
        TextField(onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search memories and tags…')),
        SwitchListTile.adaptive(
          title: const Text('Show parent-marked milestones only'),
          contentPadding: EdgeInsets.zero,
          value: _milestonesOnly, onChanged: (value) => setState(() => _milestonesOnly = value)),
        const SizedBox(height: 8),
        Text('${entries.length} memories', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        if (entries.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No matching memories.'))),
        ...entries.map((e) => MemoryTile(entry: e,
            onTap: () => openEntryEditor(context, widget.controller, entry: e))),
        const SizedBox(height: 30),
      ],
    )));
  }
}

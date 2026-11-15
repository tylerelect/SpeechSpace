import 'package:flutter/material.dart';

import '../services/app_controller.dart';
import '../widgets/entry_editor.dart';
import '../widgets/project_filter.dart';
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
    final copy = widget.controller.copy;
    final query = _query.toLowerCase();
    final entries = widget.controller.profileEntries.where((e) {
      if (_milestonesOnly && !e.isMilestone) return false;
      if (query.isEmpty) return true;
      final text = '${e.title} ${e.body} ${e.highlight} ${e.favorite} ${e.tags.join(' ')}'.toLowerCase();
      return text.contains(query);
    }).toList();
    return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 940), child: ListView(
      padding: const EdgeInsets.all(22), children: [
        Row(children: [
          Expanded(child: Text(copy.isKids ? 'My stories' : 'Entries',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800))),
          FilledButton.icon(onPressed: () => openEntryEditor(context, widget.controller),
            icon: const Icon(Icons.add), label: const Text('Add')),
        ]),
        if (!copy.isKids) ...[
          const SizedBox(height: 6),
          const Text('Search, filter, and review past entries.'),
        ],
        if (!copy.isKids) Padding(padding: const EdgeInsets.only(top: 12), child: ProjectFilter(controller: widget.controller)),
        const SizedBox(height: 14),
        TextField(onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Search ${copy.entryNounPlural.toLowerCase()} and tags…')),
        SwitchListTile.adaptive(
          title: Text(copy.isKids ? 'Show parent-marked milestones only' : 'Milestones only'),
          contentPadding: EdgeInsets.zero,
          value: _milestonesOnly, onChanged: (value) => setState(() => _milestonesOnly = value)),
        const SizedBox(height: 8),
        Text('${entries.length} ${copy.entryNounPlural.toLowerCase()}', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        if (entries.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('Nothing matches yet.'))),
        ...entries.map((e) => MemoryTile(entry: e, kids: copy.isKids, themeId: widget.controller.spaceTheme.id,
            onTap: () => openEntryEditor(context, widget.controller, entry: e))),
        const SizedBox(height: 30),
      ],
    )));
  }
}

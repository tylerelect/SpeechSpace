import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/app_controller.dart';
import '../widgets/entry_editor.dart';
import 'today_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.controller});
  final AppController controller;
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = DateTime.now();

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(_month.year, _month.month, 1);
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final offset = firstDay.weekday - 1; // Monday-first calendar
    final slots = ((offset + days + 6) ~/ 7) * 7;
    final entries = widget.controller.childEntries;
    final chosen = entries.where((e) => _sameDay(e.date, _selected)).toList();

    return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 940), child: ListView(
      padding: const EdgeInsets.all(22), children: [
        Text('Calendar', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Explore memories day by day.'),
        const SizedBox(height: 18),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          Row(children: [
            IconButton(tooltip: 'Previous month', onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
              icon: const Icon(Icons.chevron_left)),
            Expanded(child: Text(DateFormat.yMMMM().format(_month), textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
            IconButton(tooltip: 'Next month', onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
              icon: const Icon(Icons.chevron_right)),
          ]),
          const SizedBox(height: 12),
          Row(children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
              .map((name) => Expanded(child: Center(child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))))).toList()),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (ctx, constraints) => GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, mainAxisSpacing: 5, crossAxisSpacing: 5,
              childAspectRatio: constraints.maxWidth < 460 ? .9 : 1.45),
            itemCount: slots,
            itemBuilder: (ctx, i) {
              final day = i - offset + 1;
              if (day < 1 || day > days) return const SizedBox.shrink();
              final date = DateTime(_month.year, _month.month, day);
              final count = entries.where((e) => _sameDay(e.date, date)).length;
              final selected = _sameDay(date, _selected);
              return InkWell(
                onTap: () => setState(() => _selected = date),
                borderRadius: BorderRadius.circular(12),
                child: Container(decoration: BoxDecoration(
                  color: selected ? Theme.of(context).colorScheme.primaryContainer : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade200)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('$day', style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                    if (count > 0) Container(margin: const EdgeInsets.only(top: 4), width: 7, height: 7,
                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle)),
                  ])),
              );
            },
          )),
        ]))),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: Text(DateFormat('MMMM d, yyyy').format(_selected),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
          FilledButton.tonalIcon(onPressed: () => openEntryEditor(context, widget.controller, date: _selected),
            icon: const Icon(Icons.add), label: const Text('Memory')),
        ]),
        const SizedBox(height: 10),
        if (chosen.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No memories on this day.'))),
        ...chosen.map((e) => MemoryTile(entry: e,
          onTap: () => openEntryEditor(context, widget.controller, entry: e))),
      ],
    )));
  }
}

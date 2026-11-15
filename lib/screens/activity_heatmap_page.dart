import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/activity.dart';
import '../models/models.dart';
import '../services/app_controller.dart';
import '../widgets/project_filter.dart';

/// GitHub-contributions-style map of the days on which the active profile
/// recorded entries, over the last 365 days. Counts come from the already
/// loaded, profile- (and project-) filtered snapshot entries; no new endpoint.
/// It shows how many notes were written, never a score or an assessment.
class ActivityHeatmapPage extends StatefulWidget {
  const ActivityHeatmapPage({super.key, required this.controller, required this.onOpenDay, this.clock = DateTime.now});
  final AppController controller;

  /// Opens the Day calendar view for the given date.
  final ValueChanged<DateTime> onOpenDay;

  /// Injectable "now" for tests.
  final DateTime Function() clock;

  @override
  State<ActivityHeatmapPage> createState() => _ActivityHeatmapPageState();
}

class _ActivityHeatmapPageState extends State<ActivityHeatmapPage> {
  DateTime? _selected;
  String? _selectionScope;

  static const cell = 13.0;
  static const gap = 3.0;
  static const dayLabelWidth = 30.0;

  AppController get _c => widget.controller;

  // Building the 53-week grid is the costliest part of this page; reuse it
  // while the entries and the current day are unchanged (e.g. when a tap only
  // changes the selected day).
  ActivityHeatmap? _map;
  (List<JournalEntry>, DateTime)? _mapKey;

  ActivityHeatmap _heatmap() {
    final now = widget.clock();
    final key = (_c.profileEntries, DateTime(now.year, now.month, now.day));
    if (key != _mapKey) {
      _mapKey = key;
      _map = ActivityHeatmap.compute(key.$1, key.$2);
    }
    return _map!;
  }

  @override
  Widget build(BuildContext context) {
    // A selection never carries over to another profile or project.
    final scope = '${_c.selectedProfileId}|${_c.selectedProjectId}';
    if (scope != _selectionScope) {
      _selectionScope = scope;
      _selected = null;
    }
    final map = _heatmap();
    final theme = Theme.of(context);
    final copy = _c.copy;
    final noun = copy.isKids ? 'stories' : 'entries';
    final selectedDay = _selected == null ? null : map.dayFor(_selected!);

    return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1000), child: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text(copy.navActivity, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(copy.isKids
            ? 'Each square is a day. Stronger colors mean more stories that day.'
            : 'Days with saved entries over the last 365 days. Stronger colors mean more entries that day.'),
        if (!copy.isKids) ...[const SizedBox(height: 12), ProjectFilter(controller: _c)],
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _Counter(key: const ValueKey('activity-active-days'), icon: Icons.calendar_today_outlined,
              value: map.activeDays, label: 'Active days'),
          _Counter(key: const ValueKey('activity-entry-count'), icon: Icons.book_outlined,
              value: map.entryCount, label: copy.isKids ? 'Stories' : 'Entries'),
          _Counter(key: const ValueKey('activity-milestone-count'), icon: Icons.flag_outlined,
              value: map.milestoneCount, label: 'Milestones'),
        ]),
        const SizedBox(height: 14),
        Card(child: Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 10), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${DateFormat.yMMMd().format(map.start)} - ${DateFormat.yMMMd().format(map.end)}',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            // Scrolls horizontally on narrow screens; starts at the newest week.
            // Weekday labels stay pinned; the weeks scroll horizontally on
            // narrow screens, starting at the newest week.
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _DayLabels(),
              Expanded(child: SingleChildScrollView(
                key: const ValueKey('activity-scroll'),
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: _Grid(map: map, selected: _selected, onSelect: _select, noun: noun),
              )),
            ]),
            const SizedBox(height: 10),
            _Legend(),
          ],
        ))),
        const SizedBox(height: 12),
        _DetailCard(
          day: selectedDay,
          noun: noun,
          onOpen: selectedDay == null ? null : () => widget.onOpenDay(selectedDay.date),
        ),
        const SizedBox(height: 12),
        _TextSummary(map: map, noun: noun),
        const SizedBox(height: 24),
      ],
    )));
  }

  void _select(DateTime date) {
    if (_selected == date) return;
    setState(() => _selected = date);
  }
}

class _Counter extends StatelessWidget {
  const _Counter({super.key, required this.icon, required this.value, required this.label});
  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('$value', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          Text(label, style: theme.textTheme.bodySmall),
        ]),
      ],
    )));
  }
}

/// Theme-derived bucket colors: a neutral empty square, then the profile's
/// primary color at increasing strength. Placeholders are transparent.
Color heatColor(ColorScheme scheme, int bucket) => switch (bucket) {
      0 => scheme.onSurface.withValues(alpha: .09),
      1 => scheme.primary.withValues(alpha: .32),
      2 => scheme.primary.withValues(alpha: .52),
      3 => scheme.primary.withValues(alpha: .76),
      _ => scheme.primary,
    };

String _dayLabel(ActivityDay d, String noun) {
  final n = d.entryCount;
  final m = d.milestoneCount;
  final entries = n == 1 ? '1 ${noun == 'stories' ? 'story' : 'entry'}' : '$n $noun';
  return '${DateFormat('EEEE, MMMM d, y').format(d.date)}: $entries, $m ${m == 1 ? 'milestone' : 'milestones'}';
}

class _Grid extends StatelessWidget {
  const _Grid({required this.map, required this.selected, required this.onSelect, required this.noun});
  final ActivityHeatmap map;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;
  final String noun;

  static const step = _ActivityHeatmapPageState.cell + _ActivityHeatmapPageState.gap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.labelSmall;
    final weeks = map.weeks;

    // Month label above the first week column whose Monday is in a new month;
    // skip a label that would collide with the previous one.
    final labels = <int, String>{};
    var last = -3;
    for (var c = 0; c < weeks.length; c++) {
      final monday = weeks[c].first.date;
      final isNew = c == 0 || monday.month != weeks[c - 1].first.date.month;
      if (isNew && c - last >= 3) {
        labels[c] = DateFormat.MMM().format(c == 0 ? map.start : monday);
        last = c;
      }
    }

    return Semantics(
      container: true,
      label: 'Activity heat map, ${weeks.length} weeks, Monday to Sunday rows',
      child: FocusTraversalGroup(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: _monthRow, width: weeks.length * step, child: Stack(children: [
          for (final e in labels.entries)
            Positioned(left: e.key * step, top: 0, child: ExcludeSemantics(child: Text(e.value, style: small))),
        ])),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final week in weeks) Column(children: [
            for (final day in week) Padding(
              padding: const EdgeInsets.only(right: _ActivityHeatmapPageState.gap, bottom: _ActivityHeatmapPageState.gap),
              child: day.inRange
                  ? _Cell(day: day, selected: selected == day.date, color: heatColor(scheme, day.bucket),
                      outline: scheme.onSurface, label: _dayLabel(day, noun), onSelect: onSelect)
                  : const SizedBox(width: _ActivityHeatmapPageState.cell, height: _ActivityHeatmapPageState.cell),
            ),
          ]),
        ]),
      ])),
    );
  }
}

const _monthRow = 16.0;

/// Mon / Wed / Fri / Sun row labels, aligned with the grid rows.
class _DayLabels extends StatelessWidget {
  const _DayLabels();

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10);
    return ExcludeSemantics(child: SizedBox(width: _ActivityHeatmapPageState.dayLabelWidth, child: Column(children: [
      const SizedBox(height: _monthRow),
      for (final label in const ['Mon', '', 'Wed', '', 'Fri', '', 'Sun'])
        SizedBox(height: _Grid.step, child: Align(alignment: Alignment.centerLeft, child: Text(label, style: small))),
    ])));
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.day, required this.selected, required this.color, required this.outline,
      required this.label, required this.onSelect});
  final ActivityDay day;
  final bool selected;
  final Color color;
  final Color outline;
  final String label;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        waitDuration: const Duration(milliseconds: 400),
        excludeFromSemantics: true,
        child: InkWell(
          key: ValueKey('heat-${isoDay(day.date)}'),
          borderRadius: BorderRadius.circular(3),
          onTap: () => onSelect(day.date),
          // Keyboard users select a day by moving focus to it (Tab / arrows).
          onFocusChange: (focused) { if (focused) onSelect(day.date); },
          child: Container(
            width: _ActivityHeatmapPageState.cell,
            height: _ActivityHeatmapPageState.cell,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
              border: selected ? Border.all(color: outline, width: 2) : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.labelSmall;
    return Semantics(
      label: 'Legend: squares get stronger in color for 0, 1, 2, 3 to 4, and 5 or more entries per day',
      child: ExcludeSemantics(child: Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('Less', style: small),
        for (var b = 0; b < 5; b++) Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: heatColor(scheme, b),
              borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 3),
          Text(activityBucketLabels[b], style: small),
        ]),
        Text('More', style: small),
      ])),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.day, required this.noun, required this.onOpen});
  final ActivityDay? day;
  final String noun;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = day;
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: d == null
        ? Text('Tap a square (or move keyboard focus onto one) to see that day.', style: theme.textTheme.bodyMedium)
        : Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(DateFormat('EEEE, MMMM d, y').format(d.date), key: const ValueKey('activity-selected-date'),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('${d.entryCount} ${d.entryCount == 1 ? (noun == 'stories' ? 'story' : 'entry') : noun} - '
                  '${d.milestoneCount} ${d.milestoneCount == 1 ? 'milestone' : 'milestones'}',
                  key: const ValueKey('activity-selected-counts')),
            ])),
            FilledButton.tonalIcon(onPressed: onOpen, icon: const Icon(Icons.today_outlined),
                label: const Text('Open in calendar')),
          ])));
  }
}

/// Text alternative to the colors: totals, the busiest day, and per-month counts.
class _TextSummary extends StatelessWidget {
  const _TextSummary({required this.map, required this.noun});
  final ActivityHeatmap map;
  final String noun;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busiest = map.busiest;
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Summary', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        if (map.entryCount == 0)
          Text('No $noun recorded in the last 365 days yet.', key: const ValueKey('activity-empty'))
        else ...[
          Text('${map.entryCount} $noun on ${map.activeDays} ${map.activeDays == 1 ? 'day' : 'days'} in the last '
              '365 days, with ${map.milestoneCount} marked ${map.milestoneCount == 1 ? 'milestone' : 'milestones'}.',
              key: const ValueKey('activity-summary-text')),
          if (busiest != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(
              'Most $noun on one day: ${busiest.entryCount} (${DateFormat.yMMMd().format(busiest.date)}).')),
          const SizedBox(height: 10),
          Wrap(spacing: 14, runSpacing: 4, children: [
            for (final m in map.months.reversed)
              Text('${DateFormat.yMMM().format(m.month)}: ${m.entryCount}', style: theme.textTheme.bodySmall),
          ]),
        ],
        const SizedBox(height: 8),
        Text('Counts of saved notes only - not a score or an assessment.', style: theme.textTheme.bodySmall),
      ],
    )));
  }
}

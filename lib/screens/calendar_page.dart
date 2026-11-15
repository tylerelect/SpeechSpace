import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/calendar.dart';
import '../models/models.dart';
import '../services/app_controller.dart';
import '../services/repository.dart' show ApiException;
import '../widgets/entry_editor.dart';
import '../widgets/project_filter.dart';
import 'today_page.dart';

/// Day / Week / Month / Year calendar for the active profile (and project),
/// with an on-demand recap. Navigation never calls the AI.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.controller});
  final AppController controller;
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  // View and date live in the controller so navigation survives tab switches
  // and other screens (the Activity heat map) can open a specific day.
  CalendarView get _view => _c.calendarView;
  DateTime get _date => _c.calendarDate;

  // Loaded data is tagged with the request it answers; anything else is stale.
  String? _loadedKey;
  String? _loadingKey;
  CalendarData? _data;
  String? _loadError;

  String? _summaryKey;
  CalendarSummary? _summary;
  bool _summaryLoading = false;
  String? _summaryError;

  AppController get _c => widget.controller;

  String get _key {
    final period = CalendarPeriod.of(_view, _date);
    return [_c.selectedProfileId, _c.calendarProjectId, _view.wire, isoDay(period.start), _c.revision].join('|');
  }

  void _ensureLoaded({bool force = false}) {
    final key = _key;
    if (!force && (key == _loadedKey || key == _loadingKey)) return;
    final profileId = _c.selectedProfileId;
    if (profileId == null) return;
    _loadingKey = key;
    final view = _view;
    final date = _date;
    final projectId = _c.calendarProjectId;
    _c.calendar(view, date).then((data) {
      if (!mounted || _loadingKey != key) return;
      setState(() { _data = data; _loadedKey = key; _loadError = null; _loadingKey = null; });
    }, onError: (Object error) {
      if (!mounted || _loadingKey != key) return;
      // Keep saved entries visible: fall back to the entries already loaded.
      setState(() {
        _data = CalendarData.compute(profileId: profileId, view: view, date: date,
            projectId: projectId, allEntries: _c.entries);
        _loadedKey = key;
        _loadingKey = null;
        _loadError = calendarErrorMessage(error, loading: true);
      });
    });
  }

  void _retryLoad() => setState(() => _ensureLoaded(force: true));

  // The controller notifies listeners, and the shell rebuilds this page.
  void _go(CalendarView view, DateTime date) => _c.setCalendar(view, date);

  Future<void> _generateSummary() async {
    final key = _key;
    setState(() { _summaryKey = key; _summaryLoading = true; _summaryError = null; _summary = null; });
    try {
      final summary = await _c.calendarSummary(_view, _date);
      if (!mounted || _summaryKey != key) return;
      setState(() => _summary = summary);
    } catch (error) {
      if (!mounted || _summaryKey != key) return;
      setState(() => _summaryError = calendarErrorMessage(error));
    } finally {
      if (mounted && _summaryKey == key) setState(() => _summaryLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _ensureLoaded();
    final key = _key;
    final copy = _c.copy;
    final theme = Theme.of(context);
    final period = CalendarPeriod.of(_view, _date);
    // Only show data that answers the current request (no flashing of old data).
    final data = _loadedKey == key ? _data : null;
    final summaryCurrent = _summaryKey == key;

    return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 980), child: ListView(
      padding: const EdgeInsets.all(22), children: [
        Row(children: [
          Expanded(child: Text(copy.navCalendar, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800))),
          FilledButton.tonalIcon(onPressed: () => openEntryEditor(context, _c, date: _view == CalendarView.day ? _date : DateTime.now()),
              icon: const Icon(Icons.add), label: Text(copy.isKids ? 'Story' : 'Entry')),
        ]),
        const SizedBox(height: 12),
        if (!copy.isKids) ...[ProjectFilter(controller: _c), const SizedBox(height: 12)],
        SegmentedButton<CalendarView>(
          segments: [for (final v in CalendarView.values) ButtonSegment(value: v, label: Text(v.label))],
          selected: {_view},
          onSelectionChanged: (v) => _go(v.first, _date),
        ),
        const SizedBox(height: 12),
        Row(children: [
          IconButton(tooltip: 'Previous', onPressed: () => _go(_view, shiftDate(_view, _date, -1)), icon: const Icon(Icons.chevron_left)),
          Expanded(child: Text(period.label, textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
          TextButton(onPressed: () => _go(_view, DateTime.now()), child: const Text('Today')),
          IconButton(tooltip: 'Next', onPressed: () => _go(_view, shiftDate(_view, _date, 1)), icon: const Icon(Icons.chevron_right)),
        ]),
        if (_loadError != null && data != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
          Icon(Icons.cloud_off_outlined, size: 18, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(child: Text('$_loadError Showing entries already loaded.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error))),
          TextButton(onPressed: _retryLoad, child: const Text('Retry')),
        ])),
        if (data == null)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else ...[
          _Counts(data: data, kids: copy.isKids),
          const SizedBox(height: 12),
          switch (_view) {
            CalendarView.day => const SizedBox.shrink(),
            CalendarView.week => _WeekStrip(data: data, onDay: (d) => _go(CalendarView.day, d)),
            CalendarView.month => _MonthGrid(data: data, selected: _date, onDay: (d) => _go(CalendarView.day, d)),
            CalendarView.year => _YearGrid(data: data, onMonth: (m) => _go(CalendarView.month, m)),
          },
          const SizedBox(height: 14),
          _SummaryCard(
            view: _view,
            summary: summaryCurrent ? _summary : null,
            loading: summaryCurrent && _summaryLoading,
            error: summaryCurrent ? _summaryError : null,
            hasEntries: data.entryCount > 0,
            onGenerate: _generateSummary,
          ),
          const SizedBox(height: 16),
          if (_view != CalendarView.year) ...[
            Text(copy.entryNounPlural, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (data.entries.isEmpty)
              Card(child: Padding(padding: const EdgeInsets.all(18),
                  child: Text('No ${copy.entryNounPlural.toLowerCase()} in this ${_view.wire}.'))),
            ...data.entries.map((e) => MemoryTile(entry: e, kids: copy.isKids,
                onTap: () => openEntryEditor(context, _c, entry: e))),
            if (data.truncated) Padding(padding: const EdgeInsets.only(top: 6),
                child: Text('Partial list: showing the newest ${data.returnedCount} of ${data.entryCount}.',
                    key: const ValueKey('calendar-truncated'), style: theme.textTheme.bodySmall)),
          ],
        ],
        const SizedBox(height: 24),
      ],
    )));
  }
}

class _Counts extends StatelessWidget {
  const _Counts({required this.data, required this.kids});
  final CalendarData data;
  final bool kids;

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String value, String label) => Expanded(child: Card(child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      child: Row(children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ]),
      ]),
    )));
    return Row(children: [
      item(Icons.book_outlined, '${data.entryCount}', kids ? 'Stories' : 'Entries'),
      item(Icons.calendar_today_outlined, '${data.activeDays}', 'Active days'),
      item(Icons.flag_outlined, '${data.milestoneCount}', 'Milestones'),
    ]);
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.data, required this.onDay});
  final CalendarData data;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final start = data.period.start;
    return Card(child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [
      for (var i = 0; i < 7; i++) Builder(builder: (context) {
        final day = DateTime(start.year, start.month, start.day + i);
        final count = data.countFor(day);
        return Expanded(child: InkWell(
          key: ValueKey('week-day-${isoDay(day)}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => onDay(day),
          child: Container(
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: count != null ? scheme.primaryContainer : scheme.primary.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Text(DateFormat.E().format(day), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              Text('${day.day}'),
              const SizedBox(height: 4),
              Text('${count?.entryCount ?? 0}', key: ValueKey('week-count-${isoDay(day)}'),
                  style: TextStyle(fontWeight: FontWeight.w800, color: scheme.primary)),
              if ((count?.milestoneCount ?? 0) > 0) Icon(Icons.flag, size: 14, color: scheme.primary),
            ]),
          ),
        ));
      }),
    ])));
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.data, required this.selected, required this.onDay});
  final CalendarData data;
  final DateTime selected;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final first = data.period.start;
    final days = DateTime(first.year, first.month + 1, 0).day;
    final offset = first.weekday - 1; // Monday-first
    final slots = ((offset + days + 6) ~/ 7) * 7;
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
      Row(children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
          .map((n) => Expanded(child: Center(child: Text(n, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))))).toList()),
      const SizedBox(height: 8),
      LayoutBuilder(builder: (ctx, constraints) => GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 5, crossAxisSpacing: 5,
            childAspectRatio: constraints.maxWidth < 460 ? .9 : 1.45),
        itemCount: slots,
        itemBuilder: (ctx, i) {
          final dayNum = i - offset + 1;
          if (dayNum < 1 || dayNum > days) return const SizedBox.shrink();
          final date = DateTime(first.year, first.month, dayNum);
          final count = data.countFor(date);
          final isSelected = date.year == selected.year && date.month == selected.month && date.day == selected.day;
          return InkWell(
            key: ValueKey('month-day-${isoDay(date)}'),
            onTap: () => onDay(date),
            borderRadius: BorderRadius.circular(12),
            child: Container(decoration: BoxDecoration(
              color: isSelected ? scheme.primaryContainer : scheme.primary.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? scheme.primary : scheme.outlineVariant)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('$dayNum', style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                if (count != null) Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(margin: const EdgeInsets.only(top: 4), width: 7, height: 7,
                      decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle)),
                  if (count.milestoneCount > 0) Padding(padding: const EdgeInsets.only(left: 3, top: 3),
                      child: Icon(Icons.flag, size: 11, color: scheme.primary)),
                ]),
              ])),
          );
        },
      )),
    ])));
  }
}

class _YearGrid extends StatelessWidget {
  const _YearGrid({required this.data, required this.onMonth});
  final CalendarData data;
  final ValueChanged<DateTime> onMonth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final year = data.period.start.year;
    return GridView.count(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.sizeOf(context).width < 600 ? 3 : 4, childAspectRatio: 1.6,
      mainAxisSpacing: 8, crossAxisSpacing: 8,
      children: [
        for (var m = 1; m <= 12; m++) Builder(builder: (context) {
          final inMonth = data.days.where((d) => d.date.month == m);
          final entries = inMonth.fold<int>(0, (sum, d) => sum + d.entryCount);
          final milestones = inMonth.fold<int>(0, (sum, d) => sum + d.milestoneCount);
          return Card(
            color: entries > 0 ? scheme.primaryContainer : null,
            child: InkWell(
              key: ValueKey('year-month-$m'),
              borderRadius: BorderRadius.circular(16),
              onTap: () => onMonth(DateTime(year, m)),
              child: Padding(padding: const EdgeInsets.all(10), child: Column(
                mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(DateFormat.MMM().format(DateTime(year, m)), style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('$entries', key: ValueKey('year-count-$m'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  if (milestones > 0) Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.flag, size: 13, color: scheme.primary), Text(' $milestones', style: const TextStyle(fontSize: 12)),
                  ]),
                ],
              )),
            ),
          );
        }),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.view, required this.summary, required this.loading, required this.error,
      required this.hasEntries, required this.onGenerate});
  final CalendarView view;
  final CalendarSummary? summary;
  final bool loading;
  final String? error;
  final bool hasEntries;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = summary;
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.auto_awesome, color: theme.colorScheme.tertiary),
        const SizedBox(width: 8),
        Expanded(child: Text(summaryTitle(view), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
        if (loading)
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
        else
          FilledButton.tonal(onPressed: onGenerate, child: Text(s == null && error == null ? 'Generate summary' : 'Regenerate')),
      ]),
      if (s == null && error == null && !loading) Padding(padding: const EdgeInsets.only(top: 8), child: Text(
          hasEntries ? 'Tap Generate summary for a factual recap of this ${view.wire}. Nothing is saved.'
              : 'No entries recorded for this ${view.wire}.',
          style: theme.textTheme.bodySmall)),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [
        Expanded(child: Text(error!, style: TextStyle(color: theme.colorScheme.error))),
        TextButton(onPressed: onGenerate, child: const Text('Retry')),
      ])),
      if (s != null) ...[
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, children: [
          if (s.demo) const Chip(label: Text('Demo recap (not Gemini)'), visualDensity: VisualDensity.compact),
          if (s.partial) Chip(visualDensity: VisualDensity.compact,
              label: Text('Based on a sample of entries • ${s.analyzedEntries} of ${s.entryCount} analyzed')),
        ]),
        const SizedBox(height: 6),
        Text(s.summary),
        if (s.highlights.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Highlights', style: theme.textTheme.labelLarge),
          for (final h in s.highlights) Padding(padding: const EdgeInsets.only(top: 3), child: Text('• $h')),
        ],
        if (s.themes.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final t in s.themes) Chip(label: Text(t), visualDensity: VisualDensity.compact)]),
        ],
        if (s.milestones.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Milestones you marked', style: theme.textTheme.labelLarge),
          for (final m in s.milestones) Padding(padding: const EdgeInsets.only(top: 3), child: Text('⚑ $m')),
        ],
        const SizedBox(height: 10),
        // Factual counts come from saved entries, kept apart from the generated text.
        Text('Saved data: ${s.entryCount} ${s.entryCount == 1 ? 'entry' : 'entries'} • ${s.activeDays} active '
            '${s.activeDays == 1 ? 'day' : 'days'} • ${s.milestoneCount} marked '
            '${s.milestoneCount == 1 ? 'milestone' : 'milestones'}'
            '${s.generated ? ' • ${s.analyzedEntries} analyzed' : ''}.',
            key: const ValueKey('summary-counts'), style: theme.textTheme.bodySmall),
        Text('A recap of what was written, not an assessment. Not saved.', style: theme.textTheme.bodySmall),
      ],
    ])));
  }
}

/// Short, recoverable messages for calendar and recap failures. Saved entries
/// stay visible in every case.
String calendarErrorMessage(Object error, {bool loading = false}) {
  if (error is ApiException) {
    switch (error.statusCode) {
      case 503:
        return loading ? 'The calendar service is not available right now.'
            : 'Recaps need Gemini to be set up on the backend (GEMINI_API_KEY).';
      case 502:
        return 'Gemini could not create a recap right now. Try again in a moment.';
      case 401:
        return 'The app is not authorized with the backend (check DEV_API_TOKEN).';
      case 504:
        return 'The backend took too long to answer. Try again.';
    }
    return error.message;
  }
  final text = error.toString().replaceFirst('Bad state: ', '');
  if (text.contains('SocketException') || text.contains('ClientException') || text.contains('TimeoutException') ||
      text.contains('Failed host lookup') || text.contains('XMLHttpRequest')) {
    return 'Could not reach the backend. You seem to be offline.';
  }
  return text;
}

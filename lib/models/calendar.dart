import 'package:intl/intl.dart';

import 'models.dart';

/// Calendar views supported by `GET /api/calendar`.
enum CalendarView { day, week, month, year }

extension CalendarViewName on CalendarView {
  String get wire => name;
  String get label => switch (this) {
        CalendarView.day => 'Day',
        CalendarView.week => 'Week',
        CalendarView.month => 'Month',
        CalendarView.year => 'Year',
      };
}

/// Inclusive [start], exclusive [endExclusive]; weeks run Monday–Sunday.
class CalendarPeriod {
  const CalendarPeriod({required this.start, required this.endExclusive, required this.label});
  final DateTime start;
  final DateTime endExclusive;
  final String label;

  bool contains(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(start) && d.isBefore(endExclusive);
  }

  factory CalendarPeriod.of(CalendarView view, DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    switch (view) {
      case CalendarView.day:
        return CalendarPeriod(start: d, endExclusive: DateTime(d.year, d.month, d.day + 1),
            label: DateFormat('EEEE, MMMM d, y').format(d));
      case CalendarView.week:
        final start = DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));
        final end = DateTime(start.year, start.month, start.day + 7);
        final last = DateTime(end.year, end.month, end.day - 1);
        return CalendarPeriod(start: start, endExclusive: end,
            label: '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d, y').format(last)}');
      case CalendarView.month:
        return CalendarPeriod(start: DateTime(d.year, d.month), endExclusive: DateTime(d.year, d.month + 1),
            label: DateFormat('MMMM y').format(d));
      case CalendarView.year:
        return CalendarPeriod(start: DateTime(d.year), endExclusive: DateTime(d.year + 1), label: '${d.year}');
    }
  }

  factory CalendarPeriod.fromJson(Map<String, dynamic> json) => CalendarPeriod(
        start: parseCalendarDay(json['start'] as String),
        endExclusive: parseCalendarDay(json['endExclusive'] as String),
        label: (json['label'] as String?) ?? '',
      );
}

/// Moves [date] one period forward (+1) or back (-1) for [view].
DateTime shiftDate(CalendarView view, DateTime date, int step) => switch (view) {
      CalendarView.day => DateTime(date.year, date.month, date.day + step),
      CalendarView.week => DateTime(date.year, date.month, date.day + 7 * step),
      // Clamp the day so Jan 31 → Feb 28/29 rather than overflowing into March.
      CalendarView.month => _clampDay(date.year, date.month + step, date.day),
      CalendarView.year => _clampDay(date.year + step, date.month, date.day),
    };

DateTime _clampDay(int year, int month, int day) {
  final first = DateTime(year, month);
  final lastDay = DateTime(first.year, first.month + 1, 0).day;
  return DateTime(first.year, first.month, day > lastDay ? lastDay : day);
}

class CalendarDayCount {
  const CalendarDayCount({required this.date, required this.entryCount, required this.milestoneCount});
  final DateTime date;
  final int entryCount;
  final int milestoneCount;

  factory CalendarDayCount.fromJson(Map<String, dynamic> json) => CalendarDayCount(
        date: parseCalendarDay(json['date'] as String),
        entryCount: (json['entryCount'] as num?)?.toInt() ?? 0,
        milestoneCount: (json['milestoneCount'] as num?)?.toInt() ?? 0,
      );
}

/// Response of `GET /api/calendar`.
class CalendarData {
  const CalendarData({
    required this.profileId,
    required this.view,
    required this.projectId,
    required this.period,
    required this.entryCount,
    required this.activeDays,
    required this.milestoneCount,
    required this.days,
    required this.entries,
    required this.truncated,
  });

  final String profileId;
  final CalendarView view;
  final String projectId;
  final CalendarPeriod period;
  final int entryCount;
  final int activeDays;
  final int milestoneCount;
  final List<CalendarDayCount> days;
  /// Newest first; at most 200 (see [truncated]).
  final List<JournalEntry> entries;
  final bool truncated;

  CalendarDayCount? countFor(DateTime day) {
    for (final d in days) {
      if (d.date.year == day.year && d.date.month == day.month && d.date.day == day.day) return d;
    }
    return null;
  }

  /// Builds the same shape the backend returns, from local entries (demo mode
  /// and tests). Uses the same rules: inclusive/exclusive period, cap of 200.
  factory CalendarData.compute({
    required String profileId,
    required CalendarView view,
    required DateTime date,
    required String projectId,
    required Iterable<JournalEntry> allEntries,
  }) {
    final period = CalendarPeriod.of(view, date);
    final matching = allEntries
        .where((e) => e.childId == profileId && (projectId.isEmpty || e.projectId == projectId) && period.contains(e.date))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final byDay = <String, List<JournalEntry>>{};
    for (final e in matching) { byDay.putIfAbsent(isoDay(e.date), () => []).add(e); }
    final keys = byDay.keys.toList()..sort();
    return CalendarData(
      profileId: profileId,
      view: view,
      projectId: projectId,
      period: period,
      entryCount: matching.length,
      activeDays: keys.length,
      milestoneCount: matching.where((e) => e.isMilestone).length,
      days: [for (final k in keys) CalendarDayCount(date: parseCalendarDay(k), entryCount: byDay[k]!.length,
          milestoneCount: byDay[k]!.where((e) => e.isMilestone).length)],
      entries: matching.take(maxCalendarEntries).toList(),
      truncated: matching.length > maxCalendarEntries,
    );
  }

  factory CalendarData.fromJson(Map<String, dynamic> json) => CalendarData(
        profileId: json['profileId'] as String,
        view: CalendarView.values.firstWhere((v) => v.wire == json['view'], orElse: () => CalendarView.month),
        projectId: (json['projectId'] as String?) ?? '',
        period: CalendarPeriod.fromJson(Map<String, dynamic>.from(json['period'] as Map)),
        entryCount: (json['entryCount'] as num?)?.toInt() ?? 0,
        activeDays: (json['activeDays'] as num?)?.toInt() ?? 0,
        milestoneCount: (json['milestoneCount'] as num?)?.toInt() ?? 0,
        days: ((json['days'] as List?) ?? []).map((e) => CalendarDayCount.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        entries: ((json['entries'] as List?) ?? []).map((e) => JournalEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        truncated: (json['truncated'] as bool?) ?? false,
      );
}

const maxCalendarEntries = 200;
const maxSummaryEntries = 40;

/// Response of `POST /api/calendar/summary`. Never saved.
class CalendarSummary {
  const CalendarSummary({
    required this.period,
    required this.entryCount,
    required this.activeDays,
    required this.milestoneCount,
    required this.generated,
    required this.partial,
    required this.analyzedEntries,
    required this.summary,
    required this.highlights,
    required this.themes,
    required this.milestones,
    this.demo = false,
  });

  final CalendarPeriod period;
  final int entryCount;
  final int activeDays;
  final int milestoneCount;
  final bool generated;
  final bool partial;
  final int analyzedEntries;
  final String summary;
  final List<String> highlights;
  final List<String> themes;
  final List<String> milestones;
  /// True for offline demo recaps (not from Gemini).
  final bool demo;

  static List<String> _strings(Object? v) => ((v as List?) ?? []).map((e) => e.toString()).toList();

  factory CalendarSummary.fromJson(Map<String, dynamic> json) => CalendarSummary(
        period: CalendarPeriod.fromJson(Map<String, dynamic>.from(json['period'] as Map)),
        entryCount: (json['entryCount'] as num?)?.toInt() ?? 0,
        activeDays: (json['activeDays'] as num?)?.toInt() ?? 0,
        milestoneCount: (json['milestoneCount'] as num?)?.toInt() ?? 0,
        generated: (json['generated'] as bool?) ?? false,
        partial: (json['partial'] as bool?) ?? false,
        analyzedEntries: (json['analyzedEntries'] as num?)?.toInt() ?? 0,
        summary: (json['summary'] as String?) ?? '',
        highlights: _strings(json['highlights']),
        themes: _strings(json['themes']),
        milestones: _strings(json['milestones']),
      );
}

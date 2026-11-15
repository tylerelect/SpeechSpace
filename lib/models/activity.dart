import 'models.dart';

/// One square of the Activity heat map.
class ActivityDay {
  const ActivityDay({required this.date, required this.entryCount, required this.milestoneCount, required this.inRange});

  final DateTime date;
  final int entryCount;
  final int milestoneCount;

  /// False for the alignment placeholders before the 365-day range starts and
  /// after today. Placeholders are never counted or colored.
  final bool inRange;

  /// 0 = none, 1 = one entry, 2 = two, 3 = three to four, 4 = five or more.
  int get bucket => activityBucket(entryCount);
}

/// Default color buckets: `0`, `1`, `2`, `3–4`, `5+`.
int activityBucket(int count) {
  if (count <= 0) return 0;
  if (count == 1) return 1;
  if (count == 2) return 2;
  if (count <= 4) return 3;
  return 4;
}

const activityBucketLabels = ['0', '1', '2', '3–4', '5+'];

/// Factual per-month totals, used for the text alternative to the colors.
class ActivityMonth {
  const ActivityMonth({required this.month, required this.entryCount, required this.activeDays});
  final DateTime month;
  final int entryCount;
  final int activeDays;
}

/// GitHub-contributions-style grid of the days on which entries were recorded:
/// a rolling [days]-day window ending today, 7 rows (Monday–Sunday) by up to
/// 53 week columns.
///
/// Entries are bucketed by the recorded calendar day (the first 10 ISO
/// characters, see [parseCalendarDay]); there is no timezone conversion. The
/// caller passes entries already filtered to the active profile (and project).
/// Counts are numbers of notes, not a score of any kind.
class ActivityHeatmap {
  ActivityHeatmap._({
    required this.start,
    required this.end,
    required this.weeks,
    required this.entryCount,
    required this.activeDays,
    required this.milestoneCount,
    required this.busiest,
    required this.months,
  });

  static const days = 365;

  /// First day in range (inclusive).
  final DateTime start;

  /// Today (inclusive). Future days are never in range.
  final DateTime end;

  /// Week columns, oldest first; each has exactly 7 days, Monday first.
  final List<List<ActivityDay>> weeks;
  final int entryCount;
  final int activeDays;
  final int milestoneCount;

  /// The day with the most entries (earliest on ties), or null if none.
  final ActivityDay? busiest;

  /// Months overlapping the range, oldest first.
  final List<ActivityMonth> months;

  factory ActivityHeatmap.compute(Iterable<JournalEntry> entries, DateTime today) {
    final end = DateTime(today.year, today.month, today.day);
    // Calendar arithmetic (not Duration) so DST changes never skip a day.
    final start = DateTime(end.year, end.month, end.day - (days - 1));
    final startKey = isoDay(start);
    final endKey = isoDay(end);

    final counts = <String, int>{};
    final milestones = <String, int>{};
    for (final e in entries) {
      final key = isoDay(e.date);
      // ISO day strings compare chronologically.
      if (key.compareTo(startKey) < 0 || key.compareTo(endKey) > 0) continue;
      counts[key] = (counts[key] ?? 0) + 1;
      if (e.isMilestone) milestones[key] = (milestones[key] ?? 0) + 1;
    }

    final gridStart = DateTime(start.year, start.month, start.day - (start.weekday - DateTime.monday));
    final weeks = <List<ActivityDay>>[];
    ActivityDay? busiest;
    for (var w = 0;; w++) {
      final monday = DateTime(gridStart.year, gridStart.month, gridStart.day + 7 * w);
      if (monday.isAfter(end)) break;
      final week = <ActivityDay>[];
      for (var d = 0; d < 7; d++) {
        final date = DateTime(monday.year, monday.month, monday.day + d);
        final key = isoDay(date);
        final inRange = !date.isBefore(start) && !date.isAfter(end);
        final day = ActivityDay(
          date: date,
          inRange: inRange,
          entryCount: inRange ? (counts[key] ?? 0) : 0,
          milestoneCount: inRange ? (milestones[key] ?? 0) : 0,
        );
        final top = busiest;
        if (day.entryCount > 0 && (top == null || day.entryCount > top.entryCount)) busiest = day;
        week.add(day);
      }
      weeks.add(week);
    }

    final months = <ActivityMonth>[];
    for (var m = DateTime(start.year, start.month); !m.isAfter(end); m = DateTime(m.year, m.month + 1)) {
      final prefix = isoDay(m).substring(0, 8); // YYYY-MM-
      final keys = counts.keys.where((k) => k.startsWith(prefix));
      months.add(ActivityMonth(month: m, entryCount: keys.fold(0, (sum, k) => sum + counts[k]!), activeDays: keys.length));
    }

    return ActivityHeatmap._(
      start: start,
      end: end,
      weeks: weeks,
      entryCount: counts.values.fold(0, (a, b) => a + b),
      activeDays: counts.length,
      milestoneCount: milestones.values.fold(0, (a, b) => a + b),
      busiest: busiest,
      months: months,
    );
  }

  /// The in-range day for [date], or null if it is outside the window.
  ActivityDay? dayFor(DateTime date) {
    for (final week in weeks) {
      for (final d in week) {
        if (d.inRange && d.date.year == date.year && d.date.month == date.month && d.date.day == date.day) return d;
      }
    }
    return null;
  }
}

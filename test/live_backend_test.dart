// Opt-in end-to-end test against a running backend (authenticated, real HTTP).
// Skipped unless both defines are given, so `flutter test` and CI never touch
// a server. Use an isolated development database with synthetic data only:
//
//   flutter test test/live_backend_test.dart \
//     --dart-define=LIVE_API_BASE_URL=http://127.0.0.1:8000 \
//     --dart-define=LIVE_DEV_TOKEN=<local dev token>
//
// Optional: --dart-define=LIVE_GEMINI=on when the backend has Gemini (or a
// stub) configured; otherwise the summary/ideas checks expect HTTP 503.
//
// The test creates its own profiles and deletes them at the end.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speechspace/models/activity.dart';
import 'package:speechspace/models/calendar.dart';
import 'package:speechspace/models/models.dart';
import 'package:speechspace/services/app_controller.dart';
import 'package:speechspace/services/repository.dart';

const baseUrl = String.fromEnvironment('LIVE_API_BASE_URL');
const token = String.fromEnvironment('LIVE_DEV_TOKEN');
const gemini = String.fromEnvironment('LIVE_GEMINI') == 'on';

void main() {
  final skip = baseUrl.isEmpty || token.isEmpty ? 'Set LIVE_API_BASE_URL and LIVE_DEV_TOKEN to run' : null;
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('full loop: profiles, six themes, restart, projects, entries, calendar, summary, links', () async {
    RemoteRepository repo() => RemoteRepository(baseUrl: baseUrl, devToken: token);
    final c = AppController(repo());
    await c.initialize();
    final kid = await c.addProfile('Live Kid ${DateTime.now().microsecondsSinceEpoch}', SpaceProfile.kids);
    final adult = await c.addProfile('Live Adult ${DateTime.now().microsecondsSinceEpoch}', SpaceProfile.adult);
    try {
      // Themes: PATCH each of the six, verify through a fresh snapshot.
      c.enterApp(kid.id);
      for (final t in ['ocean', 'sunshine']) { await c.setTheme(t); }
      c.selectProfile(adult.id);
      for (final t in ['teal', 'slate']) { await c.setTheme(t); }
      final snap = await repo().load();
      expect(snap.children.firstWhere((p) => p.id == kid.id).themeId, 'sunshine');
      expect(snap.children.firstWhere((p) => p.id == adult.id).themeId, 'slate');
      await expectLater(repo().updateProfile(kid.copyWith(themeId: 'slate')),
          throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 422)));

      // Restart restores the selected profile and its theme.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final restarted = AppController(repo());
      await restarted.initialize();
      expect(restarted.selectedProfileId, adult.id);
      expect(restarted.spaceTheme.id, 'slate');

      // Projects + entries: the Nov 9 / 14 / 16, 2026 fixture, duplicated on the Kids profile.
      final project = await c.addProject('Garden');
      Future<JournalEntry> add(String profile, DateTime d, {String projectId = '', bool milestone = false}) =>
          c.saveEntry(JournalEntry(id: '', childId: profile, date: d, title: 'Live ${isoDay(d)}', body: 'Synthetic.',
              projectId: projectId, isMilestone: milestone));
      final n09 = await add(adult.id, DateTime(2026, 11, 9));
      final n14 = await add(adult.id, DateTime(2026, 11, 14), projectId: project.id, milestone: true);
      await add(adult.id, DateTime(2026, 11, 16));
      for (final d in [9, 14, 16]) { await add(kid.id, DateTime(2026, 11, d)); }

      final r = repo();
      final week = await r.calendar(adult.id, CalendarView.week, DateTime(2026, 11, 14));
      expect(week.period.start, DateTime(2026, 11, 9));
      expect(week.period.endExclusive, DateTime(2026, 11, 16));
      expect(week.entryCount, 2);
      expect(week.returnedCount, 2);
      expect(week.milestoneCount, 1);
      expect(week.entries.every((e) => e.childId == adult.id), isTrue);
      expect((await r.calendar(adult.id, CalendarView.month, DateTime(2026, 11))).entryCount, 3);
      expect((await r.calendar(adult.id, CalendarView.year, DateTime(2026))).entryCount, 3);
      expect((await r.calendar(adult.id, CalendarView.day, DateTime(2026, 11, 10))).entryCount, 0);
      expect((await r.calendar(kid.id, CalendarView.month, DateTime(2026, 11))).entryCount, 3);
      final filtered = await r.calendar(adult.id, CalendarView.month, DateTime(2026, 11), projectId: project.id);
      expect(filtered.entries.map((e) => e.id), [n14.id]);
      await expectLater(r.calendar(kid.id, CalendarView.month, DateTime(2026, 11), projectId: project.id),
          throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 422)));

      // Controller path, exactly as the calendar page calls it.
      c.setCalendar(CalendarView.week, DateTime(2026, 11, 14));
      expect((await c.calendar(c.calendarView, c.calendarDate)).entryCount, 2);

      // Summary: explicit POST only; empty period never calls Gemini.
      final empty = await r.calendarSummary(adult.id, CalendarView.day, DateTime(2026, 11, 10));
      expect(empty.generated, isFalse);
      if (gemini) {
        final s = await r.calendarSummary(adult.id, CalendarView.week, DateTime(2026, 11, 14));
        expect(s.generated, isTrue);
        expect(s.analyzedEntries, 2);
        expect(s.sourceEntryIds.toSet(), {n09.id, n14.id});
        expect(s.milestones, ['Live 2026-11-14']);
        expect((await repo().load()).entries.where((e) => e.childId == adult.id), hasLength(3), reason: 'not saved');
        final ideas = await r.expand(adult.id, [n09.id, n14.id], kind: SpaceProfile.adult);
        expect(ideas, isNotEmpty);
        expect(ideas.every((i) => i.sourceIds.every({n09.id, n14.id}.contains)), isTrue);
      } else {
        await expectLater(r.calendarSummary(adult.id, CalendarView.week, DateTime(2026, 11, 14)),
            throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 503)));
      }

      // Heat map uses the snapshot's profile-filtered entries.
      final map = ActivityHeatmap.compute(c.profileEntries, DateTime(2026, 11, 16));
      expect([map.entryCount, map.activeDays, map.milestoneCount], [3, 3, 1]);

      // Links: create, duplicate rejected, survives reload; deleting a project keeps entries.
      await c.addLink(n09.id, n14.id, 'same week');
      await expectLater(r.addLink(MemoryLink(id: '', childId: adult.id, fromId: n14.id, toId: n09.id)),
          throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)));
      await c.deleteProject(project.id);
      final after = await repo().load();
      expect(after.links.where((l) => l.childId == adult.id), hasLength(1));
      expect(after.entries.firstWhere((e) => e.id == n14.id).projectId, '');
    } finally {
      for (final id in [kid.id, adult.id]) {
        try { await repo().deleteChild(id); } catch (_) {}
      }
    }
    final cleaned = await repo().load();
    expect(cleaned.children.any((p) => p.id == kid.id || p.id == adult.id), isFalse);
    expect(cleaned.entries.any((e) => e.childId == kid.id || e.childId == adult.id), isFalse);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));
}

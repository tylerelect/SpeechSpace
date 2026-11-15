import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speechspace/models/calendar.dart';
import 'package:speechspace/models/models.dart';
import 'package:speechspace/screens/calendar_page.dart';
import 'package:speechspace/services/app_controller.dart';
import 'package:speechspace/services/repository.dart';

import 'support/fake_backend.dart';

/// Synthetic fixture from the handoff: entries on Nov 9, 14 and 16, 2026 for
/// profile `a1`, the same dates duplicated on profile `k1`.
FakeBackend fixture() {
  final b = FakeBackend();
  b.addEntry('a1', '2026-11-09', id: 'n09', title: 'Nov 9 note');
  b.addEntry('a1', '2026-11-14', id: 'n14', title: 'Nov 14 note', milestone: true);
  b.addEntry('a1', '2026-11-16', id: 'n16', title: 'Nov 16 note');
  for (final d in ['2026-11-09', '2026-11-14', '2026-11-16']) {
    b.addEntry('k1', d, title: 'Kid $d');
  }
  return b;
}

Future<AppController> remote(FakeBackend b, {String profile = 'a1'}) async {
  final c = AppController(RemoteRepository(baseUrl: 'http://test', devToken: 't', client: b.client), persistSelection: false);
  await c.initialize();
  c.enterApp(profile);
  return c;
}

Future<void> pumpCalendar(WidgetTester tester, AppController c, {Size size = const Size(1100, 2600)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ListenableBuilder(listenable: c, builder: (_, _) => MaterialApp(
      theme: c.theme, home: Scaffold(body: CalendarPage(controller: c)))));
  await tester.pumpAndSettle();
}

int weekCount(WidgetTester tester, String day) =>
    int.parse(tester.widget<Text>(find.byKey(ValueKey('week-count-$day'))).data!);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('fixture through the remote API', () {
    test('week of Nov 14 is Nov 9-15 and excludes Nov 16; month and year include all three', () async {
      final b = fixture();
      final repo = RemoteRepository(baseUrl: 'http://test', devToken: 't', client: b.client);
      final week = await repo.calendar('a1', CalendarView.week, DateTime(2026, 11, 14));
      expect(week.period.start, DateTime(2026, 11, 9));
      expect(week.period.endExclusive, DateTime(2026, 11, 16));
      expect(week.entries.map((e) => e.id), ['n14', 'n09']); // newest first, Nov 16 excluded
      expect(week.entryCount, 2);
      expect(week.activeDays, 2);
      expect(week.milestoneCount, 1);
      expect(week.returnedCount, 2);

      final month = await repo.calendar('a1', CalendarView.month, DateTime(2026, 11, 14));
      expect(month.entryCount, 3);
      expect(month.days.map((d) => isoDay(d.date)), ['2026-11-09', '2026-11-14', '2026-11-16']);
      final year = await repo.calendar('a1', CalendarView.year, DateTime(2026, 11, 14));
      expect(year.entryCount, 3);
      // Profile k1 has the same three dates; none of them leak into a1.
      expect([...week.entries, ...month.entries, ...year.entries].every((e) => e.childId == 'a1'), isTrue);
      final kid = await repo.calendar('k1', CalendarView.month, DateTime(2026, 11, 14));
      expect(kid.entryCount, 3);
      expect(kid.entries.every((e) => e.childId == 'k1'), isTrue);
    });

    test('a blank day and an empty month return zero counts', () async {
      final repo = RemoteRepository(baseUrl: 'http://test', devToken: 't', client: fixture().client);
      final blank = await repo.calendar('a1', CalendarView.day, DateTime(2026, 11, 10));
      expect(blank.entryCount, 0);
      expect(blank.entries, isEmpty);
      expect(blank.days, isEmpty);
      final october = await repo.calendar('a1', CalendarView.month, DateTime(2026, 10));
      expect(october.entryCount, 0);
      expect(october.activeDays, 0);
    });

    test('Monday/Sunday boundaries', () async {
      final b = fixture();
      final repo = RemoteRepository(baseUrl: 'http://test', devToken: 't', client: b.client);
      final sunday = await repo.calendar('a1', CalendarView.week, DateTime(2026, 11, 15));
      expect(sunday.period.start, DateTime(2026, 11, 9)); // Sunday belongs to the week that began Monday
      final monday = await repo.calendar('a1', CalendarView.week, DateTime(2026, 11, 16));
      expect(monday.period.start, DateTime(2026, 11, 16));
      expect(monday.entries.map((e) => e.id), ['n16']);
      // Client-side period math agrees.
      expect(CalendarPeriod.of(CalendarView.week, DateTime(2026, 11, 15)).start, DateTime(2026, 11, 9));
      expect(CalendarPeriod.of(CalendarView.week, DateTime(2026, 11, 16)).start, DateTime(2026, 11, 16));
    });

    test('December/January rollover', () async {
      final b = FakeBackend();
      b.addEntry('a1', '2026-12-28', id: 'dec28');
      b.addEntry('a1', '2026-12-31', id: 'dec31');
      b.addEntry('a1', '2027-01-03', id: 'jan03');
      b.addEntry('a1', '2027-01-04', id: 'jan04');
      final repo = RemoteRepository(baseUrl: 'http://test', devToken: 't', client: b.client);
      final week = await repo.calendar('a1', CalendarView.week, DateTime(2026, 12, 31));
      expect(week.period.start, DateTime(2026, 12, 28));
      expect(week.period.endExclusive, DateTime(2027, 1, 4));
      expect(week.entries.map((e) => e.id), ['jan03', 'dec31', 'dec28']);
      expect((await repo.calendar('a1', CalendarView.month, DateTime(2026, 12))).entryCount, 2);
      expect((await repo.calendar('a1', CalendarView.year, DateTime(2027, 6))).entryCount, 2);
      expect(shiftDate(CalendarView.month, DateTime(2026, 12, 15), 1), DateTime(2027, 1, 15));
      expect(shiftDate(CalendarView.day, DateTime(2026, 12, 31), 1), DateTime(2027));
      final local = CalendarData.compute(profileId: 'a1', view: CalendarView.week, date: DateTime(2026, 12, 31),
          projectId: '', allEntries: b.entries.map(JournalEntry.fromJson));
      expect(local.entries.map((e) => e.id), ['jan03', 'dec31', 'dec28']);
    });

    test('leap day lands in February 2028 and its week', () async {
      final b = FakeBackend();
      b.addEntry('a1', '2028-02-29', id: 'leap');
      final repo = RemoteRepository(baseUrl: 'http://test', devToken: 't', client: b.client);
      final feb = await repo.calendar('a1', CalendarView.month, DateTime(2028, 2));
      expect(feb.entries.single.date, DateTime(2028, 2, 29));
      final week = await repo.calendar('a1', CalendarView.week, DateTime(2028, 3));
      expect(week.period.start, DateTime(2028, 2, 28));
      expect(week.entryCount, 1);
      expect((await repo.calendar('a1', CalendarView.month, DateTime(2028, 3))).entryCount, 0);
    });

    test('a late-evening timestamp stays on its stored day', () async {
      final b = FakeBackend();
      b.addEntry('a1', '2026-11-14', id: 'late', time: 'T23:30:00-08:00');
      final repo = RemoteRepository(baseUrl: 'http://test', devToken: 't', client: b.client);
      final day = await repo.calendar('a1', CalendarView.day, DateTime(2026, 11, 14));
      expect(day.entries.single.date, DateTime(2026, 11, 14));
      expect(isoDay(day.days.single.date), '2026-11-14');
    });

    test('Adult project filter narrows counts; Kids are always profile-wide', () async {
      final b = fixture();
      b.projects.add({'id': 'garden', 'profileId': 'a1', 'name': 'Garden'});
      b.addEntry('a1', '2026-11-14', id: 'g1', project: 'garden');
      b.addEntry('k1', '2026-11-14', id: 'kp', project: 'stray'); // synthetic: Kids rows ignore projects
      final c = await remote(b);
      c.setCalendar(CalendarView.month, DateTime(2026, 11, 14));
      expect((await c.calendar(c.calendarView, c.calendarDate)).entryCount, 4);
      c.selectProject('garden');
      final filtered = await c.calendar(c.calendarView, c.calendarDate);
      expect(filtered.entries.map((e) => e.id), ['g1']);
      expect(b.requests.last, contains('projectId=garden'));

      c.selectProfile('k1');
      expect(c.calendarProjectId, '');
      c.setCalendar(CalendarView.month, DateTime(2026, 11, 14));
      expect((await c.calendar(c.calendarView, c.calendarDate)).entryCount, 4);
      expect(Uri.parse(b.requests.last.split(' ').last).queryParameters['projectId'], '',
          reason: 'Kids requests never carry a project filter');
    });

    test('summary contract: counts, sample flags, source IDs', () async {
      final b = fixture();
      final repo = RemoteRepository(baseUrl: 'http://test', devToken: 't', client: b.client);
      final s = await repo.calendarSummary('a1', CalendarView.week, DateTime(2026, 11, 14));
      expect(s.generated, isTrue);
      expect(s.partial, isFalse);
      expect(s.analyzedEntries, 2);
      expect(s.sourceEntryIds, ['n14', 'n09']);
      expect(s.milestones, ['Nov 14 note']);
      final empty = await repo.calendarSummary('a1', CalendarView.day, DateTime(2026, 11, 10));
      expect(empty.generated, isFalse);
      expect(empty.summary, 'No entries recorded for this day.');
    });
  });

  group('calendar UI', () {
    testWidgets('navigation: segmented views, Previous/Next/Today, and tap-to-drill', (tester) async {
      final c = await remote(fixture());
      c.setCalendar(CalendarView.week, DateTime(2026, 11, 14));
      await pumpCalendar(tester, c);

      expect(find.text('Nov 9 - Nov 15, 2026'), findsOneWidget);
      expect(weekCount(tester, '2026-11-09'), 1);
      expect(weekCount(tester, '2026-11-14'), 1);
      expect(weekCount(tester, '2026-11-15'), 0);
      expect(find.text('Nov 16 note'), findsNothing);
      expect(find.text('Weekly recap'), findsOneWidget);

      await tester.tap(find.byTooltip('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Nov 16 - Nov 22, 2026'), findsOneWidget);
      expect(find.text('Nov 16 note'), findsOneWidget);
      await tester.tap(find.byTooltip('Previous'));
      await tester.pumpAndSettle();

      // Week → Day
      await tester.tap(find.byKey(const ValueKey('week-day-2026-11-14')));
      await tester.pumpAndSettle();
      expect(c.calendarView, CalendarView.day);
      expect(find.text('Saturday, November 14, 2026'), findsOneWidget);
      expect(find.text('Nov 14 note'), findsOneWidget);
      expect(find.text('Day summary'), findsOneWidget);
      await tester.tap(find.byTooltip('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Sunday, November 15, 2026'), findsOneWidget);
      expect(find.text('No entries in this day.'), findsOneWidget); // blank day

      // Year → Month → Day
      await tester.tap(find.text('Year'));
      await tester.pumpAndSettle();
      expect(find.text('Year in review'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('year-count-11'))).data, '3');
      expect(tester.widget<Text>(find.byKey(const ValueKey('year-count-10'))).data, '0');
      await tester.tap(find.byKey(const ValueKey('year-month-11')));
      await tester.pumpAndSettle();
      expect(c.calendarView, CalendarView.month);
      expect(find.text('November 2026'), findsOneWidget);
      expect(find.text('Monthly recap'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('month-day-2026-11-16')));
      await tester.pumpAndSettle();
      expect(find.text('Monday, November 16, 2026'), findsOneWidget);
      expect(find.text('Nov 16 note'), findsOneWidget);

      // Today works from every view.
      final now = DateTime.now();
      for (final view in ['Day', 'Week', 'Month', 'Year']) {
        await tester.tap(find.text(view));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Today'));
        await tester.pumpAndSettle();
        expect(c.calendarDate, DateTime(now.year, now.month, now.day));
      }
    });

    testWidgets('navigation never asks for a summary; Generate is explicit', (tester) async {
      final b = fixture();
      final c = await remote(b);
      c.setCalendar(CalendarView.month, DateTime(2026, 11, 14));
      await pumpCalendar(tester, c);
      for (final v in ['Day', 'Week', 'Year', 'Month']) {
        await tester.tap(find.text(v));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Next'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Previous'));
        await tester.pumpAndSettle();
      }
      expect(b.count('POST /api/calendar/summary'), 0);
      await tester.tap(find.text('Generate summary'));
      await tester.pumpAndSettle();
      expect(b.count('POST /api/calendar/summary'), 1);
      expect(find.text('Recorded 3 entries.'), findsOneWidget);
      expect(find.text('- Recorded activity'), findsOneWidget);
      expect(find.text('Activities'), findsOneWidget);
      expect(find.text('⚑ Nov 14 note'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('summary-counts'))).data,
          'Saved data: 3 entries - 3 active days - 1 marked milestone - 3 analyzed.');
    });

    testWidgets('Gemini failure (502) keeps entries and offers Retry', (tester) async {
      final b = fixture()..summaryStatus = 502;
      final c = await remote(b);
      c.setCalendar(CalendarView.month, DateTime(2026, 11, 14));
      await pumpCalendar(tester, c);
      await tester.tap(find.text('Generate summary'));
      await tester.pumpAndSettle();
      expect(find.text('Gemini could not create a recap right now. Try again in a moment.'), findsOneWidget);
      expect(find.text('Nov 14 note'), findsOneWidget); // saved entries still shown
      b.summaryStatus = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Recorded 3 entries.'), findsOneWidget);
    });

    testWidgets('no Gemini key (503) is explained; entries remain', (tester) async {
      final c = await remote(fixture()..summaryStatus = 503);
      c.setCalendar(CalendarView.week, DateTime(2026, 11, 14));
      await pumpCalendar(tester, c);
      await tester.tap(find.text('Generate summary'));
      await tester.pumpAndSettle();
      expect(find.text('Recaps need Gemini to be set up on the backend (GEMINI_API_KEY).'), findsOneWidget);
      expect(find.text('Nov 9 note'), findsOneWidget);
    });

    testWidgets('offline: calendar falls back to loaded entries; summary error is retryable', (tester) async {
      final b = fixture();
      final c = await remote(b);
      b.offlinePrefix = '/api/calendar';
      c.setCalendar(CalendarView.month, DateTime(2026, 11, 14));
      await pumpCalendar(tester, c);
      expect(find.textContaining('Could not reach the backend'), findsOneWidget);
      expect(find.text('Nov 9 note'), findsOneWidget);
      expect(find.text('Nov 16 note'), findsOneWidget);
      expect(find.text('Kid 2026-11-09'), findsNothing); // fallback is still profile-scoped

      await tester.tap(find.text('Generate summary'));
      await tester.pumpAndSettle();
      expect(find.text('Could not reach the backend. You seem to be offline.'), findsWidgets);

      b.offlinePrefix = null;
      await tester.tap(find.text('Retry').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Showing entries already loaded'), findsNothing);
    });

    testWidgets('partial:true shows the sample label and analyzed/total counts', (tester) async {
      final b = FakeBackend();
      for (var i = 0; i < 45; i++) {
        b.addEntry('a1', '2026-03-${(1 + i % 28).toString().padLeft(2, '0')}');
      }
      final c = await remote(b);
      c.setCalendar(CalendarView.year, DateTime(2026, 3));
      await pumpCalendar(tester, c);
      await tester.tap(find.text('Generate summary'));
      await tester.pumpAndSettle();
      expect(find.text('Based on a sample of entries - 40 of 45 analyzed'), findsOneWidget);
    });

    testWidgets('truncated:true says the list is partial', (tester) async {
      final b = FakeBackend()..calendarCap = 5;
      for (var i = 1; i <= 8; i++) {
        b.addEntry('a1', '2026-11-${i.toString().padLeft(2, '0')}');
      }
      final c = await remote(b);
      c.setCalendar(CalendarView.month, DateTime(2026, 11, 14));
      await pumpCalendar(tester, c);
      expect(tester.widget<Text>(find.byKey(const ValueKey('calendar-truncated'))).data,
          'Partial list: showing the newest 5 of 8.');
    });

    testWidgets('editing or deleting an entry reloads counts and drops the old recap', (tester) async {
      final b = fixture();
      final c = await remote(b);
      c.setCalendar(CalendarView.week, DateTime(2026, 11, 14));
      await pumpCalendar(tester, c);
      await tester.tap(find.text('Generate summary'));
      await tester.pumpAndSettle();
      expect(find.text('Recorded 2 entries.'), findsOneWidget);
      final loads = b.count('GET /api/calendar');

      await c.saveEntry(JournalEntry(id: '', childId: 'a1', date: DateTime(2026, 11, 15), title: 'Added', body: 'x'));
      await tester.pumpAndSettle();
      expect(b.count('GET /api/calendar'), loads + 1);
      expect(weekCount(tester, '2026-11-15'), 1);
      expect(find.text('Recorded 2 entries.'), findsNothing, reason: 'stale recap must not survive an edit');
      expect(find.text('Generate summary'), findsOneWidget);

      await c.deleteEntry(c.entries.firstWhere((e) => e.id == 'n09'));
      await tester.pumpAndSettle();
      expect(weekCount(tester, '2026-11-09'), 0);
      expect(find.text('Nov 9 note'), findsNothing);
    });

    testWidgets('a slow response for the previous profile never shows up', (tester) async {
      final b = fixture();
      final gate = RequestGate();
      final c = await remote(b);
      c.setCalendar(CalendarView.month, DateTime(2026, 11, 14));
      // Hold a1's calendar response while we switch to k1.
      b.beforeRespond = (req) async {
        if (req.url.path == '/api/calendar' && req.url.queryParameters['profileId'] == 'a1') await gate.wait();
      };
      tester.view.physicalSize = const Size(1100, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ListenableBuilder(listenable: c, builder: (_, _) => MaterialApp(
          theme: c.theme, home: Scaffold(body: CalendarPage(controller: c)))));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      c.selectProfile('k1');
      c.setCalendar(CalendarView.month, DateTime(2026, 11, 14));
      await tester.pumpAndSettle();
      expect(find.text('Kid 2026-11-14'), findsOneWidget);

      gate.release(); // a1's late answer arrives
      await tester.pumpAndSettle();
      expect(find.text('Nov 14 note'), findsNothing);
      expect(find.text('Kid 2026-11-14'), findsOneWidget);
    });

    testWidgets('switching profile resets calendar view and date', (tester) async {
      final c = await remote(fixture());
      c.setCalendar(CalendarView.year, DateTime(2025, 2, 3));
      c.selectProfile('k1');
      final now = DateTime.now();
      expect(c.calendarView, CalendarView.month);
      expect(c.calendarDate, DateTime(now.year, now.month, now.day));
    });

    test('error messages map status codes', () {
      expect(calendarErrorMessage(const ApiException(503, 'x')), contains('GEMINI_API_KEY'));
      expect(calendarErrorMessage(const ApiException(503, 'x'), loading: true), contains('calendar service'));
      expect(calendarErrorMessage(const ApiException(502, 'x')), contains('Try again'));
      expect(calendarErrorMessage(const ApiException(422, 'Project must belong to the selected profile.')),
          'Project must belong to the selected profile.');
      expect(calendarErrorMessage(Exception('SocketException: refused')), contains('offline'));
    });
  });

  group('recap layout', () {
    testWidgets('kids recap keeps parent and kid guidance in separate boxes; no footer, no dots', (tester) async {
      final b = fixture()..summaryBody = {
        'summary': 'Floated on his back for the first time.',
        'highlights': ['Swim lesson', 'Ice cream after'],
        'forParents': ['Says the deep end is scary - try short visits together.'],
        'forKid': ['You floated! Try counting to ten next time.'],
      };
      final c = await remote(b, profile: 'k1');
      c.setCalendar(CalendarView.week, DateTime(2026, 11, 14));
      await pumpCalendar(tester, c, size: const Size(393, 2400));
      await tester.tap(find.text('Generate summary'));
      await tester.pumpAndSettle();
      final parents = find.byKey(const ValueKey('summary-for-parents'));
      final kid = find.byKey(const ValueKey('summary-for-kid'));
      expect(find.descendant(of: parents, matching: find.text('For parents')), findsOneWidget);
      expect(find.descendant(of: parents, matching: find.text('- Says the deep end is scary - try short visits together.')), findsOneWidget);
      expect(find.descendant(of: kid, matching: find.text('For Kid')), findsOneWidget);
      expect(find.descendant(of: kid, matching: find.text('- You floated! Try counting to ten next time.')), findsOneWidget);
      expect(find.descendant(of: parents, matching: find.textContaining('You floated')), findsNothing);
      expect(find.text('- Swim lesson'), findsOneWidget);
      expect(find.textContaining('not an assessment'), findsNothing);
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        expect(t.data ?? '', isNot(matches(RegExp('[\u2022\u00b7\u2013\u2014]'))));
      }
    });

    testWidgets('year in review lists months with short bullets', (tester) async {
      final b = fixture()..summaryBody = {
        'summary': 'Learned to swim.',
        'highlights': ['Should not show in year view'],
        'months': [
          {'month': 'November', 'items': ['First swim lesson', 'Halloween', 'Met a puppy']},
        ],
      };
      final c = await remote(b, profile: 'k1');
      c.setCalendar(CalendarView.year, DateTime(2026, 11, 14));
      await pumpCalendar(tester, c);
      await tester.tap(find.text('Generate summary'));
      await tester.pumpAndSettle();
      expect(find.text('November:'), findsOneWidget);
      for (final item in ['First swim lesson', 'Halloween', 'Met a puppy']) {
        expect(find.text('- $item'), findsOneWidget);
      }
      expect(find.textContaining('Should not show'), findsNothing);
    });

    testWidgets('adult recap never shows the kid sections', (tester) async {
      final b = fixture()..summaryBody = {'summary': 'Notes.', 'forParents': ['x'], 'forKid': ['y']};
      final c = await remote(b);
      c.setCalendar(CalendarView.week, DateTime(2026, 11, 14));
      await pumpCalendar(tester, c);
      await tester.tap(find.text('Generate summary'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('summary-for-parents')), findsNothing);
      expect(find.byKey(const ValueKey('summary-for-kid')), findsNothing);
    });
  });
}

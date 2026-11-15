import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speechspace/main.dart';
import 'package:speechspace/models/activity.dart';
import 'package:speechspace/models/calendar.dart';
import 'package:speechspace/models/models.dart';
import 'package:speechspace/screens/activity_heatmap_page.dart';
import 'package:speechspace/services/app_controller.dart';
import 'package:speechspace/services/repository.dart';

import 'support/fake_backend.dart';

JournalEntry e(String id, DateTime date, {String profile = 'p', bool milestone = false}) =>
    JournalEntry(id: id, childId: profile, date: date, title: 'T$id', body: 'b', isMilestone: milestone);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ActivityHeatmap.compute', () {
    final today = DateTime(2026, 11, 15); // a Sunday

    test('zero entries: 365 empty in-range days, zero counts, Monday-first 53 weeks', () {
      final map = ActivityHeatmap.compute(const [], today);
      expect(map.start, DateTime(2025, 11, 16));
      expect(map.end, today);
      expect(map.weeks, hasLength(53));
      expect(map.weeks.every((w) => w.length == 7), isTrue);
      expect(map.weeks.every((w) => w.first.date.weekday == DateTime.monday), isTrue);
      final inRange = map.weeks.expand((w) => w).where((d) => d.inRange).toList();
      expect(inRange, hasLength(365));
      expect(inRange.every((d) => d.entryCount == 0 && d.bucket == 0), isTrue);
      expect([map.entryCount, map.activeDays, map.milestoneCount], [0, 0, 0]);
      expect(map.busiest, isNull);
    });

    test('buckets: 0, 1, 2, 3-4, 5+', () {
      expect([0, 1, 2, 3, 4, 5, 9].map(activityBucket), [0, 1, 2, 3, 3, 4, 4]);
      expect(activityBucketLabels, ['0', '1', '2', '3-4', '5+']);
    });

    test('several notes on one day count as notes, but one active day', () {
      final map = ActivityHeatmap.compute([
        e('1', DateTime(2026, 11, 14)),
        e('2', DateTime(2026, 11, 14), milestone: true),
        e('3', DateTime(2026, 11, 14)),
        e('4', DateTime(2026, 11, 9)),
      ], today);
      expect(map.entryCount, 4);
      expect(map.activeDays, 2);
      expect(map.milestoneCount, 1);
      final day = map.dayFor(DateTime(2026, 11, 14))!;
      expect(day.entryCount, 3);
      expect(day.milestoneCount, 1);
      expect(day.bucket, 3);
      expect(map.busiest!.date, DateTime(2026, 11, 14));
    });

    test('365 days ending today: older and future entries are excluded', () {
      final map = ActivityHeatmap.compute([
        e('old', DateTime(2025, 11, 15)), // 365 days ago: just outside
        e('first', DateTime(2025, 11, 16)), // first day in range
        e('today', today),
        e('future', DateTime(2026, 11, 16)),
      ], today);
      expect(map.entryCount, 2);
      expect(map.dayFor(DateTime(2025, 11, 15)), isNull);
      expect(map.dayFor(DateTime(2026, 11, 16)), isNull);
      // Alignment placeholders never carry counts.
      final placeholders = map.weeks.expand((w) => w).where((d) => !d.inRange);
      expect(placeholders.every((d) => d.entryCount == 0), isTrue);
      expect(placeholders.any((d) => d.date == DateTime(2025, 11, 15)), isTrue);
    });

    test('today sits in the last column at its weekday row; no future day is in range', () {
      final wednesday = DateTime(2026, 11, 11);
      final map = ActivityHeatmap.compute(const [], wednesday);
      final last = map.weeks.last;
      expect(last[2].date, wednesday);
      expect(last[2].inRange, isTrue);
      expect(last.sublist(3).every((d) => !d.inRange), isTrue);
    });

    test('month and year rollover', () {
      final map = ActivityHeatmap.compute([
        e('a', DateTime(2026, 12, 31)),
        e('b', DateTime(2027)),
        e('c', DateTime(2027)),
      ], DateTime(2027, 1, 2));
      expect(map.dayFor(DateTime(2026, 12, 31))!.entryCount, 1);
      expect(map.dayFor(DateTime(2027))!.entryCount, 2);
      final months = {for (final m in map.months) isoDay(m.month): m.entryCount};
      expect(months['2026-12-01'], 1);
      expect(months['2027-01-01'], 2);
      expect(map.months.first.month, DateTime(2026));
    });

    test('leap day', () {
      final map = ActivityHeatmap.compute([e('leap', DateTime(2028, 2, 29))], DateTime(2028, 3));
      expect(map.start, DateTime(2027, 3, 3));
      expect(map.dayFor(DateTime(2028, 2, 29))!.entryCount, 1);
      expect(map.weeks.expand((w) => w).where((d) => d.inRange), hasLength(365));
    });

    test('stored dates are bucketed by their first 10 characters (no timezone shift)', () {
      final late = JournalEntry.fromJson({'id': 'x', 'childId': 'p', 'date': '2026-11-14T23:30:00-08:00'});
      final map = ActivityHeatmap.compute([late], today);
      expect(map.dayFor(DateTime(2026, 11, 14))!.entryCount, 1);
      expect(map.dayFor(DateTime(2026, 11, 15))!.entryCount, 0);
    });
  });

  group('Activity page', () {
    final today = DateTime(2026, 11, 15);

    Future<AppController> remoteController(FakeBackend b) async {
      final c = AppController(RemoteRepository(baseUrl: 'http://test', devToken: 't', client: b.client), persistSelection: false);
      await c.initialize();
      return c;
    }

    Future<List<DateTime>> pumpPage(WidgetTester tester, AppController c, {Size size = const Size(1100, 1800)}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final opened = <DateTime>[];
      await tester.pumpWidget(ListenableBuilder(listenable: c, builder: (_, _) => MaterialApp(theme: c.theme,
          home: Scaffold(body: ActivityHeatmapPage(controller: c, onOpenDay: opened.add, clock: () => today)))));
      await tester.pumpAndSettle();
      return opened;
    }

    int counter(WidgetTester tester, String key) => int.parse(tester.widget<Text>(
        find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Text)).first).data!);

    Color cellColor(WidgetTester tester, String day) {
      final box = tester.widget<Container>(find.descendant(
          of: find.byKey(ValueKey('heat-$day')), matching: find.byType(Container)).first);
      return (box.decoration! as BoxDecoration).color!;
    }

    testWidgets('empty profile: zero counters and a clear empty state', (tester) async {
      final c = await remoteController(FakeBackend());
      c.enterApp('a1');
      await pumpPage(tester, c);
      expect(counter(tester, 'activity-active-days'), 0);
      expect(counter(tester, 'activity-entry-count'), 0);
      expect(counter(tester, 'activity-milestone-count'), 0);
      expect(find.byKey(const ValueKey('activity-empty')), findsOneWidget);
      expect(find.byKey(const ValueKey('heat-2026-11-15')), findsOneWidget);
      expect(find.byKey(const ValueKey('heat-2026-11-16')), findsNothing); // no future squares
    });

    testWidgets('counts, colors, semantics, tap → details → open Day view', (tester) async {
      final b = FakeBackend();
      for (var i = 0; i < 3; i++) { b.addEntry('a1', '2026-11-14', milestone: i == 0); }
      for (var i = 0; i < 5; i++) { b.addEntry('a1', '2026-11-09'); }
      b.addEntry('a1', '2026-11-02');
      final c = await remoteController(b);
      c.enterApp('a1');
      final opened = await pumpPage(tester, c);
      final scheme = Theme.of(tester.element(find.byType(ActivityHeatmapPage))).colorScheme;

      expect(counter(tester, 'activity-active-days'), 3);
      expect(counter(tester, 'activity-entry-count'), 9);
      expect(counter(tester, 'activity-milestone-count'), 1);
      expect(cellColor(tester, '2026-11-14'), heatColor(scheme, 3));
      expect(cellColor(tester, '2026-11-09'), heatColor(scheme, 4));
      expect(cellColor(tester, '2026-11-02'), heatColor(scheme, 1));
      expect(cellColor(tester, '2026-11-10'), heatColor(scheme, 0));
      expect(find.bySemanticsLabel('Saturday, November 14, 2026: 3 entries, 1 milestone'), findsOneWidget);
      expect(find.bySemanticsLabel('Tuesday, November 10, 2026: 0 entries, 0 milestones'), findsOneWidget);
      expect(find.byKey(const ValueKey('activity-summary-text')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('heat-2026-11-14')));
      await tester.pumpAndSettle();
      expect(find.text('Saturday, November 14, 2026'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('activity-selected-counts'))).data, '3 entries - 1 milestone');
      await tester.tap(find.text('Open in calendar'));
      expect(opened, [DateTime(2026, 11, 14)]);
    });

    testWidgets('keyboard focus selects a day', (tester) async {
      final b = FakeBackend()..addEntry('a1', '2026-11-14');
      final c = await remoteController(b);
      c.enterApp('a1');
      await pumpPage(tester, c);
      final focus = Focus.of(tester.element(find.descendant(
          of: find.byKey(const ValueKey('heat-2026-11-14')), matching: find.byType(Container)).first));
      focus.requestFocus();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('activity-selected-date')), findsOneWidget);
      expect(find.text('Saturday, November 14, 2026'), findsOneWidget);
    });

    testWidgets('switching profile or project recomputes and clears the selection', (tester) async {
      final b = FakeBackend();
      b.projects.add({'id': 'garden', 'profileId': 'a1', 'name': 'Garden'});
      b.addEntry('a1', '2026-11-14', project: 'garden');
      b.addEntry('a1', '2026-11-13');
      b.addEntry('k1', '2026-11-12');
      final c = await remoteController(b);
      c.enterApp('a1');
      await pumpPage(tester, c);
      expect(counter(tester, 'activity-entry-count'), 2);
      await tester.tap(find.byKey(const ValueKey('heat-2026-11-14')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('activity-selected-date')), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Garden'));
      await tester.pumpAndSettle();
      expect(counter(tester, 'activity-entry-count'), 1);
      expect(find.byKey(const ValueKey('activity-selected-date')), findsNothing);
      expect(find.bySemanticsLabel('Friday, November 13, 2026: 0 entries, 0 milestones'), findsOneWidget);

      c.selectProfile('k1');
      await tester.pumpAndSettle();
      expect(counter(tester, 'activity-entry-count'), 1);
      expect(find.bySemanticsLabel('Thursday, November 12, 2026: 1 story, 0 milestones'), findsOneWidget);
      expect(find.bySemanticsLabel('Saturday, November 14, 2026: 0 stories, 0 milestones'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Garden'), findsNothing); // Kids: no project filter
    });

    testWidgets('theme switch recolors the squares', (tester) async {
      final b = FakeBackend()..addEntry('a1', '2026-11-14');
      final c = await remoteController(b);
      c.enterApp('a1');
      await pumpPage(tester, c);
      final before = cellColor(tester, '2026-11-14');
      await c.setTheme('teal');
      await tester.pumpAndSettle();
      final after = cellColor(tester, '2026-11-14');
      expect(after, isNot(before));
      expect(after, heatColor(c.theme.colorScheme, 1));
    });

    testWidgets('narrow screen scrolls horizontally without overflow', (tester) async {
      final b = FakeBackend()..addEntry('a1', '2026-11-15');
      final c = await remoteController(b);
      c.enterApp('a1');
      await pumpPage(tester, c, size: const Size(360, 1400));
      expect(tester.takeException(), isNull);
      final scroll = tester.widget<SingleChildScrollView>(find.byKey(const ValueKey('activity-scroll')));
      expect(scroll.scrollDirection, Axis.horizontal);
      // Starts at the newest week: today's square is visible.
      expect(tester.getRect(find.byKey(const ValueKey('heat-2026-11-15'))).right, lessThanOrEqualTo(360));
    });
  });

  group('app shell', () {
    testWidgets('Activity is a destination on wide layouts; drilldown opens the Day view', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = AppController(DemoRepository());
      await c.initialize();
      c.enterApp('demo-jordan');
      await tester.pumpWidget(SpeechSpaceApp(controller: c));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Activity')));
      await tester.pumpAndSettle();
      expect(find.byType(ActivityHeatmapPage), findsOneWidget);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await tester.tap(find.byKey(ValueKey('heat-${isoDay(today)}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open in calendar'));
      await tester.pumpAndSettle();
      expect(c.calendarView, CalendarView.day);
      expect(c.calendarDate, today);
      expect(find.text('Planning the week'), findsWidgets); // demo entry dated today
      expect(find.text('Day summary'), findsOneWidget);
    });

    for (final profile in ['demo-alex', 'demo-jordan']) {
      testWidgets('phone width: six destinations fit via "More" without overflow ($profile)', (tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final c = AppController(DemoRepository());
        await c.initialize();
        c.enterApp(profile);
        await tester.pumpWidget(SpeechSpaceApp(controller: c));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
        expect(bar.destinations, hasLength(5));

        await tester.tap(find.byKey(const ValueKey('nav-more')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('more-4')));
        await tester.pumpAndSettle();
        expect(find.byType(ActivityHeatmapPage), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const ValueKey('nav-more')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('more-5')));
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('theme-${c.isKids ? 'space' : 'indigo'}')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

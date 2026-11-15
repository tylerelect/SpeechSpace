import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speechspace/main.dart';
import 'package:speechspace/models/calendar.dart';
import 'package:speechspace/models/models.dart';
import 'package:speechspace/screens/calendar_page.dart';
import 'package:speechspace/services/app_controller.dart';
import 'package:speechspace/services/repository.dart';

Future<AppController> demo() async {
  final c = AppController(DemoRepository());
  await c.initialize();
  return c;
}

JournalEntry entry(String id, String profile, DateTime date, {String project = '', bool milestone = false}) =>
    JournalEntry(id: id, childId: profile, date: date, title: 'T$id', body: 'b', projectId: project, isMilestone: milestone);

/// Minimal in-memory stand-in for the backend, for remote-mode tests.
class FakeBackend {
  final profiles = <Map<String, dynamic>>[
    {'id': 'k1', 'name': 'Kid', 'kind': 'kids', 'themeId': 'space'},
    {'id': 'a1', 'name': 'Grown-up', 'kind': 'adult', 'themeId': 'indigo'},
  ];
  final patches = <String>[];

  MockClient get client => MockClient((req) async {
        final path = req.url.path;
        if (req.method == 'GET' && path == '/api/snapshot') {
          return http.Response(jsonEncode({'children': profiles, 'projects': <Object>[], 'entries': <Object>[], 'links': <Object>[]}), 200);
        }
        if (req.method == 'PATCH' && path.startsWith('/api/profiles/')) {
          final id = path.split('/').last;
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          patches.add('$id:${body['themeId']}');
          final p = profiles.firstWhere((p) => p['id'] == id);
          p['themeId'] = body['themeId'];
          return http.Response(jsonEncode(p), 200);
        }
        if (path == '/api/transcribe') return http.Response(jsonEncode({'detail': 'Speech adapter not configured.'}), 503);
        return http.Response(jsonEncode({'detail': 'Not Found'}), 404);
      });
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('calendar periods', () {
    test('week of Nov 14, 2026 is Mon Nov 9 - Sun Nov 15', () {
      final p = CalendarPeriod.of(CalendarView.week, DateTime(2026, 11, 14));
      expect(p.start, DateTime(2026, 11, 9));
      expect(p.endExclusive, DateTime(2026, 11, 16));
      expect(p.contains(DateTime(2026, 11, 9)), isTrue);
      expect(p.contains(DateTime(2026, 11, 15)), isTrue);
      expect(p.contains(DateTime(2026, 11, 16)), isFalse);
      expect(p.contains(DateTime(2026, 11, 8)), isFalse);
    });

    test('month, year, and leap-day boundaries', () {
      final dec = CalendarPeriod.of(CalendarView.month, DateTime(2026, 12, 31));
      expect(dec.endExclusive, DateTime(2027));
      expect(CalendarPeriod.of(CalendarView.year, DateTime(2026, 6)).endExclusive, DateTime(2027));
      final feb = CalendarPeriod.of(CalendarView.month, DateTime(2028, 2, 10));
      expect(feb.contains(DateTime(2028, 2, 29)), isTrue);
      expect(shiftDate(CalendarView.month, DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
      expect(shiftDate(CalendarView.year, DateTime(2028, 2, 29), 1), DateTime(2029, 2, 28));
      expect(shiftDate(CalendarView.week, DateTime(2026, 12, 30), 1), DateTime(2027, 1, 6));
    });

    test('stored dates keep their calendar day (no UTC shift)', () {
      expect(parseCalendarDay('2026-11-14T00:00:00Z'), DateTime(2026, 11, 14));
      expect(parseCalendarDay('2026-11-14T23:30:00-08:00'), DateTime(2026, 11, 14));
      final e = JournalEntry.fromJson({'id': 'x', 'childId': 'p', 'date': '2026-11-14T00:00:00+00:00'});
      expect(e.date, DateTime(2026, 11, 14));
      expect(e.projectId, '');
    });

    test('counts are scoped to profile and project, capped at 200', () {
      final all = [
        entry('1', 'p1', DateTime(2026, 11, 14), milestone: true),
        entry('2', 'p1', DateTime(2026, 11, 14), project: 'proj'),
        entry('3', 'p2', DateTime(2026, 11, 14)), // other profile, same day
        entry('4', 'p1', DateTime(2026, 11, 16)), // next week
      ];
      final week = CalendarData.compute(profileId: 'p1', view: CalendarView.week, date: DateTime(2026, 11, 14),
          projectId: '', allEntries: all);
      expect(week.entryCount, 2);
      expect(week.activeDays, 1);
      expect(week.milestoneCount, 1);
      expect(week.entries.map((e) => e.id), isNot(contains('3')));
      final project = CalendarData.compute(profileId: 'p1', view: CalendarView.month, date: DateTime(2026, 11),
          projectId: 'proj', allEntries: all);
      expect(project.entries.map((e) => e.id), ['2']);

      final many = [for (var i = 0; i < 230; i++) entry('m$i', 'p1', DateTime(2026, 1, 1 + i % 28))];
      final year = CalendarData.compute(profileId: 'p1', view: CalendarView.year, date: DateTime(2026, 5, 5),
          projectId: '', allEntries: many);
      expect(year.entryCount, 230);
      expect(year.entries, hasLength(200));
      expect(year.truncated, isTrue);
    });

    test('snapshot without a projects key still loads', () {
      final s = AppSnapshot.fromJson({'children': <Object>[], 'entries': <Object>[], 'links': <Object>[]});
      expect(s.projects, isEmpty);
    });
  });

  group('projects', () {
    test('create, select, delete; entries survive unassigned; reset on profile switch', () async {
      final c = await demo();
      c.enterApp('demo-jordan');
      final project = await c.addProject('Garden');
      final saved = await c.saveEntry(entry('', 'demo-jordan', DateTime.now(), project: project.id));
      c.selectProject(project.id);
      expect(c.profileEntries.map((e) => e.id), [saved.id]);

      c.selectProfile('demo-alex');
      expect(c.selectedProjectId, '');
      expect(c.profileProjects, isEmpty); // Jordan's projects don't leak
      c.selectProfile('demo-jordan');

      c.selectProject(project.id);
      await c.deleteProject(project.id);
      expect(c.selectedProjectId, '');
      final survivor = c.entries.firstWhere((e) => e.id == saved.id);
      expect(survivor.projectId, '');
    });

    test('cannot select another profile\'s project', () async {
      final c = await demo();
      c.enterApp('demo-alex');
      c.selectProject('demo-project-home'); // belongs to Jordan
      expect(c.selectedProjectId, '');
    });
  });

  group('persistence', () {
    test('selected profile survives a restart; a deleted one falls back', () async {
      final first = await demo();
      first.enterApp('demo-jordan');
      await Future<void>.delayed(Duration.zero);

      final restarted = AppController(DemoRepository());
      await restarted.initialize();
      expect(restarted.selectedProfileId, 'demo-jordan');
      expect(restarted.started, isFalse); // chooser always shows; remembered profile is pre-selected

      await (await SharedPreferences.getInstance()).setString(AppController.selectedProfileKey, 'gone');
      final fallback = AppController(DemoRepository());
      await fallback.initialize();
      expect(fallback.selectedProfileId, 'demo-alex');
      expect(fallback.started, isFalse);
    });

    test('remote mode: theme PATCH persists per profile and survives reload', () async {
      final backend = FakeBackend();
      await http.runWithClient(() async {
        final repo = RemoteRepository(baseUrl: 'http://test', devToken: 't');
        final c = AppController(repo);
        await c.initialize();
        c.enterApp('k1');
        await c.setTheme('ocean');
        await c.setTheme('sunshine');
        c.selectProfile('a1');
        await c.setTheme('teal');
        await c.setTheme('slate');
        expect(backend.patches, ['k1:ocean', 'k1:sunshine', 'a1:teal', 'a1:slate']);

        final reloaded = AppController(RemoteRepository(baseUrl: 'http://test', devToken: 't'));
        await reloaded.initialize();
        expect(reloaded.selectedProfileId, 'a1'); // restored locally
        expect(reloaded.spaceTheme.id, 'slate');
        reloaded.selectProfile('k1');
        expect(reloaded.spaceTheme.id, 'sunshine');
      }, () => backend.client);
    });
  });

  group('recording errors', () {
    test('missing STT endpoint gives a friendly message, not a crash', () async {
      final backend = FakeBackend();
      await http.runWithClient(() async {
        final repo = RemoteRepository(baseUrl: 'http://test', devToken: 't');
        await expectLater(repo.transcribe(Uint8List(64)), throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'status', 503)
            .having((e) => e.message, 'message', contains('not set up'))));
      }, () => backend.client);
    });

    test('status codes map to readable messages', () {
      expect(transcribeErrorMessage(401, ''), contains('authorized'));
      expect(transcribeErrorMessage(413, ''), contains('too long'));
      expect(transcribeErrorMessage(504, ''), contains('timed out'));
      expect(transcribeErrorMessage(418, 'odd'), 'odd');
    });
  });

  group('theme UI', () {
    testWidgets('Settings shows all theme choices and applies them immediately', (tester) async {
      tester.view.physicalSize = const Size(1100, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await demo();
      c.enterApp('demo-alex');
      await tester.pumpWidget(SpeechSpaceApp(controller: c));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Grown-ups').last);
      await tester.pumpAndSettle();

      for (final id in ['space', 'ocean', 'sunshine']) { expect(find.byKey(ValueKey('theme-$id')), findsOneWidget); }
      Color bg() => tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!.scaffoldBackgroundColor;
      final before = bg();
      await tester.tap(find.byKey(const ValueKey('theme-ocean')));
      await tester.pumpAndSettle();
      expect(c.spaceTheme.id, 'ocean');
      expect(bg(), isNot(before));

      c.selectProfile('demo-jordan');
      await tester.pumpAndSettle();
      for (final id in ['indigo', 'teal', 'slate']) { expect(find.byKey(ValueKey('theme-$id')), findsOneWidget); }
      await tester.tap(find.byKey(const ValueKey('theme-slate')));
      await tester.pumpAndSettle();
      c.selectProfile('demo-alex');
      expect(c.spaceTheme.id, 'ocean'); // other profile's choice untouched
    });
  });

  group('calendar UI', () {
    Future<void> pumpCalendar(WidgetTester tester, AppController c) async {
      tester.view.physicalSize = const Size(1100, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(theme: c.theme, home: Scaffold(body: ListenableBuilder(
          listenable: c, builder: (_, _) => CalendarPage(controller: c)))));
      await tester.pumpAndSettle();
    }

    testWidgets('switches views and shows an on-demand recap', (tester) async {
      final c = await demo();
      c.enterApp('demo-alex');
      await pumpCalendar(tester, c);
      for (final v in ['Day', 'Week', 'Month', 'Year']) { expect(find.text(v), findsWidgets); }
      expect(find.text('Generate summary'), findsOneWidget);

      await tester.tap(find.text('Year'));
      await tester.pumpAndSettle();
      expect(find.text('${DateTime.now().year}'), findsOneWidget);

      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate summary'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Demo recap (not Gemini)'), findsOneWidget);
    });

    testWidgets('large periods are labelled as sampled', (tester) async {
      final c = await demo();
      c.enterApp('demo-jordan');
      final now = DateTime.now();
      for (var i = 0; i < 45; i++) {
        await c.saveEntry(entry('', 'demo-jordan', DateTime(now.year, 3, 1 + i % 28)));
      }
      await pumpCalendar(tester, c);
      await tester.tap(find.text('Year'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate summary'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.textContaining('Based on a sample of entries'), findsOneWidget);
      expect(find.textContaining('40 of'), findsOneWidget);
    });
  });
}


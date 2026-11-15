import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speechspace/main.dart';
import 'package:speechspace/models/models.dart';
import 'package:speechspace/services/app_controller.dart';
import 'package:speechspace/services/layout_store.dart';
import 'package:speechspace/services/repository.dart';

import 'support/fake_backend.dart';

/// Wraps a repository so a test can hold `load()` calls open.
class GatedRepository extends DemoRepository {
  final pending = <Completer<void>>[];
  bool gate = false;
  @override
  Future<AppSnapshot> load() async {
    final snapshot = await super.load(); // data as of the call, so a held load is stale
    if (gate) {
      final c = Completer<void>();
      pending.add(c);
      await c.future;
    }
    return snapshot;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  RemoteRepository repo(FakeBackend b) => RemoteRepository(baseUrl: 'http://test', devToken: 't', client: b.client);

  testWidgets('remote mode: all six theme chips PATCH, recolor the app, and survive profile switch + restart',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final b = FakeBackend();
    final c = AppController(repo(b));
    await c.initialize();
    c.enterApp('k1');
    await tester.pumpWidget(SpeechSpaceApp(controller: c));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grown-ups').last);
    await tester.pumpAndSettle();

    Color bg() => tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!.scaffoldBackgroundColor;
    bool chipSelected(String id) => tester.widget<ChoiceChip>(find.byKey(ValueKey('theme-$id'))).selected;
    final seen = <Color>{bg()};
    expect(chipSelected('space'), isTrue);
    for (final id in ['ocean', 'sunshine']) {
      await tester.tap(find.byKey(ValueKey('theme-$id')));
      await tester.pumpAndSettle();
      expect(chipSelected(id), isTrue);
      expect(seen.add(bg()), isTrue, reason: '$id changes the whole-app colors');
    }
    // Switch to the Adult profile (app bar picker); its own chips appear.
    c.selectProfile('a1');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('theme-space')), findsNothing);
    expect(chipSelected('indigo'), isTrue);
    for (final id in ['teal', 'slate']) {
      await tester.tap(find.byKey(ValueKey('theme-$id')));
      await tester.pumpAndSettle();
      expect(chipSelected(id), isTrue);
      expect(seen.add(bg()), isTrue, reason: '$id changes the whole-app colors');
    }
    expect(b.patches, ['k1:ocean', 'k1:sunshine', 'a1:teal', 'a1:slate']);
    expect(b.profiles.map((p) => p['themeId']), ['sunshine', 'slate']); // stored server-side

    c.selectProfile('k1');
    expect(c.spaceTheme.id, 'sunshine'); // switching never overwrites the other profile's theme

    // Restart: a new controller restores the selected profile locally and themes from the backend.
    final restarted = AppController(repo(b));
    await restarted.initialize();
    expect(restarted.started, isFalse); // chooser always shows; remembered profile is pre-selected
    expect(restarted.selectedProfileId, 'k1');
    expect(restarted.spaceTheme.id, 'sunshine');
    restarted.selectProfile('a1');
    expect(restarted.spaceTheme.id, 'slate');
  });

  test('a rejected theme keeps the saved one', () async {
    final b = FakeBackend();
    final c = AppController(repo(b), persistSelection: false);
    await c.initialize();
    c.enterApp('k1');
    await expectLater(c.setTheme('slate'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 422)));
    expect(c.spaceTheme.id, 'space');
  });

  test('legacy profiles without kind/themeId default to Kids/space', () {
    final s = AppSnapshot.fromJson({'children': [{'id': 'old', 'name': 'Legacy'}]});
    expect(s.children.single.kind, SpaceProfile.kids);
    expect(s.children.single.themeId, 'space');
    expect(SpaceProfile.fromJson({'id': 'a', 'name': 'A', 'kind': 'adult', 'themeId': ''}).themeId, 'indigo');
  });

  test('remote create, switch and delete; deleting falls back and clears local layout', () async {
    final b = FakeBackend();
    final c = AppController(repo(b));
    await c.initialize();
    final adult = await c.addProfile('Sam', SpaceProfile.adult, themeId: 'teal');
    expect(b.requests, contains('POST /api/profiles'));
    expect(c.selectedProfileId, adult.id);
    expect(c.spaceTheme.id, 'teal');
    await c.saveEntry(JournalEntry(id: '', childId: adult.id, date: DateTime(2026, 11, 14), title: 'Sam note', body: 'x'));
    await MindMapLayoutStore.save(adult.id, {'x': const Offset(1, 2)});
    c.selectProfile('k1');
    expect(c.profileEntries.map((e) => e.title), isNot(contains('Sam note')));

    c.selectProfile(adult.id);
    await c.deleteCurrentProfile();
    expect(b.profiles.any((p) => p['id'] == adult.id), isFalse);
    expect(b.entries.any((e) => e['childId'] == adult.id), isFalse);
    expect(c.selectedProfileId, 'k1');
    expect(await MindMapLayoutStore.load(adult.id), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppController.selectedProfileKey), 'k1');
  });

  test('remote projects: create, filter, delete keeps entries unassigned, no cross-profile leak', () async {
    final b = FakeBackend();
    final c = AppController(repo(b), persistSelection: false);
    await c.initialize();
    c.enterApp('a1');
    final project = await c.addProject('Garden');
    expect(b.projects.single['profileId'], 'a1');
    final saved = await c.saveEntry(JournalEntry(id: '', childId: 'a1', date: DateTime(2026, 11, 14),
        title: 'Planted', body: 'x', projectId: project.id));
    expect(b.entries.single['projectId'], project.id);
    c.selectProject(project.id);
    expect(c.profileEntries.single.id, saved.id);
    c.selectProfile('k1');
    expect(c.profileProjects, isEmpty);
    expect(c.selectedProjectId, '');
    c.selectProfile('a1');
    await c.deleteProject(project.id);
    expect(c.entries.single.projectId, '');
    expect(c.profileEntries.single.title, 'Planted');
  });

  test('a slower, older snapshot never overwrites a newer one', () async {
    final r = GatedRepository();
    final c = AppController(r, persistSelection: false);
    await c.initialize();
    r.gate = true;
    final older = c.refresh();
    await r.saveEntry(JournalEntry(id: 'new', childId: 'demo-alex', date: DateTime.now(), title: 'New', body: 'x'));
    final newer = c.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(r.pending, hasLength(2));
    // Newer load completes first, then the older (stale) one.
    r.pending[1].complete();
    await Future<void>.delayed(Duration.zero);
    r.pending[0].complete();
    await Future.wait([older, newer]);
    expect(c.entries.any((e) => e.id == 'new'), isTrue);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speechspace/models/models.dart';
import 'package:speechspace/screens/mind_map_page.dart';
import 'package:speechspace/services/app_controller.dart';
import 'package:speechspace/services/layout_store.dart';
import 'package:speechspace/services/repository.dart';
import 'package:speechspace/widgets/space_art.dart';

import 'support/fake_backend.dart';

Future<AppController> demo(String profile) async {
  final c = AppController(DemoRepository());
  await c.initialize();
  c.enterApp(profile);
  return c;
}

Future<void> pumpMap(WidgetTester tester, AppController c, {Size size = const Size(1200, 1000)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ListenableBuilder(listenable: c, builder: (_, _) => MaterialApp(theme: c.theme,
      home: Scaffold(body: MindMapPage(controller: c)))));
  await tester.pumpAndSettle();
}

Offset cardTopLeft(WidgetTester tester, String id) {
  final p = tester.widget<Positioned>(find.byKey(ValueKey(id)));
  return Offset(p.left!, p.top!);
}

double scale(WidgetTester tester) =>
    tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).transformationController!.value.getMaxScaleOnAxis();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Kids map follows the theme', () {
    const names = {'space': 'Star map', 'ocean': 'Sea map', 'sunshine': 'Garden map'};
    for (final entry in names.entries) {
      for (final width in [360.0, 1200.0]) {
        testWidgets('${entry.key} at ${width.toInt()}px', (tester) async {
          final c = await demo('demo-alex');
          await c.setTheme(entry.key);
          await pumpMap(tester, c, size: Size(width, 1000));
          expect(tester.takeException(), isNull);
          expect(find.text(entry.value), findsOneWidget);
          final kinds = tester.widgetList<SpaceArt>(find.byType(SpaceArt)).map((a) => a.kind).toSet();
          expect(kinds, containsAll([artFor(entry.key, ArtRole.hero), artFor(entry.key, ArtRole.sticker)]));
          if (entry.key != 'space') expect(kinds, isNot(contains(SpaceArtKind.star)));
        });
      }
    }
  });

  group('phase 1: existing capabilities', () {
    test('link, duplicate/self-link rejection, unlink', () async {
      final c = await demo('demo-alex');
      expect(c.profileLinks, hasLength(1)); // demo-1 ↔ demo-3
      await expectLater(c.addLink('demo-1', 'demo-1', 'x'), throwsStateError);
      await expectLater(c.addLink('demo-1', 'demo-3', 'x'), throwsA(isA<StateError>()
          .having((e) => e.message, 'message', contains('already connected'))));
      await expectLater(c.addLink('demo-3', 'demo-1', 'x'), throwsStateError, reason: 'reverse duplicate');
      await c.addLink('demo-1', 'demo-2', 'Favorites');
      expect(c.profileLinks, hasLength(2));
      await c.removeLink(c.profileLinks.firstWhere((l) => l.label == 'Favorites').id);
      expect(c.profileLinks, hasLength(1));
    });

    testWidgets('only the active profile\'s cards and links are drawn', (tester) async {
      final c = await demo('demo-alex');
      await pumpMap(tester, c);
      expect(find.text('The big blue kite'), findsOneWidget);
      expect(find.text('Planning the week'), findsNothing);
      c.selectProfile('demo-jordan');
      await tester.pumpAndSettle();
      expect(find.text('Planning the week'), findsOneWidget);
      expect(find.text('The big blue kite'), findsNothing);
      expect(find.text('Mind map'), findsOneWidget);
    });

    testWidgets('Link and unlink through the UI', (tester) async {
      final c = await demo('demo-alex');
      await pumpMap(tester, c);
      await tester.tap(find.text('Link'));
      await tester.pumpAndSettle();
      expect(find.text('Connect two memories'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Relationship label'), 'Outdoors');
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      expect(c.profileLinks.map((l) => l.label), contains('Outdoors'));

      await tester.tap(find.byTooltip('Remove connection'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('• Outdoors'));
      await tester.pumpAndSettle();
      expect(c.profileLinks.map((l) => l.label), isNot(contains('Outdoors')));
    });

    testWidgets('a duplicate link shows a message instead of crashing', (tester) async {
      final c = await demo('demo-jordan'); // demo-a1 ↔ demo-a2 already linked
      await pumpMap(tester, c);
      await tester.tap(find.text('Link'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      expect(find.text('These memories are already connected.'), findsOneWidget);
    });

    testWidgets('tap a card to edit it', (tester) async {
      final c = await demo('demo-alex');
      await pumpMap(tester, c);
      await tester.tap(find.text('The big blue kite'));
      await tester.pumpAndSettle();
      expect(find.text('My story'), findsOneWidget); // Kids edit title
      expect(find.widgetWithText(TextField, 'Name your story'), findsOneWidget);
    });

    testWidgets('drag a card; pan and zoom the canvas', (tester) async {
      final c = await demo('demo-alex');
      await pumpMap(tester, c);
      final before = cardTopLeft(tester, 'demo-2');
      await tester.drag(find.text('Favorite outfit'), const Offset(-60, 40));
      await tester.pumpAndSettle();
      expect(cardTopLeft(tester, 'demo-2'), isNot(before));

      final s0 = scale(tester);
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pump();
      expect(scale(tester), closeTo(s0 * 1.25, 1e-6));
      await tester.tap(find.byTooltip('Zoom out'));
      await tester.pump();
      expect(scale(tester), closeTo(s0, 1e-6));

      final controller = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).transformationController!;
      final t0 = controller.value.getTranslation();
      // Drag empty background (top-left corner of the canvas) to pan.
      final viewer = tester.getRect(find.byType(InteractiveViewer));
      await tester.dragFrom(viewer.topLeft + const Offset(20, 20), const Offset(120, 60));
      await tester.pumpAndSettle();
      expect(controller.value.getTranslation(), isNot(t0));

      await tester.tap(find.byTooltip('Fit to screen'));
      await tester.pump();
      expect(find.text('The big blue kite'), findsOneWidget);
    });

    testWidgets('empty state and single-entry hint', (tester) async {
      final c = await demo('demo-alex');
      await c.addProfile('Nova', SpaceProfile.kids);
      await pumpMap(tester, c);
      expect(find.text('Tell a story to see it here!'), findsOneWidget);
      await c.saveEntry(JournalEntry(id: '', childId: c.selectedProfileId!, date: DateTime.now(), title: 'Only one', body: 'x'));
      await tester.pumpAndSettle();
      expect(find.text('Only one'), findsOneWidget);
      expect(find.text('Add another story to make connections.'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.ancestor(of: find.text('Link'), matching: find.byWidgetPredicate((w) => w is FilledButton))).onPressed,
          isNull);
    });

    testWidgets('cards follow the profile theme', (tester) async {
      final c = await demo('demo-jordan');
      await pumpMap(tester, c);
      Color cardColor() => (tester.widget<Container>(find.ancestor(of: find.text('Planning the week'),
          matching: find.byType(Container)).first).decoration! as BoxDecoration).color!;
      expect(cardColor(), c.theme.colorScheme.primaryContainer);
      await c.setTheme('teal');
      await tester.pumpAndSettle();
      expect(cardColor(), c.theme.colorScheme.primaryContainer);
      expect(cardColor(), isNot(ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5))).colorScheme.primaryContainer));
    });

    testWidgets('kept idea opens the editor with the suggestion; links stay in-profile', (tester) async {
      final c = await demo('demo-alex');
      await pumpMap(tester, c, size: const Size(1200, 2400)); // room for the whole editor
      final generating = c.generateIdeas(['demo-1', 'demo-3']);
      await tester.pump(const Duration(milliseconds: 500)); // demo repository simulates latency
      await generating;
      await tester.pumpAndSettle();
      final idea = c.profileIdeas.firstWhere((i) => i.sourceIds.length == 2);
      await tester.tap(find.text(idea.title));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tell this story'));
      await tester.pumpAndSettle();
      expect(find.text('Idea to get you started. Tell it in your own words!'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'What happened?'), 'We did it.');
      await tester.tap(find.text('Save my story'));
      await tester.pumpAndSettle();
      final saved = c.profileEntries.firstWhere((e) => e.title == idea.title);
      final linked = c.profileLinks.where((l) => l.toId == saved.id).map((l) => l.fromId).toSet();
      expect(linked, {'demo-1', 'demo-3'});
      expect(c.links.where((l) => l.toId == saved.id).every((l) => l.childId == 'demo-alex'), isTrue);
    });
  });

  group('phase 1 through the backend', () {
    test('links survive refresh and restart; ideas are session-only', () async {
      final b = FakeBackend();
      b.addEntry('k1', '2026-11-14', id: 'x1');
      b.addEntry('k1', '2026-11-13', id: 'x2');
      AppController make() => AppController(RemoteRepository(baseUrl: 'http://test', devToken: 't', client: b.client));
      final first = make();
      await first.initialize();
      first.enterApp('k1');
      await first.addLink('x1', 'x2', 'same week');
      await first.generateIdeas(['x1', 'x2']);
      expect(first.profileIdeas, hasLength(2));
      await first.refresh();
      expect(first.profileLinks.single.label, 'same week');
      // Server rejects a duplicate created behind the client's back.
      await expectLater(first.repository.addLink(const MemoryLink(id: '', childId: 'k1', fromId: 'x2', toId: 'x1')),
          throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)));

      final restarted = make();
      await restarted.initialize();
      expect(restarted.selectedProfileId, 'k1');
      expect(restarted.profileLinks.single.label, 'same week');
      expect(restarted.profileIdeas, isEmpty);
    });

    testWidgets('Ideas with no Gemini key shows a recoverable message', (tester) async {
      final b = FakeBackend()..expandStatus = 503;
      b.addEntry('a1', '2026-11-14', id: 'x1', title: 'Some note');
      final c = AppController(RemoteRepository(baseUrl: 'http://test', devToken: 't', client: b.client), persistSelection: false);
      await c.initialize();
      c.enterApp('a1');
      await pumpMap(tester, c);
      await tester.tap(find.text('Ideas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate'));
      await tester.pumpAndSettle();
      expect(find.text('Gemini is not configured on the backend yet (GEMINI_API_KEY).'), findsOneWidget);
      expect(find.text('Some note'), findsOneWidget);
      expect(c.generatingIdeas, isFalse);
    });
  });

  group('phase 2: usability', () {
    test('default layout has no overlapping cards for 0, 1, 6, 20 and 60 entries', () {
      for (final n in [0, 1, 6, 7, 20, 60]) {
        final points = defaultMindMapLayout(n);
        final canvas = mindMapCanvasFor(n);
        expect(points, hasLength(n));
        final rects = [for (final p in points) Rect.fromCenter(center: p, width: mindMapNodeSize.width, height: mindMapNodeSize.height)];
        for (final r in rects) {
          expect(Offset.zero & canvas, predicate<Rect>((c) => c.contains(r.topLeft) && c.contains(r.bottomRight - const Offset(1, 1))),
              reason: 'n=$n card inside canvas');
        }
        for (var i = 0; i < rects.length; i++) {
          for (var j = i + 1; j < rects.length; j++) {
            expect(rects[i].overlaps(rects[j]), isFalse, reason: 'n=$n cards $i and $j overlap');
          }
        }
      }
    });

    testWidgets('20+ entries render without overlap or errors and start fitted', (tester) async {
      final c = await demo('demo-jordan');
      for (var i = 0; i < 22; i++) {
        await c.saveEntry(JournalEntry(id: '', childId: 'demo-jordan', date: DateTime(2026, 1, 1 + i),
            title: 'A rather long entry title number $i that needs to wrap onto two lines', body: 'x'));
      }
      await pumpMap(tester, c, size: const Size(900, 800));
      expect(tester.takeException(), isNull);
      expect(find.textContaining('A rather long entry title'), findsNWidgets(22));
      expect(scale(tester), lessThan(1), reason: 'a large map is shrunk to fit on first view');
      final ids = c.profileEntries.map((e) => e.id).toList();
      final rects = [for (final id in ids) cardTopLeft(tester, id) & mindMapNodeSize];
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) { expect(rects[i].overlaps(rects[j]), isFalse); }
      }
    });

    testWidgets('layout persists per profile and Reset layout restores the default', (tester) async {
      final c = await demo('demo-alex');
      await pumpMap(tester, c);
      final original = cardTopLeft(tester, 'demo-2');
      await tester.drag(find.text('Favorite outfit'), const Offset(-80, 50));
      await tester.pumpAndSettle();
      final moved = cardTopLeft(tester, 'demo-2');
      expect(moved, isNot(original));
      expect((await MindMapLayoutStore.load('demo-alex')).keys, contains('demo-2'));
      expect(await MindMapLayoutStore.load('demo-jordan'), isEmpty);

      // A fresh map (e.g. after restart) restores the saved spot.
      await tester.pumpWidget(const SizedBox());
      await pumpMap(tester, c);
      expect(cardTopLeft(tester, 'demo-2'), moved);

      await tester.tap(find.byTooltip('Reset layout'));
      await tester.pumpAndSettle();
      expect(cardTopLeft(tester, 'demo-2'), original);
      expect(await MindMapLayoutStore.load('demo-alex'), isEmpty);
    });

    testWidgets('selection emphasis, semantics, keyboard and Esc', (tester) async {
      final c = await demo('demo-alex');
      await pumpMap(tester, c);
      expect(find.bySemanticsLabel(RegExp(r'^Story: The big blue kite\. 1 connection\. Activate to edit\.$')), findsOneWidget);
      expect(find.byKey(const ValueKey('mindmap-hint')), findsOneWidget);

      // Keyboard focus selects a card; Enter opens the editor.
      final focus = Focus.of(tester.element(find.text('The big blue kite')));
      focus.requestFocus();
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const ValueKey('mindmap-selected'))).data,
          'Selected: The big blue kite • 1 connection');
      // Unconnected cards are dimmed; the linked one is not.
      double opacityOf(String title) => tester.widget<AnimatedOpacity>(
          find.ancestor(of: find.text(title), matching: find.byType(AnimatedOpacity))).opacity;
      expect(opacityOf('Favorite outfit'), lessThan(1));
      expect(opacityOf('Made a cardboard castle'), 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mindmap-selected')), findsNothing);
      expect(opacityOf('Favorite outfit'), 1);

      focus.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('My story'), findsOneWidget);
    });

    testWidgets('switching profile clears the selection', (tester) async {
      final c = await demo('demo-alex');
      await pumpMap(tester, c);
      Focus.of(tester.element(find.text('The big blue kite'))).requestFocus();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mindmap-selected')), findsOneWidget);
      c.selectProfile('demo-jordan');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mindmap-selected')), findsNothing);
    });

    testWidgets('phone width: toolbar wraps without overflow', (tester) async {
      final c = await demo('demo-jordan');
      await pumpMap(tester, c, size: const Size(360, 740));
      expect(tester.takeException(), isNull);
      expect(find.text('Pinch to zoom • drag the background to pan • drag a card to move it'), findsOneWidget);
    });
  });
}

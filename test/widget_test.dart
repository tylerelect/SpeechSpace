import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speechspace/main.dart';
import 'package:speechspace/models/models.dart';
import 'package:speechspace/screens/mind_map_page.dart';
import 'package:speechspace/services/app_controller.dart';
import 'package:speechspace/services/repository.dart';
import 'package:speechspace/services/writing_prompts.dart';
import 'package:speechspace/widgets/entry_editor.dart';

Future<AppController> demoController() async {
  final controller = AppController(DemoRepository());
  await controller.initialize();
  return controller;
}

void main() {
  testWidgets('launch shows the profile chooser; picking Alex opens Kids mode', (tester) async {
    final controller = await demoController();
    await tester.pumpWidget(SpeechSpaceApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('Who\'s using SpeechSpace?'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Jordan'), findsOneWidget);
    expect(find.text('New profile'), findsOneWidget);

    await tester.tap(find.text('Alex'));
    await tester.pumpAndSettle();
    expect(find.text('SpeechSpace'), findsOneWidget);
    expect(controller.profile?.kind, SpaceProfile.kids);
    expect(find.text('Ready for liftoff!'), findsOneWidget);
    expect(find.text('Tell my story'), findsOneWidget);
    expect(find.text('Watch the Commander'), findsOneWidget);
  });

  testWidgets('switching to Adult changes wording, theme, and hides kid data', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = await demoController();
    controller.enterApp('demo-alex');
    await tester.pumpWidget(SpeechSpaceApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('The big blue kite'), findsOneWidget);

    controller.selectProfile('demo-jordan');
    await tester.pumpAndSettle();
    expect(find.text('New entry'), findsOneWidget);
    expect(find.text('Watch the Commander'), findsNothing);
    expect(find.text('The big blue kite'), findsNothing);
    expect(find.text('Planning the week'), findsOneWidget);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.brightness, Brightness.light); // indigo, not the dark space theme
  });

  testWidgets('setup flow creates a Kids profile with theme and commander voice', (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = await demoController();
    await tester.pumpWidget(SpeechSpaceApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New profile'));
    await tester.pumpAndSettle();
    expect(find.text('Who is this profile for?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Riley');
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Pick a look'), findsOneWidget);
    expect(find.text('Indigo'), findsNothing); // only Kids themes offered
    await tester.tap(find.text('Ocean'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Choose your commander'), findsOneWidget);
    await tester.tap(find.text('Commander (male)'));
    await tester.pump();
    await tester.tap(find.text('Blast off!'));
    await tester.pumpAndSettle();

    expect(controller.started, isTrue);
    expect(controller.profile?.name, 'Riley');
    expect(controller.profile?.kind, SpaceProfile.kids);
    expect(controller.spaceTheme.id, 'ocean');
    expect(controller.voice, 'm');
    expect(find.text('Ready for liftoff!'), findsOneWidget);
  });

  testWidgets('Adult setup skips the commander step', (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = await demoController();
    await tester.pumpWidget(SpeechSpaceApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Sam');
    await tester.tap(find.text('Adult'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Space'), findsNothing); // only Adult themes offered
    await tester.tap(find.text('Teal'));
    await tester.pump();
    await tester.tap(find.text('Create profile'));
    await tester.pumpAndSettle();

    expect(controller.profile?.kind, SpaceProfile.adult);
    expect(controller.spaceTheme.id, 'teal');
    expect(find.text('Choose your commander'), findsNothing);
    expect(find.text('New entry'), findsOneWidget);
  });

  test('profile defaults and per-profile themes', () async {
    final controller = await demoController();
    expect(controller.spaceTheme.id, 'space');

    await controller.setTheme('ocean');
    expect(controller.spaceTheme.id, 'ocean');

    controller.selectProfile('demo-jordan');
    expect(controller.spaceTheme.id, 'indigo');
    await controller.setTheme('slate');

    // Themes survive a reload from the repository and stay per profile.
    await controller.refresh();
    expect(controller.spaceTheme.id, 'slate');
    controller.selectProfile('demo-alex');
    expect(controller.spaceTheme.id, 'ocean');
  });

  test('new profiles get the right kind and default theme; data is scoped', () async {
    final controller = await demoController();
    await controller.addProfile('Sam', SpaceProfile.adult);
    expect(controller.profile?.name, 'Sam');
    expect(controller.profile?.kind, SpaceProfile.adult);
    expect(controller.spaceTheme.id, 'indigo');
    expect(controller.profileEntries, isEmpty);
    expect(controller.profileLinks, isEmpty);

    await controller.addProfile('Riley', SpaceProfile.kids);
    expect(controller.spaceTheme.id, 'space');

    await controller.deleteCurrentProfile();
    expect(controller.profiles.any((p) => p.name == 'Riley'), isFalse);
  });

  test('an unknown or mismatched themeId falls back to the kind default', () {
    expect(SpaceProfile.fromJson({'id': 'a', 'name': 'A', 'kind': 'adult'}).themeId, 'indigo');
    expect(SpaceProfile.fromJson({'id': 'k', 'name': 'K'}).kind, SpaceProfile.kids);
  });

  test('star ideas are generated per profile and only from that profile\'s entries', () async {
    final controller = await demoController();
    controller.enterApp('demo-alex');
    final count = await controller.generateIdeas(['demo-1', 'demo-3', 'demo-a1']); // demo-a1 is Jordan's
    expect(count, greaterThan(0));
    final ideas = controller.profileIdeas;
    expect(ideas, hasLength(count));
    for (final idea in ideas) {
      expect(idea.demo, isTrue);
      expect(idea.sourceIds.every((id) => ['demo-1', 'demo-3'].contains(id)), isTrue);
    }
    controller.selectProfile('demo-jordan');
    expect(controller.profileIdeas, isEmpty);
  });

  test('keeping an idea links the new entry to its sources; dismissing removes it', () async {
    final controller = await demoController();
    controller.enterApp('demo-alex');
    await controller.generateIdeas(['demo-1', 'demo-3']);
    final idea = controller.profileIdeas.firstWhere((i) => i.sourceIds.length == 2);
    final saved = await controller.saveEntry(JournalEntry(id: '', childId: 'demo-alex', date: DateTime.now(),
        title: idea.title, body: 'We tried it!'));
    await controller.acceptIdea(idea, saved);
    expect(controller.profileIdeas.any((i) => i.id == idea.id), isFalse);
    final newLinks = controller.profileLinks.where((l) => l.toId == saved.id).map((l) => l.fromId).toSet();
    expect(newLinks, {'demo-1', 'demo-3'});

    final other = controller.profileIdeas.first;
    controller.dismissIdea(other.id);
    expect(controller.profileIdeas.any((i) => i.id == other.id), isFalse);
  });

  test('server ideas cannot point at entries outside the request', () {
    final idea = StarIdea.fromJson({'title': 'X', 'type': 'recommendation', 'sourceIds': ['a', 'evil']},
        id: '1', profileId: 'p', allowedSourceIds: {'a', 'b'});
    expect(idea?.sourceIds, ['a']);
    expect(idea?.isRecommendation, isTrue);
    expect(StarIdea.fromJson({'title': '  '}, id: '2', profileId: 'p', allowedSourceIds: {'a'}), isNull);
  });

  testWidgets('star map shows suggested stars and opens the keep/dismiss sheet', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = await demoController();
    controller.enterApp('demo-alex');
    await tester.pumpWidget(MaterialApp(theme: controller.theme,
        home: Scaffold(body: MindMapPage(controller: controller))));
    await tester.pumpAndSettle();
    expect(find.text('New ideas'), findsOneWidget);

    await tester.tap(find.text('New ideas'));
    await tester.pumpAndSettle();
    expect(find.text('Make new idea stars'), findsOneWidget);
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();
    expect(controller.profileIdeas, isNotEmpty);

    final idea = controller.profileIdeas.first;
    expect(find.text(idea.title), findsOneWidget);
    await tester.tap(find.text(idea.title));
    await tester.pumpAndSettle();
    expect(find.text('Demo sample (not Gemini)'), findsOneWidget);
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text(idea.title), findsNothing);
  });

  test('detail prompts wait for a starter sentence and skip details already given', () {
    expect(suggestPrompts('We went', kids: true), isEmpty);
    final ids = suggestPrompts('Today I played at the park with Grandpa', kids: true, max: 10).map((p) => p.id).toList();
    expect(ids, isNot(contains('who')));   // "with Grandpa"
    expect(ids, isNot(contains('where'))); // "at the park"
    expect(ids, contains('feel'));
    expect(ids, contains('next'));
    final adult = suggestPrompts('Finished the quarterly report draft', kids: false, max: 10).map((p) => p.id);
    expect(adult, containsAll(['why', 'next']));
    expect(suggestPrompts('Today I played at the park', kids: true, used: {'feel'}, max: 10).map((p) => p.id),
        isNot(contains('feel')));
  });

  test('starters are appended as a new sentence', () {
    expect(appendStarter('I flew a kite', 'I was with '), 'I flew a kite. I was with ');
    expect(appendStarter('I flew a kite!  ', 'Then '), 'I flew a kite! Then ');
    expect(appendStarter('', 'Then '), 'Then ');
  });

  testWidgets('tapping a detail chip adds a sentence starter to the note', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = await demoController();
    controller.enterApp('demo-alex');
    await tester.pumpWidget(MaterialApp(theme: controller.theme, home: Scaffold(
        body: EntryEditor(controller: controller, initialDate: DateTime.now()))));
    await tester.pumpAndSettle();
    expect(find.text('Write a little to get story helpers ✨'), findsOneWidget);

    final body = find.widgetWithText(TextField, 'What happened?');
    await tester.enterText(body, 'Today I built a big sandcastle');
    await tester.pump();
    expect(find.text('Add more to your story'), findsOneWidget);
    expect(find.text('Who was there?'), findsOneWidget);

    await tester.tap(find.text('Who was there?'));
    await tester.pump();
    expect(tester.widget<TextField>(body).controller!.text, 'Today I built a big sandcastle. I was with ');
    expect(find.text('Who was there?'), findsNothing); // used prompts go away
  });

  test('Gemini prompt items are validated and trimmed', () {
    final ok = WritingPrompt.fromJson({'label': '  Who helped you? ', 'starter': 'Someone who helped me was'});
    expect(ok?.label, 'Who helped you?');
    expect(ok?.starter, 'Someone who helped me was ');
    expect(ok?.fromAi, isTrue);
    expect(WritingPrompt.fromJson({'label': '', 'starter': 'x'}), isNull);
    expect(WritingPrompt.fromJson({'label': 'x' * 200, 'starter': 'y'})?.label.length, 40);
  });

  testWidgets('Gemini suggestions only load after opting in, then fill the chips', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = await demoController();
    controller.enterApp('demo-alex');
    await tester.pumpWidget(MaterialApp(theme: controller.theme, home: Scaffold(
        body: EntryEditor(controller: controller, initialDate: DateTime.now()))));
    await tester.pumpAndSettle();

    final body = find.widgetWithText(TextField, 'What happened?');
    await tester.enterText(body, 'Today I built a big sandcastle');
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Tell more about the sandcastle'), findsNothing); // nothing sent before opting in

    await tester.tap(find.text('More ideas from Gemini'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('Demo samples (not Gemini)'), findsOneWidget);
    expect(find.text('More ideas from Gemini'), findsNothing);
    expect(find.text('Tell more about the sandcastle'), findsOneWidget);

    await tester.tap(find.text('Tell more about the sandcastle'));
    await tester.pump();
    expect(tester.widget<TextField>(body).controller!.text, 'Today I built a big sandcastle. The sandcastle was ');
    await tester.pump(const Duration(seconds: 2)); // let the debounced refresh finish
    await tester.pump(const Duration(milliseconds: 400));
  });
}

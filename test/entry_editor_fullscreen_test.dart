import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speechspace/main.dart';
import 'package:speechspace/services/app_controller.dart';
import 'package:speechspace/services/repository.dart';
import 'package:speechspace/widgets/entry_editor.dart';

import 'support/fake_backend.dart';

/// The story editor is a full-screen page with Close and a menu. It is not a
/// bottom sheet, so a downward swipe never throws away a half-written story.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> openEditor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393, 852); // iPhone logical size
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = AppController(RemoteRepository(baseUrl: 'http://test', devToken: 't', client: FakeBackend().client));
    await c.initialize();
    c.enterApp('a1');
    await tester.pumpWidget(SpeechSpaceApp(controller: c));
    await tester.pumpAndSettle();
    await tester.tap(find.text(c.copy.addToday).first);
    await tester.pumpAndSettle();
  }

  testWidgets('opens full screen with Close, Save and a menu; no bottom sheet', (tester) async {
    await openEditor(tester);
    expect(find.byType(EntryEditor), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    final editorScaffold = find.ancestor(of: find.byTooltip('Close'), matching: find.byType(Scaffold));
    expect(tester.getSize(editorScaffold.first), const Size(393, 852), reason: 'fills the whole screen');
    expect(find.byTooltip('More options'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Save'), findsOneWidget);
    expect(tester.widget<Scrollbar>(find.byType(Scrollbar).first).thumbVisibility, isTrue);

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    expect(find.text('Change date'), findsOneWidget);
    expect(find.text('Mark as milestone'), findsOneWidget);
  });

  testWidgets('a downward swipe does not dismiss the editor', (tester) async {
    await openEditor(tester);
    await tester.dragFrom(const Offset(200, 120), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(find.byType(EntryEditor), findsOneWidget);
  });

  testWidgets('Close with unsaved text asks before discarding', (tester) async {
    await openEditor(tester);
    await tester.enterText(find.byType(TextField).first, 'Half a story');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byType(EntryEditor), findsOneWidget);
    expect(find.text('Half a story'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(EntryEditor), findsNothing);
  });

  testWidgets('Close with nothing typed closes right away', (tester) async {
    await openEditor(tester);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.byType(EntryEditor), findsNothing);
  });
}

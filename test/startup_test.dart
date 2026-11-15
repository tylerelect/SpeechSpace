import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speechspace/main.dart';
import 'package:speechspace/models/models.dart';
import 'package:speechspace/services/app_controller.dart';
import 'package:speechspace/services/repository.dart';

class DelayedRepository extends DemoRepository {
  final pending = Completer<AppSnapshot>();
  @override
  Future<AppSnapshot> load() => pending.future;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('stalled preferences release startup and late results cannot switch profiles', (tester) async {
    final preferences = Completer<SharedPreferences>();
    final controller = AppController(DemoRepository(), preferencesLoader: () => preferences.future);
    final startup = controller.initialize();
    await tester.pumpWidget(SpeechSpaceApp(controller: controller));
    expect(find.text('Opening SpeechSpace'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await startup;
    await tester.pumpAndSettle();
    expect(find.text("Who's using SpeechSpace?"), findsOneWidget);
    expect(controller.loadError, isNull);
    controller.enterApp('demo-alex');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppController.selectedProfileKey, 'demo-jordan');
    preferences.complete(prefs);
    await tester.pumpAndSettle();
    expect(controller.selectedProfileId, 'demo-alex');
  });

  testWidgets('preference timeout runs alongside API rather than after it', (tester) async {
    final repo = DelayedRepository();
    final controller = AppController(repo, preferencesLoader: () => Completer<SharedPreferences>().future);
    final startup = controller.initialize();
    await tester.pumpWidget(SpeechSpaceApp(controller: controller));
    await tester.pump(const Duration(seconds: 3));
    expect(controller.loading, isTrue);
    repo.pending.complete(await DemoRepository().load());
    await tester.pump();
    await startup;
    expect(controller.loading, isFalse);
    await tester.pumpAndSettle();
    expect(find.text("Who's using SpeechSpace?"), findsOneWidget);
  });

  testWidgets('unresponsive API times out and Retry recovers', (tester) async {
    var recover = false;
    final repo = RemoteRepository(baseUrl: 'https://example.test', devToken: 'test',
      client: MockClient((_) => recover
        ? Future.value(http.Response('{"children":[{"id":"p1","name":"Test profile","kind":"adult","themeId":"indigo"}],"entries":[],"links":[],"projects":[]}', 200))
        : Completer<http.Response>().future));
    final controller = AppController(repo, persistSelection: false);
    final startup = controller.initialize();
    await tester.pumpWidget(SpeechSpaceApp(controller: controller));
    expect(find.text('Opening SpeechSpace'), findsOneWidget);
    await tester.pump(const Duration(seconds: 15));
    await startup;
    await tester.pumpAndSettle();
    expect(find.text('Cannot connect to the backend'), findsOneWidget);
    recover = true;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(controller.loading, isFalse);
    expect(controller.loadError, isNull);
    expect(find.text("Who's using SpeechSpace?"), findsOneWidget);
  });
}

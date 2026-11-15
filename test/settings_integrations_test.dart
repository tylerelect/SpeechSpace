import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speechspace/screens/settings_page.dart';
import 'package:speechspace/services/app_controller.dart';
import 'package:speechspace/services/repository.dart';

void main() {
  testWidgets('settings help opens integrations and returns to settings', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(DemoRepository());
    await controller.initialize();
    controller.enterApp('demo-jordan');
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SettingsPage(controller: controller))));
    expect(find.text('MongoDB Atlas'), findsNothing);
    await tester.tap(find.byTooltip('Integration information'));
    await tester.pumpAndSettle();
    expect(find.text('Integrations'), findsOneWidget);
    expect(find.text('MongoDB Atlas'), findsOneWidget);
    expect(find.text('Voice transcription'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Integration information'), findsOneWidget);
  });
}

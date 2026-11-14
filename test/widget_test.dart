import 'package:flutter_test/flutter_test.dart';
import 'package:speechspace/main.dart';
import 'package:speechspace/services/app_controller.dart';
import 'package:speechspace/services/repository.dart';

void main() {
  testWidgets('synthetic demo renders the childhood memory dashboard', (tester) async {
    final controller = AppController(DemoRepository());
    await controller.initialize();
    await tester.pumpWidget(SpeechSpaceApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('SpeechSpace'), findsOneWidget);
    expect(find.text('Every day tells a story.'), findsOneWidget);
    expect(find.text('Add today\'s memory'), findsOneWidget);
  });
}

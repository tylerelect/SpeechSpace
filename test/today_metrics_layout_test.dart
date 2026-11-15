import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speechspace/main.dart';
import 'package:speechspace/services/app_controller.dart';
import 'package:speechspace/services/repository.dart';

import 'support/fake_backend.dart';

/// The adult Today metrics must form a 2x2 grid on a phone (not one half-width
/// card per row) and a single row of four on a wide screen.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<List<Offset>> metricTopLefts(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final b = FakeBackend();
    final c = AppController(RemoteRepository(baseUrl: 'http://test', devToken: 't', client: b.client));
    await c.initialize();
    c.enterApp('a1');
    await tester.pumpWidget(SpeechSpaceApp(controller: c));
    await tester.pumpAndSettle();
    return [
      for (final label in ['Days recorded', 'Connections', 'Milestones'])
        tester.getTopLeft(find.ancestor(of: find.text(label), matching: find.byType(Card)).first),
    ];
  }

  testWidgets('iPhone width: metrics are a 2x2 grid', (tester) async {
    final p = await metricTopLefts(tester, const Size(393, 852)); // iPhone 15/16 logical size
    final days = p[0], connections = p[1], milestones = p[2];
    expect(connections.dy, greaterThan(days.dy), reason: 'Connections starts the second row');
    expect(milestones.dy, connections.dy, reason: 'Connections and Milestones share the second row');
    expect(milestones.dx, days.dx, reason: 'right column lines up');
  });

  testWidgets('wide screen: metrics are one row', (tester) async {
    final p = await metricTopLefts(tester, const Size(1200, 1600));
    expect(p.map((o) => o.dy).toSet().length, 1);
  });
}

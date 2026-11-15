import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speechspace/models/calendar.dart';
import 'package:speechspace/widgets/cursor_trail.dart';
import 'package:speechspace/widgets/space_art.dart';

import 'calendar_test.dart' show fixture, pumpCalendar, remote;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('calendar on a phone', () {
    for (final size in const [Size(320, 900), Size(360, 900), Size(390, 900)]) {
      for (final kids in [true, false]) {
        testWidgets('${kids ? 'Kids' : 'Adult'} month view at ${size.width.toInt()}px has no overflow', (tester) async {
          final c = await remote(fixture(), profile: kids ? 'k1' : 'a1');
          c.setCalendar(CalendarView.month, DateTime(2026, 11, 14));
          await pumpCalendar(tester, c, size: size);
          expect(tester.takeException(), isNull);
          expect(find.text('Active days'), findsOneWidget);
          expect(find.text('Milestones'), findsOneWidget);
          // "Month" stays on one line: no checkmark crowding it.
          expect(find.byIcon(Icons.check), findsNothing);
          expect(find.byType(SpaceArt), kids ? findsWidgets : findsNothing);
        });
      }
    }
  });

  testWidgets('every view fits a 320px phone in Kids and Adult mode', (tester) async {
    for (final profile in ['k1', 'a1']) {
      final c = await remote(fixture(), profile: profile);
      for (final view in CalendarView.values) {
        c.setCalendar(view, DateTime(2026, 11, 14));
        await pumpCalendar(tester, c, size: const Size(320, 900));
        expect(tester.takeException(), isNull, reason: '$profile ${view.wire}');
      }
    }
  });

  group('Ocean and Sunshine', () {
    for (final theme in ['ocean', 'sunshine']) {
      testWidgets('$theme: themed art, Nunito font, calendar fits a phone', (tester) async {
        final c = await remote(fixture(), profile: 'k1');
        await c.setTheme(theme);
        expect(c.spaceTheme.id, theme);
        expect(c.theme.textTheme.bodyMedium?.fontFamily, contains('Nunito'));
        for (final view in CalendarView.values) {
          c.setCalendar(view, DateTime(2026, 11, 14));
          await pumpCalendar(tester, c, size: const Size(320, 900));
          expect(tester.takeException(), isNull, reason: '$theme ${view.wire}');
        }
        // The title art follows the theme (no rocket/planet outside Space).
        final kinds = tester.widgetList<SpaceArt>(find.byType(SpaceArt)).map((a) => a.kind).toSet();
        expect(kinds, contains(artFor(theme, ArtRole.big)));
        expect(kinds, isNot(contains(SpaceArtKind.planet)));
      });

      testWidgets('$theme: backdrop and trail render without errors', (tester) async {
        await tester.pumpWidget(MaterialApp(
            builder: (_, child) => SpaceCursorTrail(enabled: true, themeId: theme, child: child!),
            home: Scaffold(body: Stack(children: [Positioned.fill(child: ThemeBackdrop(theme)), const Center(child: Text('Hi'))]))));
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(10, 10));
        addTearDown(mouse.removePointer);
        for (var x = 20.0; x < 300; x += 25) {
          await mouse.moveTo(Offset(x, x / 2));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.tap(find.text('Hi'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('space cursor trail', () {
    Future<void> pump(WidgetTester tester, {required bool enabled, required VoidCallback onTap}) =>
        tester.pumpWidget(MaterialApp(builder: (_, child) => SpaceCursorTrail(enabled: enabled, child: child!),
            home: Scaffold(body: Center(child: ElevatedButton(onPressed: onTap, child: const Text('Go'))))));

    testWidgets('taps pass through and the burst settles', (tester) async {
      var taps = 0;
      await pump(tester, enabled: true, onTap: () => taps++);
      await tester.tap(find.text('Go'));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.hasScheduledFrame, isTrue); // sparkles are animating
      await tester.pumpAndSettle(); // ...and then stop, so the ticker is idle
      expect(taps, 1);
    });

    testWidgets('a mouse brings out the rocket, which comes to rest', (tester) async {
      await pump(tester, enabled: true, onTap: () {});
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(10, 10));
      addTearDown(mouse.removePointer);
      for (var x = 20.0; x < 300; x += 20) {
        await mouse.moveTo(Offset(x, x / 2));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('disabled trail stays idle', (tester) async {
      var taps = 0;
      // A plain tap target (no ink ripple) so any scheduled frame would be the trail's.
      await tester.pumpWidget(MaterialApp(builder: (_, child) => SpaceCursorTrail(enabled: false, child: child!),
          home: GestureDetector(onTap: () => taps++, child: const ColoredBox(color: Colors.black, child: Text('Go')))));
      await tester.tap(find.text('Go'));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(taps, 1);
    });
  });
}

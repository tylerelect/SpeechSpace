import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speechspace/services/app_controller.dart';
import 'package:speechspace/services/repository.dart';
import 'package:speechspace/widgets/entry_editor.dart';
import 'package:speechspace/widgets/voice_capture.dart';

class FakeRecorder implements VoiceRecorder {
  FakeRecorder({this.permission = true});

  bool permission;
  Object? permissionError;
  Object? startError;
  Completer<bool>? permissionGate;
  Completer<void>? stopGate;
  // ignore: close_sinks (the code under test owns this stream; tests inspect it)
  StreamController<Uint8List>? stream;
  int permissionCalls = 0;
  int startCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;

  @override
  Future<bool> hasPermission() async {
    permissionCalls++;
    if (permissionError != null) throw permissionError!;
    if (permissionGate != null) return permissionGate!.future;
    return permission;
  }

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
    startCalls++;
    if (startError != null) throw startError!;
    stream = StreamController<Uint8List>();
    return stream!.stream;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    if (stopGate != null) await stopGate!.future;
  }

  @override
  Future<void> dispose() async => disposeCalls++;

  void add(int bytes) => stream!.add(Uint8List(bytes));
}

class Harness {
  final events = <bool>[];
  final transcripts = <String>[];
  final uploads = <Uint8List>[];
  Future<String> Function(Uint8List wav) respond = (_) async => 'hello world';

  Future<String> transcribe(Uint8List wav) {
    uploads.add(wav);
    return respond(wav);
  }
}

Future<void> pumpCapture(WidgetTester tester, FakeRecorder recorder, Harness h, {bool approve = true}) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: VoiceCapture(
    onTranscribe: h.transcribe,
    onTranscript: h.transcripts.add,
    onRecordingChanged: h.events.add,
    recorderFactory: () => recorder,
  )))));
  if (approve) {
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
  }
}

FilledButton recordButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byWidgetPredicate((w) => w is FilledButton));

Future<void> startRecording(WidgetTester tester) async {
  await tester.tap(find.text('Record'));
  await tester.pump();
  await tester.pump();
  expect(find.text('Stop'), findsOneWidget);
}

Future<void> stopRecording(WidgetTester tester) async {
  await tester.tap(find.text('Stop'));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('guardian approval is required before Record is enabled', (tester) async {
    final recorder = FakeRecorder();
    final h = Harness();
    await pumpCapture(tester, recorder, h, approve: false);
    expect(recordButton(tester).onPressed, isNull);
    await tester.tap(find.text('Record'));
    await tester.pump();
    expect(recorder.permissionCalls, 0);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(recordButton(tester).onPressed, isNotNull);
  });

  testWidgets('permission denied shows a clear message and re-enables Record', (tester) async {
    final recorder = FakeRecorder(permission: false);
    final h = Harness();
    await pumpCapture(tester, recorder, h);
    await tester.tap(find.text('Record'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Microphone permission is required'), findsOneWidget);
    expect(find.textContaining('Bad state'), findsNothing);
    expect(find.text('Record'), findsOneWidget);
    expect(recordButton(tester).onPressed, isNotNull);
    expect(recorder.startCalls, 0);
    expect(h.events, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a permission check that throws is reported without a crash', (tester) async {
    final recorder = FakeRecorder()..permissionError = Exception('plugin missing');
    final h = Harness();
    await pumpCapture(tester, recorder, h);
    await tester.tap(find.text('Record'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('plugin missing'), findsOneWidget);
    expect(recordButton(tester).onPressed, isNotNull);
    expect(h.events, isEmpty);
  });

  testWidgets('a failure to start the stream releases the music pause', (tester) async {
    final recorder = FakeRecorder()..startError = Exception('mic busy');
    final h = Harness();
    await pumpCapture(tester, recorder, h);
    await tester.tap(find.text('Record'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('mic busy'), findsOneWidget);
    expect(h.events, [true, false]);
    expect(find.text('Record'), findsOneWidget);
  });

  testWidgets('double taps start one recording and upload once', (tester) async {
    final recorder = FakeRecorder();
    final h = Harness();
    await pumpCapture(tester, recorder, h);
    await tester.tap(find.text('Record'));
    await tester.tap(find.text('Record'));
    await tester.pump();
    await tester.pump();
    expect(recorder.permissionCalls, 1);
    expect(recorder.startCalls, 1);
    expect(h.events, [true]);

    recorder.add(3200);
    await tester.pump();
    await tester.tap(find.text('Stop'));
    await tester.tap(find.text('Stop'));
    await tester.pump();
    await tester.pump();
    expect(recorder.stopCalls, 1);
    expect(h.uploads, hasLength(1));
    expect(h.uploads.single.length, 44 + 3200);
    expect(String.fromCharCodes(h.uploads.single.sublist(0, 4)), 'RIFF');
    expect(h.transcripts, ['hello world']);
    expect(h.events, [true, false]);
    expect(find.text('Record'), findsOneWidget);
  });

  testWidgets('empty audio shows "No audio was captured" and does not upload', (tester) async {
    final recorder = FakeRecorder();
    final h = Harness();
    await pumpCapture(tester, recorder, h);
    await startRecording(tester);
    await stopRecording(tester);
    expect(find.textContaining('No audio was captured'), findsOneWidget);
    expect(h.uploads, isEmpty);
    expect(h.events, [true, false]);
    expect(recordButton(tester).onPressed, isNotNull);
  });

  testWidgets('blank transcripts are reported as no speech recognized', (tester) async {
    final recorder = FakeRecorder();
    final h = Harness()..respond = (_) async => '   ';
    await pumpCapture(tester, recorder, h);
    await startRecording(tester);
    recorder.add(640);
    await tester.pump();
    await stopRecording(tester);
    expect(find.textContaining('No speech was recognized'), findsOneWidget);
    expect(h.transcripts, isEmpty);
  });

  for (final status in [503, 413, 504]) {
    testWidgets('ApiException $status shows its message and Record works again', (tester) async {
      final recorder = FakeRecorder();
      final message = transcribeErrorMessage(status, '');
      final h = Harness()..respond = (_) async => throw ApiException(status, message);
      await pumpCapture(tester, recorder, h);
      await startRecording(tester);
      recorder.add(640);
      await tester.pump();
      await stopRecording(tester);
      expect(find.text(message), findsOneWidget);
      expect(h.transcripts, isEmpty);
      expect(h.events, [true, false]);
      expect(find.text('Record'), findsOneWidget);
      expect(recordButton(tester).onPressed, isNotNull);
    });
  }

  testWidgets('retry after a transcription error succeeds and clears the error', (tester) async {
    final recorder = FakeRecorder();
    var attempt = 0;
    final h = Harness()
      ..respond = (_) async {
        attempt++;
        if (attempt == 1) throw const ApiException(504, 'Transcription timed out. Try a shorter recording.');
        return 'second try';
      };
    await pumpCapture(tester, recorder, h);
    await startRecording(tester);
    recorder.add(640);
    await tester.pump();
    await stopRecording(tester);
    expect(find.textContaining('timed out'), findsOneWidget);

    await startRecording(tester);
    expect(find.textContaining('timed out'), findsNothing);
    recorder.add(640);
    await tester.pump();
    await stopRecording(tester);
    expect(h.uploads, hasLength(2));
    expect(h.uploads.last.length, 44 + 640); // first attempt's audio is not resent
    expect(h.transcripts, ['second try']);
    expect(h.events, [true, false, true, false]);
  });

  testWidgets('the 90-second cap stops recording and uploads exactly once', (tester) async {
    final recorder = FakeRecorder();
    final h = Harness();
    await pumpCapture(tester, recorder, h);
    await startRecording(tester);
    const chunk = 32000; // one second
    for (var i = 0; i < 89; i++) { recorder.add(chunk); }
    await tester.pump();
    expect(h.uploads, isEmpty);
    // Cross the cap, then keep sending: only the first 90 seconds are kept.
    recorder.add(chunk + 100);
    recorder.add(chunk);
    recorder.add(chunk);
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(recorder.stopCalls, 1);
    expect(h.uploads, hasLength(1));
    expect(h.uploads.single.length, 44 + VoiceCapture.maxBytes);
    expect(h.transcripts, ['hello world']);
    expect(h.events, [true, false]);
    expect(find.text('Record'), findsOneWidget);
  });

  testWidgets('disposing while recording stops the recorder without uploading', (tester) async {
    final recorder = FakeRecorder();
    final h = Harness();
    await pumpCapture(tester, recorder, h);
    await startRecording(tester);
    recorder.add(640);
    await tester.pump();
    final stream = recorder.stream!; // ignore: close_sinks
    expect(stream.hasListener, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(stream.hasListener, isFalse);
    expect(recorder.stopCalls, 1);
    expect(recorder.disposeCalls, 1);
    expect(h.uploads, isEmpty);
    expect(h.events, [true, false]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing while the permission prompt is open never opens the mic', (tester) async {
    final recorder = FakeRecorder()..permissionGate = Completer<bool>();
    final h = Harness();
    await pumpCapture(tester, recorder, h);
    await tester.tap(find.text('Record'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    recorder.permissionGate!.complete(true);
    await tester.pump();
    await tester.pump();
    expect(recorder.startCalls, 0);
    expect(recorder.disposeCalls, 1);
    expect(h.events, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing while stopping does not upload', (tester) async {
    final recorder = FakeRecorder()..stopGate = Completer<void>();
    final h = Harness();
    await pumpCapture(tester, recorder, h);
    await startRecording(tester);
    recorder.add(640);
    await tester.pump();
    await tester.tap(find.text('Stop'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    recorder.stopGate!.complete();
    await tester.pump();
    await tester.pump();
    expect(h.uploads, isEmpty);
    expect(h.events, [true, false]);
    expect(recorder.disposeCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing during transcription ignores the late result', (tester) async {
    final recorder = FakeRecorder();
    final pending = Completer<String>();
    final h = Harness()..respond = (_) => pending.future;
    await pumpCapture(tester, recorder, h);
    await startRecording(tester);
    recorder.add(640);
    await tester.pump();
    await stopRecording(tester);
    expect(h.uploads, hasLength(1));
    expect(find.text('Working…'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    pending.complete('too late');
    await tester.pump();
    expect(h.transcripts, isEmpty);
    expect(h.events, [true, false]);
    expect(tester.takeException(), isNull);
  });

  group('entry editor', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('keeps typed text when transcription fails', (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = AppController(_FailingTranscribeRepository());
      await controller.initialize();
      controller.enterApp('demo-alex');
      final recorder = FakeRecorder();
      await tester.pumpWidget(MaterialApp(theme: controller.theme, home: Scaffold(
          body: EntryEditor(controller: controller, initialDate: DateTime.now(),
              voiceRecorderFactory: () => recorder))));
      await tester.pumpAndSettle();

      final body = find.widgetWithText(TextField, 'What happened?');
      await tester.enterText(body, 'We flew a kite at the park');
      await tester.pump();

      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('Record'));
      await tester.pump();
      await tester.pump();
      recorder.add(640);
      await tester.pump();
      await tester.tap(find.text('Stop'));
      await tester.pump();
      await tester.pump();

      expect(find.text(transcribeErrorMessage(503, '')), findsOneWidget);
      expect(tester.widget<TextField>(body).controller!.text, 'We flew a kite at the park');
      expect(recorder.stopCalls, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  });
}

class _FailingTranscribeRepository extends DemoRepository {
  @override
  Future<String> transcribe(Uint8List wav) =>
      Future.error(ApiException(503, transcribeErrorMessage(503, '')));
}

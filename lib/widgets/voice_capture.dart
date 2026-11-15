import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:record/record.dart';

/// The subset of the `record` package used by [VoiceCapture]. Tests inject a fake.
abstract class VoiceRecorder {
  Future<bool> hasPermission();
  Future<Stream<Uint8List>> startStream(RecordConfig config);
  Future<void> stop();
  Future<void> dispose();
}

/// Default [VoiceRecorder] backed by the `record` package's [AudioRecorder].
class RecordPackageRecorder implements VoiceRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  @override
  Future<bool> hasPermission() => _recorder.hasPermission();
  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) => _recorder.startStream(config);
  @override
  Future<void> stop() async { await _recorder.stop(); }
  @override
  Future<void> dispose() => _recorder.dispose();
}

/// Records PCM to memory, wraps it in WAV, and hands bytes to the configured
/// transcription adapter. This widget does not pick or embed an STT model.
class VoiceCapture extends StatefulWidget {
  const VoiceCapture({super.key, required this.onTranscribe, required this.onTranscript,
      this.prompt = 'Speak your memory', this.onRecordingChanged, this.recorderFactory,
      this.requireGuardianApproval = true});

  final Future<String> Function(Uint8List wav) onTranscribe;
  final ValueChanged<String> onTranscript;
  final String prompt;
  /// Kids profiles need a guardian to tick a box before recording; Adult profiles don't.
  final bool requireGuardianApproval;
  /// Lets the app pause background audio so it is not captured by the microphone.
  /// Always called in pairs: true when the microphone opens, false when it closes.
  final ValueChanged<bool>? onRecordingChanged;
  /// Creates the recorder (once per widget). Defaults to [RecordPackageRecorder].
  final VoiceRecorder Function()? recorderFactory;

  /// 90 seconds of mono 16 kHz PCM16.
  static const maxBytes = 16000 * 2 * 90;

  @override
  State<VoiceCapture> createState() => _VoiceCaptureState();
}

class _VoiceCaptureState extends State<VoiceCapture> {
  late final VoiceRecorder _recorder = (widget.recorderFactory ?? RecordPackageRecorder.new)();
  StreamSubscription<Uint8List>? _subscription;
  BytesBuilder _audio = BytesBuilder(copy: false);
  bool _recording = false;
  bool _working = false;
  bool _guardianApproved = false;
  bool _micOpen = false; // whether onRecordingChanged(true) is outstanding
  bool _starting = false; // a start is awaiting the platform
  bool _disposed = false;
  String? _error;
  int _size = 0;

  void _setMic(bool open) {
    if (_micOpen == open) return;
    _micOpen = open;
    widget.onRecordingChanged?.call(open);
  }

  void _update(VoidCallback change) {
    if (mounted && !_disposed) setState(change);
  }

  static String _describe(Object error) =>
      error is StateError ? error.message : error.toString();

  Future<void> _start() async {
    if (_working || _recording || _disposed) return;
    setState(() { _working = true; _error = null; });
    _starting = true;
    try {
      final allowed = await _recorder.hasPermission();
      if (_disposed) return;
      if (!allowed) throw StateError('Microphone permission is required. Allow it in system settings, or type instead.');
      _setMic(true);
      _audio = BytesBuilder(copy: false);
      _size = 0;
      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ));
      if (_disposed) return;
      _subscription = stream.listen(_onAudio, onError: (Object error) {
        _update(() => _error = _describe(error));
      });
      _recording = true;
    } catch (error) {
      _setMic(false);
      _update(() => _error = _describe(error));
    } finally {
      _starting = false;
      if (_disposed) {
        unawaited(_shutdown(stopRecorder: true));
      } else {
        _update(() => _working = false);
      }
    }
  }

  void _onAudio(Uint8List bytes) {
    if (!_recording || _disposed) return;
    final room = VoiceCapture.maxBytes - _size;
    if (room > 0) {
      final chunk = bytes.length <= room ? bytes : Uint8List.sublistView(bytes, 0, room);
      _size += chunk.length;
      _audio.add(chunk);
    }
    // Stop (and upload once) as soon as the 90-second cap is reached.
    if (_size >= VoiceCapture.maxBytes) _stop();
  }

  Future<void> _stop() async {
    if (_working || !_recording || _disposed) return;
    setState(() { _working = true; _recording = false; });
    try {
      final subscription = _subscription;
      _subscription = null;
      try {
        await _recorder.stop();
      } finally {
        // Cancelling detaches the listener synchronously; no need to wait.
        unawaited(subscription?.cancel());
        _setMic(false);
      }
      if (_disposed) return;
      final pcm = _audio.takeBytes();
      if (pcm.isEmpty) throw StateError('No audio was captured. Check the microphone and try again.');
      final result = await widget.onTranscribe(_makeWav(pcm));
      if (_disposed) return;
      if (result.trim().isEmpty) throw StateError('No speech was recognized. Try again, closer to the microphone.');
      widget.onTranscript(result);
    } catch (error) {
      _update(() => _error = _describe(error));
    } finally {
      _update(() => _working = false);
    }
  }

  Future<void> _shutdown({required bool stopRecorder}) async {
    try {
      if (stopRecorder) await _recorder.stop();
    } catch (_) {
      // Best effort: the widget is gone.
    }
    try {
      await _recorder.dispose();
    } catch (_) {}
  }

  Uint8List _makeWav(Uint8List pcm) {
    final result = Uint8List(44 + pcm.length);
    final data = ByteData.sublistView(result);
    void text(int offset, String value) {
      for (var i = 0; i < value.length; i++) { result[offset + i] = value.codeUnitAt(i); }
    }
    text(0, 'RIFF');
    data.setUint32(4, 36 + pcm.length, Endian.little);
    text(8, 'WAVE'); text(12, 'fmt ');
    data.setUint32(16, 16, Endian.little); // PCM format block
    data.setUint16(20, 1, Endian.little); // Linear PCM
    data.setUint16(22, 1, Endian.little); // Mono
    data.setUint32(24, 16000, Endian.little);
    data.setUint32(28, 32000, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    text(36, 'data');
    data.setUint32(40, pcm.length, Endian.little);
    result.setRange(44, result.length, pcm);
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    final wasRecording = _recording;
    _recording = false;
    _subscription?.cancel();
    _subscription = null;
    _setMic(false);
    // A start still awaiting the platform finishes the shutdown itself.
    if (!_starting) unawaited(_shutdown(stopRecorder: wasRecording));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .34),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(_recording ? Icons.mic : Icons.mic_none_rounded),
            const SizedBox(width: 9),
            Expanded(child: Text(_recording ? 'Recording… tap Stop when finished' : widget.prompt,
                style: const TextStyle(fontWeight: FontWeight.w600))),
            FilledButton.tonalIcon(
              onPressed: _working || (widget.requireGuardianApproval && !_guardianApproved && !_recording) ? null : (_recording ? _stop : _start),
              icon: Icon(_recording ? Icons.stop_circle_outlined : Icons.fiber_manual_record),
              label: Text(_working ? 'Working…' : (_recording ? 'Stop' : 'Record')),
            ),
          ]),
          if (widget.requireGuardianApproval) CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            title: const Text('Guardian has approved this recording', style: TextStyle(fontSize: 12)),
            value: _guardianApproved,
            onChanged: _recording || _working ? null : (value) => setState(() => _guardianApproved = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 6),
          const Text('Recording is capped at 90 seconds.',
              style: TextStyle(fontSize: 12)),
          if (_error != null) Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ]),
      ),
    );
  }
}

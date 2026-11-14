import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:record/record.dart';

/// Records PCM to memory, wraps it in WAV, and hands bytes to the configured
/// transcription adapter. This widget does not pick or embed an STT model.
class VoiceCapture extends StatefulWidget {
  const VoiceCapture({super.key, required this.onTranscribe, required this.onTranscript});

  final Future<String> Function(Uint8List wav) onTranscribe;
  final ValueChanged<String> onTranscript;

  @override
  State<VoiceCapture> createState() => _VoiceCaptureState();
}

class _VoiceCaptureState extends State<VoiceCapture> {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _subscription;
  BytesBuilder _audio = BytesBuilder(copy: false);
  bool _recording = false;
  bool _working = false;
  bool _guardianApproved = false;
  String? _error;
  int _size = 0;
  static const _maxBytes = 16000 * 2 * 90; // 90 seconds of mono 16kHz PCM16

  Future<void> _start() async {
    setState(() { _working = true; _error = null; });
    try {
      if (!await _recorder.hasPermission()) throw StateError('Microphone permission is required.');
      _audio = BytesBuilder(copy: false);
      _size = 0;
      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ));
      _subscription = stream.listen((bytes) {
        if (_size + bytes.length <= _maxBytes) {
          _size += bytes.length;
          _audio.add(bytes);
        } else {
          // Stop asynchronously when the 90-second cap is reached.
          if (_recording && !_working) { _stop(); }
        }
      }, onError: (Object error) {
        if (mounted) setState(() => _error = error.toString());
      });
      if (mounted) setState(() => _recording = true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _stop() async {
    if (_working || !_recording) return;
    setState(() { _working = true; _recording = false; });
    try {
      await _recorder.stop();
      await _subscription?.cancel();
      final pcm = _audio.takeBytes();
      if (pcm.isEmpty) throw StateError('No audio was captured.');
      final result = await widget.onTranscribe(_makeWav(pcm));
      if (result.trim().isEmpty) throw StateError('No speech was recognized.');
      widget.onTranscript(result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
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
    _subscription?.cancel();
    _recorder.dispose();
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
            Expanded(child: Text(_recording ? 'Recording… tap Stop when finished' : 'Speak your memory',
                style: const TextStyle(fontWeight: FontWeight.w600))),
            FilledButton.tonalIcon(
              onPressed: _working || (!_guardianApproved && !_recording) ? null : (_recording ? _stop : _start),
              icon: Icon(_recording ? Icons.stop_circle_outlined : Icons.fiber_manual_record),
              label: Text(_working ? 'Working…' : (_recording ? 'Stop' : 'Record')),
            ),
          ]),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            title: const Text('Guardian has approved this recording', style: TextStyle(fontSize: 12)),
            value: _guardianApproved,
            onChanged: _recording || _working ? null : (value) => setState(() => _guardianApproved = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 6),
          const Text('Voice recognition uses a replaceable server adapter. Recording is capped at 90 seconds.',
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

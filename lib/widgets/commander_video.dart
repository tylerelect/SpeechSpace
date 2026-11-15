import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/sound_service.dart';

/// Plays the commander briefing video in a dialog. Uses [voice] if given
/// (e.g. a preview during setup), otherwise the sound service's current voice.
/// Must be called from a user tap so browsers allow playback with sound.
Future<void> showCommanderBriefing(BuildContext context, SoundService sound, {String? voice}) {
  final id = voice ?? sound.voice;
  return showDialog<void>(
    context: context,
    builder: (_) => CommanderVideoDialog(sound: sound, asset: SoundService.videos[id] ?? SoundService.videos['f']!),
  );
}

class CommanderVideoDialog extends StatefulWidget {
  const CommanderVideoDialog({super.key, required this.sound, required this.asset});
  final SoundService sound;
  final String asset;

  @override
  State<CommanderVideoDialog> createState() => _CommanderVideoDialogState();
}

class _CommanderVideoDialogState extends State<CommanderVideoDialog> {
  late final VideoPlayerController _video = VideoPlayerController.asset(widget.asset);
  String? _error;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _video.addListener(_onTick);
    _start();
  }

  Future<void> _start() async {
    try {
      await _video.initialize();
      if (!mounted) return;
      await widget.sound.briefingStarted(_close);
      await _video.play();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = 'The commander video could not play: $e');
    }
  }

  void _onTick() {
    final v = _video.value;
    if (v.hasError && _error == null) {
      setState(() => _error = 'The commander video could not play: ${v.errorDescription}');
      return;
    }
    final done = v.isInitialized && !v.isPlaying && v.duration > Duration.zero && v.position >= v.duration;
    if (done && !_finished) {
      setState(() => _finished = true);
      widget.sound.briefingEnded();
    }
  }

  Future<void> _replay() async {
    setState(() => _finished = false);
    await widget.sound.briefingStarted(_close);
    await _video.seekTo(Duration.zero);
    await _video.play();
  }

  void _close() {
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _video.removeListener(_onTick);
    _video.dispose();
    final sound = widget.sound;
    // Deferred: notifying listeners during unmount is not allowed.
    Future.microtask(sound.briefingEnded);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ready = _video.value.isInitialized;
    return Dialog(
      clipBehavior: Clip.antiAlias,
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: _error != null
              ? Padding(padding: const EdgeInsets.all(24),
                  child: Text(_error!, style: const TextStyle(color: Colors.white)))
              : !ready
                  ? const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()))
                  : AspectRatio(aspectRatio: _video.value.aspectRatio, child: VideoPlayer(_video))),
          if (ready) VideoProgressIndicator(_video, allowScrubbing: false,
              colors: VideoProgressColors(playedColor: scheme.primary)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: Row(children: [
            if (ready && _error == null) IconButton(
              color: Colors.white,
              tooltip: _finished ? 'Watch again' : (_video.value.isPlaying ? 'Pause' : 'Play'),
              icon: Icon(_finished ? Icons.replay : (_video.value.isPlaying ? Icons.pause : Icons.play_arrow)),
              onPressed: () {
                if (_finished) { _replay(); }
                else if (_video.value.isPlaying) { _video.pause(); }
                else { _video.play(); }
                setState(() {});
              },
            ),
            const Spacer(),
            TextButton(onPressed: _close, child: const Text('Close', style: TextStyle(color: Colors.white))),
          ])),
        ]),
      ),
    );
  }
}

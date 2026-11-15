import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Kids-mode audio: looping space background music, plus the commander choice
/// and music ducking for the commander briefing video (see commander_video.dart).
///
/// Players are created lazily on first use, so tests and Adult mode never touch
/// the audio plugin. Browsers only allow playback after a user gesture, which is
/// why nothing here auto-plays on launch.
class SoundService extends ChangeNotifier {
  static const tracks = <String>[
    'sound/bgmusic_1.mp3',
    'sound/bgmusic_2.mp3',
    'sound/bgmusic_3.mp3',
    'sound/bgmusic_4.mp3',
  ];
  /// Commander briefing videos, by voice. Full asset paths (video_player needs them).
  static const videos = <String, String>{
    'f': 'assets/sound/videos/commander_f.mp4',
    'm': 'assets/sound/videos/commander_m.mp4',
  };
  static const _musicVolume = .35;
  static const _duckedVolume = .1;

  AudioPlayer? _music;
  VoidCallback? _stopVideo;

  bool musicOn = false;
  bool briefingPlaying = false;
  int trackIndex = 0;
  String voice = 'f';
  bool _pausedForRecording = false;
  String? error;

  AudioPlayer get _musicPlayer => _music ??= AudioPlayer()..setReleaseMode(ReleaseMode.loop);

  Future<void> toggleMusic() => musicOn ? stopMusic() : startMusic();

  Future<void> startMusic() async {
    musicOn = true;
    notifyListeners();
    await _guard(() => _musicPlayer.play(AssetSource(tracks[trackIndex]),
        volume: briefingPlaying ? _duckedVolume : _musicVolume));
  }

  Future<void> stopMusic() async {
    musicOn = false;
    notifyListeners();
    if (_music != null) await _guard(() => _music!.stop());
  }

  Future<void> selectTrack(int index) async {
    if (index < 0 || index >= tracks.length) return;
    trackIndex = index;
    notifyListeners();
    if (musicOn) await startMusic();
  }

  void selectVoice(String id) {
    if (!videos.containsKey(id)) return;
    voice = id;
    notifyListeners();
  }

  /// Called by the briefing video when it starts playing; ducks the music.
  /// [stop] lets other code (switching user, recording) end the video.
  Future<void> briefingStarted(VoidCallback stop) async {
    _stopVideo = stop;
    briefingPlaying = true;
    notifyListeners();
    if (musicOn && _music != null) await _guard(() => _music!.setVolume(_duckedVolume));
  }

  /// Called by the briefing video when it finishes or closes; restores the music.
  Future<void> briefingEnded() async {
    _stopVideo = null;
    if (!briefingPlaying) return;
    briefingPlaying = false;
    notifyListeners();
    if (musicOn && _music != null) await _guard(() => _music!.setVolume(_musicVolume));
  }

  Future<void> stopBriefing() async {
    _stopVideo?.call();
    await briefingEnded();
  }

  /// Keep music and voice out of the microphone while a memory is recorded.
  Future<void> onRecordingChanged(bool recording) async {
    if (recording) {
      if (briefingPlaying) await stopBriefing();
      if (musicOn && _music != null) {
        _pausedForRecording = true;
        await _guard(() => _music!.pause());
      }
    } else if (_pausedForRecording) {
      _pausedForRecording = false;
      if (musicOn && _music != null) await _guard(() => _music!.resume());
    }
  }

  /// Called when the active profile changes; Adult mode is silent.
  Future<void> onProfileKindChanged(bool isKids) async {
    if (isKids) return;
    if (briefingPlaying) await stopBriefing();
    if (musicOn) await stopMusic();
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
      if (error != null) { error = null; notifyListeners(); }
    } catch (e) {
      error = 'Sound could not play: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _music?.dispose();
    super.dispose();
  }
}

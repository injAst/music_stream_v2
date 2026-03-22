import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../data/models/track.dart';

class AudioPlayerController extends ChangeNotifier {
  AudioPlayerController() {
    _player.playerStateStream.listen((_) => notifyListeners());
    _player.positionStream.listen((_) => notifyListeners());
    _player.durationStream.listen((_) => notifyListeners());
  }

  final AudioPlayer _player = AudioPlayer();
  Track? _queue;

  Track? get currentTrack => _queue;
  AudioPlayer get player => _player;

  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;

  Future<void> playTrack(Track track) async {
    _queue = track;
    notifyListeners();
    try {
      await _player.setUrl(track.streamUrl);
      await _player.play();
    } catch (e) {
      debugPrint('playTrack error: $e');
      rethrow;
    }
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      if (_queue != null && _player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    }
  }

  Future<void> seek(Duration position) => _player.seek(position);

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../core/config/api_config.dart';
import '../data/models/track.dart';
import 'library_controller.dart';

class AudioPlayerController extends ChangeNotifier {
  AudioPlayerController() {
    _player.playerStateStream.listen((_) => notifyListeners());
    _player.positionStream.listen((_) => notifyListeners());
    _player.durationStream.listen((d) {
       _handleDurationChange(d);
       notifyListeners();
    });
    _player.shuffleModeEnabledStream.listen((_) => notifyListeners());
    _player.loopModeStream.listen((_) => notifyListeners());
    
    // Слушаем изменение индекса текущего трека
    _player.currentIndexStream.listen((index) {
      if (index != null && _currentPlaylist.isNotEmpty) {
        _currentIndex = index;
        notifyListeners();
      }
    });
  }

  final AudioPlayer _player = AudioPlayer();
  List<Track> _currentPlaylist = [];
  int _currentIndex = -1;
  LibraryController? _library;

  void setLibrary(LibraryController lib) {
    _library = lib;
  }

  void _handleDurationChange(Duration? d) {
    if (d == null || d.inSeconds == 0) return;
    final track = currentTrack;
    if (track != null && (track.durationSeconds == 0 || track.durationSeconds == null)) {
      // Авто-починка: обновляем в библиотеке
      _library?.updateTrackDuration(track.id, d.inSeconds);
      
      // И в текущем плейлисте плеера
      if (_currentIndex != -1) {
        _currentPlaylist[_currentIndex] = track.copyWith(durationSeconds: d.inSeconds);
      }
    }
  }

  Track? get currentTrack {
    if (_currentIndex >= 0 && _currentIndex < _currentPlaylist.length) {
      return _currentPlaylist[_currentIndex];
    }
    return null;
  }
  
  AudioPlayer get player => _player;

  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  
  bool get shuffleEnabled => _player.shuffleModeEnabled;
  LoopMode get loopMode => _player.loopMode;
  
  bool get hasNext => _player.hasNext;
  bool get hasPrevious => _player.hasPrevious;

  Future<void> playTrack(Track track, {List<Track>? playlist}) async {
    // Если передан плейлист, используем его, иначе создаем из одного трека
    _currentPlaylist = playlist != null ? List.from(playlist) : [track];
    _currentIndex = _currentPlaylist.indexOf(track);
    if (_currentIndex == -1) {
      _currentPlaylist.insert(0, track);
      _currentIndex = 0;
    }

    notifyListeners();

    try {
      final source = ConcatenatingAudioSource(
        children: _currentPlaylist.map((t) {
          final resolved = ApiConfig.resolveUrl(t.streamUrl) ?? t.streamUrl;
          return AudioSource.uri(Uri.parse(resolved));
        }).toList(),
      );
      
      await _player.setAudioSource(source, initialIndex: _currentIndex);
      await _player.play();
    } catch (e) {
      debugPrint('playTrack error: $e');
      rethrow;
    }
  }

  Future<void> playWave(List<Track> tracks) async {
    if (tracks.isEmpty) return;
    final shuffled = List<Track>.from(tracks)..shuffle();
    await _player.setLoopMode(LoopMode.all);
    await playTrack(shuffled.first, playlist: shuffled);
  }

  Future<void> next() async {
    if (_player.hasNext) {
      await _player.seekToNext();
    }
  }

  Future<void> previous() async {
    if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else {
      await _player.seek(Duration.zero);
    }
  }

  Future<void> toggleShuffle() async {
    final newValue = !_player.shuffleModeEnabled;
    await _player.setShuffleModeEnabled(newValue);
    if (newValue) {
      await _player.shuffle();
    }
  }

  Future<void> toggleLoopMode() async {
    switch (_player.loopMode) {
      case LoopMode.off:
        await _player.setLoopMode(LoopMode.all);
        break;
      case LoopMode.all:
        await _player.setLoopMode(LoopMode.one);
        break;
      case LoopMode.one:
        await _player.setLoopMode(LoopMode.off);
        break;
    }
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      if (currentTrack != null && _player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    }
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> stop() async {
    await _player.stop();
    _currentPlaylist = [];
    _currentIndex = -1;
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

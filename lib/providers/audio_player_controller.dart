import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/api_config.dart';
import '../data/models/track.dart';
import '../data/repositories/auth_repository.dart';
import 'library_controller.dart';

class AudioPlayerController extends ChangeNotifier {
  AudioPlayerController(this._prefs) {
    // Восстанавливаем громкость
    final savedVolume = _prefs.getDouble(_volumeKey) ?? 1.0;
    _player.setVolume(savedVolume);

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

    // Слушаем изменение громкости
    _player.volumeStream.listen((_) => notifyListeners());
  }

  final AudioPlayer _player = AudioPlayer();
  final SharedPreferences _prefs;
  static const _volumeKey = 'ms_volume_v1';
  List<Track> _currentPlaylist = [];
  ConcatenatingAudioSource? _playlistSource;
  int _currentIndex = -1;
  LibraryController? _library;
  AuthRepository? _authRepo;
  DateTime? _lastPlayedAt;

  void setLibrary(LibraryController lib) {
    _library = lib;
  }

  void setAuthRepo(AuthRepository repo) {
    _authRepo = repo;
  }

  DateTime? get lastPlayedAt => _lastPlayedAt;

  void setInitialTrack(Track track, DateTime? at) {
    // Устанавливаем, только если плеер пуст
    if (_currentIndex == -1 || _currentPlaylist.isEmpty) {
      _currentPlaylist = [track];
      _currentIndex = 0;
      _lastPlayedAt = at;
      
      // Настраиваем плеер без авто-запуска
      final resolved = ApiConfig.resolveUrl(track.streamUrl) ?? track.streamUrl;
      _player.setAudioSource(AudioSource.uri(Uri.parse(resolved)), preload: true);
      
      notifyListeners();
    }
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

  List<Track> get currentPlaylist => _currentPlaylist;

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

  double get volume => _player.volume;
  Future<void> setVolume(double value) async {
    await _player.setVolume(value);
    await _prefs.setDouble(_volumeKey, value);
    notifyListeners();
  }

  Future<void> playTrack(Track track, {List<Track>? playlist}) async {
    // Если передан плейлист, используем его, иначе создаем из одного трека
    _currentPlaylist = playlist != null ? List.from(playlist) : [track];
    _currentIndex = _currentPlaylist.indexOf(track);
    if (_currentIndex == -1) {
      _currentPlaylist.insert(0, track);
      _currentIndex = 0;
    }

    _lastPlayedAt = DateTime.now();
    notifyListeners();
    
    // Синхронизация с сервером
    _authRepo?.updateLastTrack(track.id);

    try {
      _playlistSource = ConcatenatingAudioSource(
        children: _currentPlaylist.map((t) {
          final resolved = ApiConfig.resolveUrl(t.streamUrl) ?? t.streamUrl;
          return AudioSource.uri(Uri.parse(resolved));
        }).toList(),
      );
      
      await _player.setAudioSource(_playlistSource!, initialIndex: _currentIndex);
      await _player.play();
    } catch (e) {
      debugPrint('playTrack error: $e');
      rethrow;
    }
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    
    // Обновляем список в памяти
    final track = _currentPlaylist.removeAt(oldIndex);
    _currentPlaylist.insert(newIndex, track);
    
    // Обновляем источник звука в плеере
    await _playlistSource?.move(oldIndex, newIndex);
    
    notifyListeners();
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

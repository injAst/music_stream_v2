import 'package:flutter/foundation.dart';

import '../data/models/user_profile.dart';
import '../data/models/track.dart';
import '../data/repositories/auth_repository.dart';
import 'library_controller.dart';
import 'audio_player_controller.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._repo);

  final AuthRepository _repo;
  LibraryController? _library;
  AudioPlayerController? _audioPlayer;

  UserProfile? _user;

  void setLibrary(LibraryController lib) {
    _library = lib;
  }

  void setAudioPlayer(AudioPlayerController player) {
    _audioPlayer = player;
  }

  UserProfile? get user => _user;
  bool get isLoggedIn => _user != null;

  Future<void> init() async {
    // 1. Мгновенная загрузка из кэша
    _user = await _repo.currentUser();
    if (_user != null) {
      _hydrateFromUser(_user!);
    }
    notifyListeners();

    // 2. Фоновое обновление с сервера
    if (isLoggedIn) {
      final updatedUser = await _repo.currentUser(forceRefresh: true);
      if (updatedUser != null) {
        _user = updatedUser;
        // Обновляем плеер данными с сервера, если они новее
        await _hydrateLastTrack();
      }
      notifyListeners();
    }
  }

  void _hydrateFromUser(UserProfile user) {
    if (user.lastTrack != null) {
      final lastAt = user.lastPlayedAt != null 
          ? DateTime.tryParse(user.lastPlayedAt!) 
          : null;
      
      final t = user.lastTrack!;
      final track = Track(
        id: t['id'].toString(),
        title: t['title'] ?? '',
        artist: t['artist'] ?? '',
        streamUrl: t['stream_url'] ?? '',
        artworkUrl: t['artwork_url'],
        durationSeconds: t['duration_seconds'],
      );
      
      _audioPlayer?.setInitialTrack(track, lastAt);
    }
  }

  Future<void> _hydrateLastTrack() async {
    try {
      final state = await _repo.fetchMe();
      if (state != null && state['last_track'] != null) {
        final lastAtStr = state['user']['last_played_at'];
        final lastAt = lastAtStr != null ? DateTime.tryParse(lastAtStr) : null;
        
        final t = state['last_track'];
        final track = Track(
          id: t['id'].toString(),
          title: t['title'] ?? '',
          artist: t['artist'] ?? '',
          streamUrl: t['stream_url'] ?? '',
          artworkUrl: t['artwork_url'],
          durationSeconds: t['duration_seconds'],
        );
        
        _audioPlayer?.setInitialTrack(track, lastAt);
      }
    } catch (e) {
      debugPrint('Error hydrating last track from server: $e');
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await _repo.register(
      email: email,
      password: password,
      displayName: displayName,
    );
    _user = await _repo.currentUser(forceRefresh: true);
    await _hydrateLastTrack();
    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    await _repo.login(email: email, password: password);
    _user = await _repo.currentUser(forceRefresh: true);
    await _hydrateLastTrack();
    notifyListeners();
  }

  Future<void> logout() async {
    await _repo.logout();
    _user = null;
    _library?.clear();
    await _audioPlayer?.stop();
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    _user = await _repo.currentUser(forceRefresh: true);
    notifyListeners();
  }

  Future<void> updateProfile({
    required String displayName,
    String? avatarUrl,
    bool clearAvatar = false,
  }) async {
    await _repo.updateProfile(
      displayName: displayName,
      avatarUrl: avatarUrl,
      clearAvatar: clearAvatar,
    );
    _user = await _repo.currentUser(forceRefresh: true);
    notifyListeners();
  }
}

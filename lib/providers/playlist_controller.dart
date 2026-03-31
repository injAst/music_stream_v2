import 'package:flutter/material.dart';
import '../data/models/playlist.dart';
import '../data/repositories/playlist_repository.dart';
import 'auth_controller.dart';

class PlaylistController extends ChangeNotifier {
  final AuthController auth;
  late PlaylistRepository _repository;

  PlaylistController({required this.auth}) {
    _initRepository();
  }

  void _initRepository() {
    _repository = PlaylistRepository(token: auth.token ?? '');
  }

  List<Playlist> _playlists = [];
  List<Playlist> get playlists => _playlists;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> fetchPlaylists() async {
    if (auth.token == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      _playlists = await _repository.getPlaylists();
    } catch (e) {
      debugPrint('Error fetching playlists: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Playlist?> createPlaylist(String name, {String? description}) async {
    try {
      final p = await _repository.createPlaylist(name, description: description);
      _playlists.insert(0, p);
      notifyListeners();
      return p;
    } catch (e) {
      debugPrint('Error creating playlist: $e');
      return null;
    }
  }

  Future<void> deletePlaylist(String id) async {
    try {
      await _repository.deletePlaylist(id);
      _playlists.removeWhere((p) => p.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting playlist: $e');
    }
  }

  Future<Playlist?> updatePlaylist(
    String id, {
    String? name,
    String? description,
    bool? isPublic,
  }) async {
    try {
      final p = await _repository.updatePlaylist(id, name: name, description: description, isPublic: isPublic);
      final idx = _playlists.indexWhere((pl) => pl.id == id);
      if (idx != -1) {
        _playlists[idx] = p;
        notifyListeners();
      }
      return p;
    } catch (e) {
      debugPrint('Error updating playlist: $e');
      return null;
    }
  }

  Future<void> addTrackToPlaylist(String playlistId, String trackId) async {
    try {
      await _repository.addTrackToPlaylist(playlistId, trackId);
      // При желании можно обновить trackCount локально
      final idx = _playlists.indexWhere((p) => p.id == playlistId);
      if (idx != -1) {
        final p = _playlists[idx];
        _playlists[idx] = Playlist(
          id: p.id,
          name: p.name,
          description: p.description,
          artworkUrl: p.artworkUrl,
          isPublic: p.isPublic,
          trackCount: p.trackCount + 1,
          createdAt: p.createdAt,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error adding track to playlist: $e');
    }
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    try {
      await _repository.removeTrackFromPlaylist(playlistId, trackId);
      final idx = _playlists.indexWhere((p) => p.id == playlistId);
      if (idx != -1) {
        final p = _playlists[idx];
        _playlists[idx] = Playlist(
          id: p.id,
          name: p.name,
          description: p.description,
          artworkUrl: p.artworkUrl,
          isPublic: p.isPublic,
          trackCount: (p.trackCount - 1).clamp(0, 999999),
          createdAt: p.createdAt,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error removing track from playlist: $e');
    }
  }

  Future<Map<String, dynamic>> getPlaylistDetails(String id) async {
    return await _repository.getPlaylistDetails(id);
  }
}

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/models/track.dart';
import '../data/repositories/track_repository.dart';

class LibraryController extends ChangeNotifier {
  LibraryController(this._repo);

  final TrackRepository _repo;

  List<Track> _tracks = [];
  bool _loading = true;

  List<Track> get tracks => List.unmodifiable(_tracks);
  bool get isLoading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      _tracks = await _repo.loadTracks();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addTrack({
    required String title,
    required String artist,
    String? streamUrl,
    File? audioFile,
    List<int>? audioBytes,
    String? audioFileName,
    String? artworkUrl,
    int? durationSeconds,
  }) async {
    String finalStreamUrl = streamUrl ?? '';
    
    if (audioFile != null || audioBytes != null) {
      finalStreamUrl = await _repo.uploadAudioFile(
        file: audioFile,
        bytes: audioBytes,
        filename: audioFileName ?? 'upload.mp3',
      );
    }
    
    if (finalStreamUrl.isEmpty) {
      throw Exception('Необходимо указать ссылку или выбрать файл');
    }

    await _repo.addTrack(
      title: title,
      artist: artist,
      streamUrl: finalStreamUrl,
      artworkUrl: artworkUrl,
      durationSeconds: durationSeconds,
    );
    await load();
  }

  Future<void> removeTrack(String id) async {
    await _repo.removeTrack(id);
    await load();
  }

  Future<void> toggleLike(String id) async {
    final idx = _tracks.indexWhere((t) => t.id == id);
    if (idx == -1) return;

    final track = _tracks[idx];
    final isLiking = !track.isLiked;

    // Оптимистичное обновление
    _tracks[idx] = track.copyWith(
      isLiked: isLiking,
      likesCount: track.likesCount + (isLiking ? 1 : -1),
    );
    notifyListeners();

    try {
      if (isLiking) {
        await _repo.likeTrack(id);
      } else {
        await _repo.unlikeTrack(id);
      }
    } catch (e) {
      // Откат при ошибке
      _tracks[idx] = track;
      notifyListeners();
    }
  }

  void updateTrackDuration(String id, int seconds) {
    if (seconds <= 0) return;
    final idx = _tracks.indexWhere((t) => t.id == id);
    if (idx != -1) {
      if (_tracks[idx].durationSeconds == 0 || _tracks[idx].durationSeconds == null) {
        _tracks[idx] = _tracks[idx].copyWith(durationSeconds: seconds);
        notifyListeners();
      }
    }
  }

  void clear() {
    _tracks = [];
    _loading = false;
    notifyListeners();
  }
}

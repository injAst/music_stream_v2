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
    required String streamUrl,
    String? artworkUrl,
  }) async {
    await _repo.addTrack(
      title: title,
      artist: artist,
      streamUrl: streamUrl,
      artworkUrl: artworkUrl,
    );
    await load();
  }

  Future<void> removeTrack(String id) async {
    await _repo.removeTrack(id);
    await load();
  }
}

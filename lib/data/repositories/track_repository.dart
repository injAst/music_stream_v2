import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/track.dart';

class TrackRepository {
  TrackRepository(this._prefs);

  final SharedPreferences _prefs;
  final _uuid = const Uuid();

  static const _tracksKey = 'ms_tracks_v1';
  static const _seededKey = 'ms_tracks_seeded';

  List<Track> get _defaultCatalog => const [
        Track(
          id: 'seed-1',
          title: 'SoundHelix Song 1',
          artist: 'SoundHelix',
          streamUrl:
              'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
          artworkUrl:
              'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400',
          durationSeconds: 372,
        ),
        Track(
          id: 'seed-2',
          title: 'SoundHelix Song 2',
          artist: 'SoundHelix',
          streamUrl:
              'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
          artworkUrl:
              'https://images.unsplash.com/photo-1511379938547-c1f69419868d?w=400',
          durationSeconds: 393,
        ),
        Track(
          id: 'seed-3',
          title: 'SoundHelix Song 3',
          artist: 'SoundHelix',
          streamUrl:
              'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
          artworkUrl:
              'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=400',
          durationSeconds: 418,
        ),
      ];

  Future<List<Track>> loadTracks() async {
    final seeded = _prefs.getBool(_seededKey) ?? false;
    final raw = _prefs.getString(_tracksKey);
    if (!seeded && (raw == null || raw.isEmpty)) {
      await _persist(_defaultCatalog);
      await _prefs.setBool(_seededKey, true);
      return List.from(_defaultCatalog);
    }
    if (raw == null || raw.isEmpty) return List.from(_defaultCatalog);
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Track.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> _persist(List<Track> tracks) async {
    await _prefs.setString(
      _tracksKey,
      jsonEncode(tracks.map((t) => t.toJson()).toList()),
    );
  }

  Future<void> addTrack({
    required String title,
    required String artist,
    required String streamUrl,
    String? artworkUrl,
  }) async {
    final tracks = await loadTracks();
    tracks.add(
      Track(
        id: _uuid.v4(),
        title: title.trim(),
        artist: artist.trim(),
        streamUrl: streamUrl.trim(),
        artworkUrl: _cleanOptional(artworkUrl),
      ),
    );
    await _persist(tracks);
  }

  String? _cleanOptional(String? value) {
    final t = value?.trim();
    if (t == null || t.isEmpty) return null;
    return t;
  }

  Future<void> removeTrack(String id) async {
    final tracks = await loadTracks();
    tracks.removeWhere((t) => t.id == id);
    await _persist(tracks);
  }
}

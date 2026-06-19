import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../core/config/api_config.dart';
import '../models/playlist.dart';
import '../models/track.dart';

class PlaylistRepository {
  final String token;

  PlaylistRepository({required this.token});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Future<List<Playlist>> getPlaylists() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/playlists'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List list = data['playlists'] ?? [];
      return list.map((json) => Playlist.fromJson(json)).toList();
    }
    throw Exception('Failed to load playlists: ${response.body}');
  }

  Future<Playlist> createPlaylist(
    String name, {
    String? description,
    bool isPublic = false,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/playlists'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'description': description,
        'is_public': isPublic,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return Playlist.fromJson(data['playlist']);
    }
    throw Exception('Failed to create playlist: ${response.body}');
  }

  Future<Map<String, dynamic>> getPlaylistDetails(String id) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/playlists/$id'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final playlist = Playlist.fromJson(data['playlist']);
      final List tracksJson = data['tracks'] ?? [];
      final tracks = tracksJson.map((json) => Track.fromJson(json)).toList();
      return {'playlist': playlist, 'tracks': tracks};
    }
    throw Exception('Failed to load playlist details: ${response.body}');
  }

  Future<void> deletePlaylist(String id) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/playlists/$id'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete playlist: ${response.body}');
    }
  }

  Future<Playlist> updatePlaylist(
    String id, {
    String? name,
    String? description,
    bool? isPublic,
    String? artworkUrl,
  }) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/playlists/$id'),
      headers: _headers,
      body: jsonEncode({
        'name': ?name,
        'description': ?description,
        'is_public': ?isPublic,
        'artwork_url': ?artworkUrl,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Playlist.fromJson(data['playlist']);
    }
    throw Exception('Failed to update playlist: ${response.body}');
  }

  Future<String> uploadArtwork(Uint8List bytes, String filename) async {
    // Шаг 1: Получаем presigned URL от сервера
    final presignRes = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/upload/presign'
        '?filename=${Uri.encodeComponent(filename)}&type=artwork',
      ),
      headers: _headers,
    );
    if (presignRes.statusCode != 200) {
      throw Exception('Failed to get presigned URL: ${presignRes.body}');
    }
    final presignData = jsonDecode(presignRes.body) as Map<String, dynamic>;
    final presignedUrl = presignData['presigned_url'] as String;
    final publicUrl    = presignData['public_url']    as String;
    final contentType  = presignData['content_type']  as String? ?? 'image/jpeg';

    // Шаг 2: Загружаем напрямую в S3 (Content-Type совпадает с подписанным)
    final s3Response = await http.put(
      Uri.parse(presignedUrl),
      headers: {'Content-Type': contentType},
      body: bytes,
    );

    if (s3Response.statusCode != 200) {
      throw Exception('Failed to upload artwork to S3: ${s3Response.statusCode}');
    }
    return publicUrl;
  }



  Future<void> addTrackToPlaylist(String playlistId, String trackId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/playlists/$playlistId/tracks'),
      headers: _headers,
      body: jsonEncode({'track_id': trackId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to add track to playlist: ${response.body}');
    }
  }

  Future<void> removeTrackFromPlaylist(
    String playlistId,
    String trackId,
  ) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/playlists/$playlistId/tracks/$trackId'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to remove track from playlist: ${response.body}');
    }
  }
}

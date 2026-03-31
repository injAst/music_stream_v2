import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
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

  Future<Playlist> createPlaylist(String name, {String? description, bool isPublic = false}) async {
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
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (isPublic != null) 'is_public': isPublic,
        if (artworkUrl != null) 'artwork_url': artworkUrl,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Playlist.fromJson(data['playlist']);
    }
    throw Exception('Failed to update playlist: ${response.body}');
  }

  Future<String> uploadArtwork(Uint8List bytes, String filename) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/upload/artwork');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_headers)
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: MediaType('image', 'jpeg'), // Обобщенно
      ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['url'] as String;
    }
    throw Exception('Failed to upload artwork: ${response.body}');
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

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/playlists/$playlistId/tracks/$trackId'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to remove track from playlist: ${response.body}');
    }
  }
}

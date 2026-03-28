import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/api_config.dart';
import '../models/track.dart';

class TrackRepository {
  TrackRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _tokenKey = 'ms_auth_token_v1';

  Map<String, String> _headers() {
    final h = {'Content-Type': 'application/json'};
    final t = _prefs.getString(_tokenKey);
    if (t != null) h['Authorization'] = 'Bearer $t';
    return h;
  }

  void _handleError(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    try {
      final body = jsonDecode(res.body);
      if (body['error'] != null) throw Exception(body['error'].toString());
    } catch (_) {}
    throw Exception('Ошибка сервера: ${res.statusCode}');
  }

  Future<List<Track>> loadTracks() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/tracks'),
      headers: _headers(),
    );
    _handleError(res);
    final body = jsonDecode(res.body);
    final list = body['tracks'] as List;
    return list.map((e) => Track.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> addTrack({
    required String title,
    required String artist,
    required String streamUrl,
    String? artworkUrl,
  }) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/tracks'),
      headers: _headers(),
      body: jsonEncode({
        'title': title,
        'artist': artist,
        'stream_url': streamUrl,
        'artwork_url': artworkUrl,
      }),
    );
    _handleError(res);
  }

  Future<void> removeTrack(String id) async {
    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/tracks/$id'),
      headers: _headers(),
    );
    _handleError(res);
  }
}

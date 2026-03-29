import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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

  Future<Track> addTrack({
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
    final data = jsonDecode(res.body);
    return Track.fromJson(data['track']);
  }

  Future<String> uploadAudioFile({
    File? file,
    List<int>? bytes,
    required String filename,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/upload'))
      ..headers.addAll(_headers());
      
    if (kIsWeb && bytes != null) {
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    } else if (!kIsWeb && file != null) {
      request.files.add(await http.MultipartFile.fromPath('file', file.path, filename: filename));
    } else if (bytes != null) {
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    } else {
      throw Exception('Необходим либо файл, либо набор байтов для загрузки');
    }

    final streamedResponse = await request.send();
    final res = await http.Response.fromStream(streamedResponse);
    _handleError(res);

    final data = jsonDecode(res.body);
    return data['url'] as String;
  }

  Future<void> removeTrack(String id) async {
    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/tracks/$id'),
      headers: _headers(),
    );
    _handleError(res);
  }

  Future<void> likeTrack(String id) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/tracks/$id/like'),
      headers: _headers(),
    );
    _handleError(res);
  }

  Future<void> unlikeTrack(String id) async {
    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/tracks/$id/like'),
      headers: _headers(),
    );
    _handleError(res);
  }

  Future<List<Track>> searchTracks(String query) async {
    if (query.trim().isEmpty) return [];
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/tracks/search?q=${Uri.encodeQueryComponent(query.trim())}'),
      headers: _headers(),
    );
    _handleError(res);
    final data = jsonDecode(res.body);
    final list = data['tracks'] as List;
    return list.map((e) => Track.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }
}

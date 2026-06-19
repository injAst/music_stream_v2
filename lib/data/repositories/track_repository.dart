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
    int? durationSeconds,
  }) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/tracks'),
      headers: _headers(),
      body: jsonEncode({
        'title': title,
        'artist': artist,
        'stream_url': streamUrl,
        'artwork_url': artworkUrl,
        'duration_seconds': durationSeconds ?? 0,
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
  }) {
    return _uploadFile(
      file: file,
      bytes: bytes,
      filename: filename,
      endpoint: '/upload',
    );
  }

  Future<String> uploadArtwork({
    File? file,
    List<int>? bytes,
    required String filename,
  }) {
    return _uploadFile(
      file: file,
      bytes: bytes,
      filename: filename,
      endpoint: '/upload/artwork',
    );
  }

  Future<String> _uploadFile({
    File? file,
    List<int>? bytes,
    required String filename,
    required String endpoint,
  }) async {
    // Шаг 1: Получаем presigned URL от сервера
    final type = endpoint.contains('artwork') ? 'artwork' : 'audio';
    final presignRes = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/upload/presign'
        '?filename=${Uri.encodeComponent(filename)}&type=$type',
      ),
      headers: _headers(),
    );
    _handleError(presignRes);
    final presignData = jsonDecode(presignRes.body) as Map<String, dynamic>;
    final presignedUrl  = presignData['presigned_url'] as String;
    final publicUrl     = presignData['public_url']    as String;
    // Используем content-type от сервера — он должен совпадать с подписанным!
    final contentType   = presignData['content_type']  as String? ?? 'application/octet-stream';

    // Шаг 2: Читаем байты файла
    final List<int> fileBytes;
    if (bytes != null) {
      fileBytes = bytes;
    } else if (file != null) {
      fileBytes = await file.readAsBytes();
    } else {
      throw Exception('Необходим либо файл, либо набор байтов для загрузки');
    }

    // Шаг 3: Загружаем напрямую в S3 через presigned URL (минуя Gateway)
    // ВАЖНО: Content-Type подписан в URL. Не добавляем x-amz-content-sha256 — вызывает 403.
    final s3Response = await http.put(
      Uri.parse(presignedUrl),
      headers: {'Content-Type': contentType},
      body: fileBytes,
    );

    if (s3Response.statusCode != 200) {
      throw Exception('Ошибка загрузки в S3: ${s3Response.statusCode} ${s3Response.body}');
    }

    return publicUrl;
  }


  Future<void> removeTrack(String id) async {
    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/tracks/$id'),
      headers: _headers(),
    );
    _handleError(res);
  }

  Future<void> updateTrack({
    required String id,
    String? title,
    String? artist,
    String? artworkUrl,
    int? durationSeconds,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (artist != null) body['artist'] = artist;
    if (artworkUrl != null) body['artwork_url'] = artworkUrl;
    if (durationSeconds != null) body['duration_seconds'] = durationSeconds;

    if (body.isEmpty) return;

    final res = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/tracks/$id'),
      headers: _headers(),
      body: jsonEncode(body),
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

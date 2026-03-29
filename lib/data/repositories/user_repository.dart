import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/api_config.dart';
import '../models/track.dart';
import '../models/user_profile.dart';

class UserRepository {
  UserRepository(this._prefs);

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

  /// Загрузить профиль + публичные треки пользователя
  Future<Map<String, dynamic>> getUserProfileAndTracks(String userId) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/users/$userId'),
      headers: _headers(),
    );
    _handleError(res);

    final data = jsonDecode(res.body);
    final user = UserProfile.fromJson(data['user'] as Map<String, dynamic>);
    final tracksList = data['tracks'] as List;
    final tracks = tracksList.map((e) => Track.fromJson(Map<String, dynamic>.from(e as Map))).toList();

    return {'user': user, 'tracks': tracks};
  }

  /// Треки, которые пользователь лайкнул (публичные)
  Future<List<Track>> getUserLikedTracks(String userId) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/users/$userId/liked'),
      headers: _headers(),
    );
    _handleError(res);
    final data = jsonDecode(res.body);
    final list = data['tracks'] as List;
    return list.map((e) => Track.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Поиск пользователей по нику
  Future<List<UserProfile>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/users/search?q=${Uri.encodeQueryComponent(query.trim())}'),
      headers: _headers(),
    );
    _handleError(res);
    final data = jsonDecode(res.body);
    final list = data['users'] as List;
    return list
        .map((e) => UserProfile.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

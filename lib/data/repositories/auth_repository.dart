import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/api_config.dart';
import '../models/user_profile.dart';

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
}

class AuthRepository {
  AuthRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _tokenKey = 'ms_auth_token_v1';
  static const _userKey = 'ms_user_profile_v1';

  String? get currentToken => _prefs.getString(_tokenKey);

  Map<String, String> _headers([String? token]) {
    final h = {'Content-Type': 'application/json'};
    final t = token ?? currentToken;
    if (t != null) h['Authorization'] = 'Bearer $t';
    return h;
  }

  void _saveLocalUser(UserProfile user) {
    _prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  UserProfile? _loadLocalUser() {
    final jsonStr = _prefs.getString(_userKey);
    if (jsonStr == null) return null;
    try {
      return UserProfile.fromJson(jsonDecode(jsonStr));
    } catch (e) {
      return null;
    }
  }

  void _clearLocalUser() {
    _prefs.remove(_userKey);
  }

  void _handleError(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    try {
      final body = jsonDecode(res.body);
      if (body['error'] != null) throw AuthException(body['error'].toString());
    } catch (e) {
      if (e is AuthException) rethrow;
    }
    throw AuthException('Ошибка сервера: ${res.statusCode}');
  }

  Future<UserProfile?> currentUser({bool forceRefresh = false}) async {
    final token = currentToken;
    
    if (!forceRefresh) {
      final cached = _loadLocalUser();
      if (cached != null) return cached;
    }

    if (token == null) return null;

    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/me'),
        headers: _headers(token),
      );
      if (res.statusCode == 401) {
        await logout(); 
        return null;
      }
      _handleError(res);
      final body = jsonDecode(res.body);
      final u = body['user'];
      final lt = body['last_track'];
      
      final user = UserProfile(
        id: u['id']?.toString() ?? '',
        email: u['email'] ?? '',
        displayName: u['display_name'] ?? '',
        avatarUrl: u['avatar_url'],
        lastTrack: lt as Map<String, dynamic>?,
        lastPlayedAt: u['last_played_at']?.toString(),
      );
      _saveLocalUser(user);
      return user;
    } catch (e) {
      return null;
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/register'),
      headers: _headers(),
      body: jsonEncode({
        'email': email,
        'password': password,
        'display_name': displayName,
      }),
    );
    _handleError(res);
    final body = jsonDecode(res.body);
    await _prefs.setString(_tokenKey, body['token'] as String);
  }

  Future<void> login({required String email, required String password}) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    _handleError(res);
    final body = jsonDecode(res.body);
    await _prefs.setString(_tokenKey, body['token'] as String);
  }

  Future<void> logout() async {
    await _prefs.remove(_tokenKey);
    _clearLocalUser();
  }

  Future<void> updateProfile({
    required String displayName,
    String? avatarUrl,
    bool clearAvatar = false,
  }) async {
    if (currentToken == null) throw AuthException('Нет сессии');
    final res = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/me'),
      headers: _headers(),
      body: jsonEncode({
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'clear_avatar': clearAvatar,
      }),
    );
    _handleError(res);
  }

  Future<Map<String, dynamic>?> fetchMe() async {
    final token = currentToken;
    if (token == null) return null;
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/me'),
        headers: _headers(token),
      );
      if (res.statusCode == 401) {
        await logout();
        return null;
      }
      _handleError(res);
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  Future<void> updateLastTrack(String trackId) async {
    final token = currentToken;
    if (token == null) return;
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/me/state'),
        headers: _headers(token),
        body: jsonEncode({'track_id': trackId}),
      );
      _handleError(res);
    } catch (e) {
      print('DEBUG: updateLastTrack error: $e');
    }
  }
}

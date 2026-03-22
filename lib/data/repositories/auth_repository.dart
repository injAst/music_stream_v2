import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
}

class AuthRepository {
  AuthRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _usersKey = 'ms_users_v1';
  static const _sessionEmailKey = 'ms_session_email';

  String _hash(String password, String email) {
    final bytes = utf8.encode('$email::$password::pulse_music');
    return sha256.convert(bytes).toString();
  }

  Map<String, Map<String, dynamic>> _readUsers() {
    final raw = _prefs.getString(_usersKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
    );
  }

  Future<void> _writeUsers(Map<String, Map<String, dynamic>> users) async {
    await _prefs.setString(_usersKey, jsonEncode(users));
  }

  Future<UserProfile?> currentUser() async {
    final email = _prefs.getString(_sessionEmailKey);
    if (email == null) return null;
    final users = _readUsers();
    final row = users[email];
    if (row == null) {
      await _prefs.remove(_sessionEmailKey);
      return null;
    }
    return UserProfile(
      email: email,
      displayName: row['displayName'] as String,
      avatarUrl: row['avatarUrl'] as String?,
    );
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) throw AuthException('Введите email');
    if (password.length < 6) {
      throw AuthException('Пароль не короче 6 символов');
    }
    if (displayName.trim().isEmpty) {
      throw AuthException('Введите имя');
    }
    final users = _readUsers();
    if (users.containsKey(normalized)) {
      throw AuthException('Этот email уже зарегистрирован');
    }
    users[normalized] = {
      'passwordHash': _hash(password, normalized),
      'displayName': displayName.trim(),
      'avatarUrl': null,
    };
    await _writeUsers(users);
    await _prefs.setString(_sessionEmailKey, normalized);
  }

  Future<void> login({required String email, required String password}) async {
    final normalized = email.trim().toLowerCase();
    final users = _readUsers();
    final row = users[normalized];
    if (row == null) throw AuthException('Неверный email или пароль');
    final hash = _hash(password, normalized);
    if (row['passwordHash'] != hash) {
      throw AuthException('Неверный email или пароль');
    }
    await _prefs.setString(_sessionEmailKey, normalized);
  }

  Future<void> logout() async {
    await _prefs.remove(_sessionEmailKey);
  }

  Future<void> updateProfile({
    required String displayName,
    String? avatarUrl,
    bool clearAvatar = false,
  }) async {
    final email = _prefs.getString(_sessionEmailKey);
    if (email == null) throw AuthException('Нет сессии');
    final users = _readUsers();
    final row = users[email];
    if (row == null) throw AuthException('Пользователь не найден');
    row['displayName'] = displayName.trim();
    if (clearAvatar) {
      row['avatarUrl'] = null;
    } else if (avatarUrl != null) {
      row['avatarUrl'] = avatarUrl;
    }
    await _writeUsers(users);
  }
}

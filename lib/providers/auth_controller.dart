import 'package:flutter/foundation.dart';

import '../data/models/user_profile.dart';
import '../data/repositories/auth_repository.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._repo);

  final AuthRepository _repo;

  UserProfile? _user;

  UserProfile? get user => _user;
  bool get isLoggedIn => _user != null;

  Future<void> init() async {
    // Мгновенная загрузка из кэша
    _user = await _repo.currentUser();
    notifyListeners();

    // Фоновое обновление с сервера для проверки актуальности сессии
    if (isLoggedIn) {
      _user = await _repo.currentUser(forceRefresh: true);
      notifyListeners();
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await _repo.register(
      email: email,
      password: password,
      displayName: displayName,
    );
    await _repo.register(
      email: email,
      password: password,
      displayName: displayName,
    );
    _user = await _repo.currentUser(forceRefresh: true);
    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    await _repo.login(email: email, password: password);
    _user = await _repo.currentUser(forceRefresh: true);
    notifyListeners();
  }

  Future<void> logout() async {
    await _repo.logout();
    _user = null;
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    _user = await _repo.currentUser(forceRefresh: true);
    notifyListeners();
  }

  Future<void> updateProfile({
    required String displayName,
    String? avatarUrl,
    bool clearAvatar = false,
  }) async {
    await _repo.updateProfile(
      displayName: displayName,
      avatarUrl: avatarUrl,
      clearAvatar: clearAvatar,
    );
    _user = await _repo.currentUser(forceRefresh: true);
    notifyListeners();
  }
}

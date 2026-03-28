import 'dart:io';

class ApiConfig {
  static String get baseUrl {
    // В Android Emulator localhost не работает, нужно использовать 10.0.2.2
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8081/v1';
    } catch (_) {}
    return 'http://127.0.0.1:8081/v1';
  }
}

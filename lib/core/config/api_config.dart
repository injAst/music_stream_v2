import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  /// Задаётся при сборке командой:
  /// flutter build web --dart-define=API_URL=https://your-api.fly.dev/v1
  static const _prodApiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://d5dd2ipjnesrn8mjreq9.tmjd4m4j.apigw.yandexcloud.net/v1',
  );

  static String get baseUrl {
    if (_prodApiUrl.isNotEmpty) return _prodApiUrl;
    try {
      if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8081/v1';
    } catch (_) {}
    return 'http://127.0.0.1:8081/v1';
  }

  static String? resolveUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    
    // Если это локальный путь (начинается с /uploads или т.п.)
    if (!url.startsWith('http')) {
      final host = baseUrl.replaceAll('/v1', '');
      return '$host$url';
    }

    // Обработка Android эмулятора
    try {
      if (!kIsWeb && Platform.isAndroid && (url.contains('localhost') || url.contains('127.0.0.1'))) {
        return url.replaceAll('localhost', '10.0.2.2').replaceAll('127.0.0.1', '10.0.2.2');
      }
    } catch (_) {}

    // На Web для внешних ссылок используем прокси, чтобы обойти CORS
    if (kIsWeb) {
      final baseUri = Uri.parse(baseUrl);
      final targetUri = Uri.parse(url);
      
      // Если домен отличается от нашего API — проксируем
      if (targetUri.host != baseUri.host) {
        return '$baseUrl/proxy/image?url=${Uri.encodeComponent(url)}';
      }
    }

    return url;
  }
}

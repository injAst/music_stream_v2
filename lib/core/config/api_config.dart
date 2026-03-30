import 'dart:io';

class ApiConfig {
  static String get baseUrl {
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8081/v1';
    } catch (_) {}
    return 'http://127.0.0.1:8081/v1';
  }

  static String? resolveUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (!url.startsWith('http')) {
      // Относительный путь от корня сервера (предположим, что база без /v1)
      final host = baseUrl.replaceAll('/v1', '');
      return '$host$url';
    }
    // Если на Android и адрес localhost/127.0.0.1 — меняем на 10.0.2.2
    try {
      if (Platform.isAndroid && (url.contains('localhost') || url.contains('127.0.0.1'))) {
        return url.replaceAll('localhost', '10.0.2.2').replaceAll('127.0.0.1', '10.0.2.2');
      }
    } catch (_) {}
    return url;
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Универсальный S3-совместимый клиент для объектного хранилища.
/// Работает с Yandex Cloud, VK Cloud, Selectel, Cloudflare R2, AWS S3 и др.
/// Реализует AWS Signature V4 без дополнительных зависимостей.
class R2Client {
  R2Client({
    required this.accessKeyId,
    required this.secretAccessKey,
    required this.bucket,
    required this.publicUrl,

    /// Хост S3-совместимого хранилища, например:
    /// - Yandex Cloud:  'storage.yandexcloud.net'
    /// - Cloudflare R2: '{account_id}.r2.cloudflarestorage.com'
    /// - VK Cloud:      'hb.ru-msk.vkcloud-storage.ru'
    /// - Selectel:      's3.ru-1.storage.selcloud.ru'
    required this.endpoint,

    /// Регион хранилища:
    /// - Yandex Cloud:  'ru-central1'
    /// - Cloudflare R2: 'auto'
    /// - VK Cloud:      'ru-msk'
    this.region = 'auto',
  });

  final String accessKeyId;
  final String secretAccessKey;
  final String bucket;

  /// Публичный домен для генерации ссылок на файлы.
  /// Примеры:
  /// - Yandex Cloud:  'storage.yandexcloud.net/pulse-music'
  /// - Cloudflare R2: 'pub-XXXXXXXX.r2.dev'
  final String publicUrl;

  final String endpoint;
  final String region;

  String get _host => endpoint;

  /// Генерирует presigned PUT URL для прямой загрузки файла в хранилище из браузера.
  /// Клиент делает PUT-запрос с файлом напрямую в S3, минуя API Gateway.
  String generatePresignedPutUrl(
    String key, {
    int expiresInSeconds = 3600,
    String contentType = 'application/octet-stream',
  }) {
    const service = 's3';
    final now = DateTime.now().toUtc();
    final dateStr = _yyyymmdd(now);
    final datetimeStr =
        '${dateStr}T${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}Z';

    final credentialScope = '$dateStr/$region/$service/aws4_request';
    final credential = '$accessKeyId/$credentialScope';
    final encodedKey = key.split('/').map(Uri.encodeComponent).join('/');

    // Подписываем content-type и host (алфавитный порядок!)
    const signedHeaderNames = 'content-type;host';

    // Query-параметры для presigned URL (сортировка по алфавиту обязательна)
    final queryParams = <String, String>{
      'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
      'X-Amz-Credential': credential,
      'X-Amz-Date': datetimeStr,
      'X-Amz-Expires': expiresInSeconds.toString(),
      'X-Amz-SignedHeaders': signedHeaderNames,
    };

    final sortedQuery = (queryParams.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)))
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    // Canonical headers (алфавитный порядок: content-type < host)
    final canonicalHeaders = 'content-type:$contentType\nhost:$_host\n';

    final canonicalRequest = [
      'PUT',
      '/$bucket/$encodedKey',
      sortedQuery,
      canonicalHeaders,
      signedHeaderNames,
      'UNSIGNED-PAYLOAD',
    ].join('\n');

    final credScope = '$dateStr/$region/$service/aws4_request';
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      datetimeStr,
      credScope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');

    List<int> hmac(List<int> k, String msg) =>
        Hmac(sha256, k).convert(utf8.encode(msg)).bytes;

    final signingKey = hmac(
      hmac(
        hmac(hmac(utf8.encode('AWS4$secretAccessKey'), dateStr), region),
        service,
      ),
      'aws4_request',
    );
    final signature =
        Hmac(sha256, signingKey).convert(utf8.encode(stringToSign)).toString();

    final fullQuery = '$sortedQuery&X-Amz-Signature=$signature';
    return 'https://$_host/$bucket/$encodedKey?$fullQuery';
  }

  /// Возвращает публичный URL файла.
  Future<String> putObject(
    String key,
    Uint8List bytes, {
    String contentType = 'application/octet-stream',
  }) async {
    const service = 's3';

    final now = DateTime.now().toUtc();
    final dateStr = _yyyymmdd(now);
    final datetimeStr =
        '${dateStr}T${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}Z';

    final payloadHash = sha256.convert(bytes).toString();

    // Заголовки для подписи (в алфавитном порядке)
    final sigHeaders = <String, String>{
      'content-type': contentType,
      'host': _host,
      'x-amz-content-sha256': payloadHash,
      'x-amz-date': datetimeStr,
    };

    final sortedKeys = sigHeaders.keys.toList()..sort();
    final signedHeaderStr = sortedKeys.join(';');
    final canonicalHeaders =
        sortedKeys.map((k) => '$k:${sigHeaders[k]}').join('\n') + '\n';

    // URI-кодирование каждого сегмента пути (без кодирования слэшей)
    final encodedKey = key.split('/').map(Uri.encodeComponent).join('/');

    final canonicalRequest = [
      'PUT',
      '/$bucket/$encodedKey',
      '', // query string
      canonicalHeaders,
      signedHeaderStr,
      payloadHash,
    ].join('\n');

    final credentialScope = '$dateStr/$region/$service/aws4_request';

    final stringToSign = [
      'AWS4-HMAC-SHA256',
      datetimeStr,
      credentialScope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');

    // Вычисление подписи (AWS Signature V4)
    List<int> hmac(List<int> k, String msg) =>
        Hmac(sha256, k).convert(utf8.encode(msg)).bytes;

    final signingKey = hmac(
      hmac(
        hmac(hmac(utf8.encode('AWS4$secretAccessKey'), dateStr), region),
        service,
      ),
      'aws4_request',
    );

    final signature =
        Hmac(sha256, signingKey).convert(utf8.encode(stringToSign)).toString();

    final authorization = 'AWS4-HMAC-SHA256 '
        'Credential=$accessKeyId/$credentialScope, '
        'SignedHeaders=$signedHeaderStr, '
        'Signature=$signature';

    final uri = Uri.https(_host, '/$bucket/$encodedKey');

    final response = await http.put(
      uri,
      headers: {
        'Content-Type': contentType,
        'x-amz-content-sha256': payloadHash,
        'x-amz-date': datetimeStr,
        'Authorization': authorization,
      },
      body: bytes,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Storage upload error [${response.statusCode}]: ${response.body}',
      );
    }

    // Убираем схему из publicUrl если она уже есть (напр. если S3_PUBLIC_URL содержит https://)
    final baseUrl = publicUrl.startsWith('https://')
        ? publicUrl
        : publicUrl.startsWith('http://')
            ? publicUrl.replaceFirst('http://', 'https://')
            : 'https://$publicUrl';
    return '$baseUrl/$key';

  }

  static String _yyyymmdd(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}'
      '${dt.month.toString().padLeft(2, '0')}'
      '${dt.day.toString().padLeft(2, '0')}';

  static String _pad(int n) => n.toString().padLeft(2, '0');
}

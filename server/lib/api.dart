import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dotenv/dotenv.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_multipart/shelf_multipart.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:http/http.dart' as http;

Future<void> runServer(List<String> args) async {
  final dotEnv = DotEnv(includePlatformEnvironment: true)..load();

  final parser = ArgParser()..addOption('port', defaultsTo: dotEnv['PORT'] ?? '8080');
  final arg = parser.parse(args);
  final port = int.tryParse(arg['port'] as String) ?? 8080;

  final dbUrl = dotEnv['DATABASE_URL'];
  final jwtSecret = dotEnv['JWT_SECRET'];
  if (dbUrl == null || dbUrl.isEmpty) {
    stderr.writeln('DATABASE_URL не задан в server/.env');
    exit(1);
  }
  if (jwtSecret == null || jwtSecret.length < 16) {
    stderr.writeln('JWT_SECRET в server/.env должен быть не короче 16 символов');
    exit(1);
  }

  final u = Uri.parse(dbUrl);
  final endpoint = Endpoint(
    host: u.host,
    port: u.port == 0 ? 5432 : u.port,
    database: u.path.replaceAll('/', ''),
    username: u.userInfo.split(':')[0],
    password: u.userInfo.contains(':') ? u.userInfo.substring(u.userInfo.indexOf(':') + 1) : null,
  );
  
  final sslModeParam = u.queryParameters['sslmode'];
  final sslMode = sslModeParam == 'disable' ? SslMode.disable : SslMode.require;
  
  final pool = Pool<void>.withEndpoints(
    [endpoint],
    settings: PoolSettings(
       maxConnectionCount: 20,
       sslMode: sslMode,
    ),
  );
  final app = _buildApp(conn: pool, jwtSecret: jwtSecret);
  final handler = Pipeline().addMiddleware(corsHeaders()).addHandler(app);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('FlowMusic API → http://${server.address.host}:${server.port}');
}

Handler _buildApp({required Session conn, required String jwtSecret}) {
  final router = Router();

  Response jsonRes(Object? body, {int status = 200}) => Response(
        status,
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );

  String _sanitizeFileName(String fileName) {
    // Убираем всё, кроме латиницы, цифр, точек и подчёркиваний
    final name = fileName.replaceAll(RegExp(r'\s+'), '_');
    return name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '');
  }

  String? bearer(Request req) {
    final h = req.headers['Authorization'];
    if (h == null || !h.startsWith('Bearer ')) return null;
    return h.substring(7).trim();
  }

  String? userIdFromToken(Request req) {
    final t = bearer(req);
    if (t == null || t.isEmpty) return null;
    try {
      final jwt = JWT.verify(t, SecretKey(jwtSecret));
      final p = jwt.payload;
      if (p is Map && p['sub'] != null) return p['sub'].toString();
    } catch (_) {}
    return null;
  }

  String issueToken(String userId, String email) {
    final jwt = JWT({'sub': userId, 'email': email});
    return jwt.sign(SecretKey(jwtSecret), expiresIn: const Duration(days: 30));
  }

  Map<String, dynamic> userJson(ResultRow row) {
    final m = row.toColumnMap();
    return {
      'id': m['id'].toString(),
      'email': m['email'],
      'display_name': m['display_name'],
      'avatar_url': m['avatar_url'],
      'last_played_at': m['last_played_at']?.toString(),
    };
  }

  router.get('/health', (_) => Response.ok('ok'));

  final staticHandler = createStaticHandler('uploads');
  final cachedStaticHandler = const Pipeline()
      .addMiddleware((innerHandler) => (request) async {
            final response = await innerHandler(request);
            if (response.statusCode == 200) {
              return response.change(headers: {
                ...response.headers,
                'Cache-Control': 'public, max-age=31536000',
              });
            }
            return response;
          })
      .addHandler(staticHandler);
  router.mount('/uploads/', cachedStaticHandler);

  router.post('/v1/upload', (Request req) async {
    final uid = userIdFromToken(req);
    if (uid == null) return jsonRes({'error': 'Нужна авторизация'}, status: 401);

    final formReq = req.formData();
    if (formReq == null) {
      return jsonRes({'error': 'Ожидался multipart/form-data'}, status: 400);
    }

    try {
      String? fileUrl;
      await for (final data in formReq.formData) {
        if (data.name == 'file') {
          final filename = data.filename ?? 'upload.mp3';
          final sanitized = _sanitizeFileName(filename);
          // Формат: [краткий UID]_[метка времени]_[имя_файла]
          final prefix = uid.substring(0, 8);
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final newName = '${prefix}_${timestamp}_$sanitized';
          
          final dir = Directory('uploads/audio');
          if (!await dir.exists()) await dir.create(recursive: true);
          
          final file = File('uploads/audio/$newName');
          final sink = file.openWrite();
          await sink.addStream(data.part);
          await sink.close();
          
          final scheme = req.requestedUri.scheme;
          final host = req.requestedUri.host;
          final port = req.requestedUri.port;
          fileUrl = '$scheme://$host:$port/uploads/audio/$newName';
        }
      }

      if (fileUrl != null) {
        return jsonRes({'url': fileUrl});
      } else {
        return jsonRes({'error': 'Файл с полем "file" не найден'}, status: 400);
      }
    } catch (e) {
      return jsonRes({'error': e.toString()}, status: 500);
    }
  });

  // Загрузка обложки (картинки)
  router.post('/v1/upload/artwork', (Request req) async {
    final uid = userIdFromToken(req);
    if (uid == null) return jsonRes({'error': 'Нужна авторизация'}, status: 401);

    final formReq = req.formData();
    if (formReq == null) return jsonRes({'error': 'Ожидался multipart/form-data'}, status: 400);

    try {
      String? fileUrl;
      await for (final data in formReq.formData) {
        if (data.name == 'file') {
          final filename = data.filename ?? 'cover.jpg';
          final sanitized = _sanitizeFileName(filename);
          final prefix = uid.substring(0, 8);
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final newName = '${prefix}_${timestamp}_$sanitized';
          
          final dir = Directory('uploads/artworks');
          if (!await dir.exists()) await dir.create(recursive: true);
          
          final file = File('uploads/artworks/$newName');
          final sink = file.openWrite();
          await sink.addStream(data.part);
          await sink.close();
          
          final scheme = req.requestedUri.scheme;
          final host = req.requestedUri.host;
          final port = req.requestedUri.port;
          fileUrl = '$scheme://$host:$port/uploads/artworks/$newName';
        }
      }

      if (fileUrl != null) {
        return jsonRes({'url': fileUrl});
      } else {
        return jsonRes({'error': 'Файл с полем "file" не найден'}, status: 400);
      }
    } catch (e) {
      return jsonRes({'error': e.toString()}, status: 500);
    }
  });


  router.post('/v1/auth/register', (Request req) async {
    try {
      final map = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final email = (map['email'] as String?)?.trim().toLowerCase() ?? '';
      final password = map['password'] as String? ?? '';
      final displayName = (map['display_name'] as String?)?.trim() ?? '';
      if (email.isEmpty || !email.contains('@')) {
        return jsonRes({'error': 'Некорректный email'}, status: 400);
      }
      if (password.length < 6) {
        return jsonRes({'error': 'Пароль не короче 6 символов'}, status: 400);
      }
      if (displayName.isEmpty) {
        return jsonRes({'error': 'Введите имя'}, status: 400);
      }
      final salt = BCrypt.gensalt();
      final hash = BCrypt.hashpw(password, salt);
      final rs = await conn.execute(
        Sql.named(
          '''
          INSERT INTO app_users (email, password_hash, display_name)
          VALUES (@email, @hash, @name)
          RETURNING id::text AS id, email, display_name, avatar_url
          ''',
        ),
        parameters: {'email': email, 'hash': hash, 'name': displayName},
      );
      final row = rs.first;
      final u = userJson(row);
      final token = issueToken(u['id']! as String, u['email']! as String);
      return jsonRes({'token': token, 'user': u});
    } on UniqueViolationException {
      return jsonRes({'error': 'Этот email уже зарегистрирован'}, status: 409);
    } catch (e) {
      return jsonRes({'error': e.toString()}, status: 500);
    }
  });

  router.post('/v1/auth/login', (Request req) async {
    try {
      final map = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final email = (map['email'] as String?)?.trim().toLowerCase() ?? '';
      final password = map['password'] as String? ?? '';
      if (email.isEmpty || password.isEmpty) {
        return jsonRes({'error': 'Введите email и пароль'}, status: 400);
      }
      final rs = await conn.execute(
        Sql.named(
          '''
          SELECT id::text AS id, email, password_hash, display_name, avatar_url
          FROM app_users WHERE lower(email) = lower(@email)
          ''',
        ),
        parameters: {'email': email},
      );
      if (rs.isEmpty) {
        return jsonRes({'error': 'Неверный email или пароль'}, status: 401);
      }
      final row = rs.first;
      final m = row.toColumnMap();
      final hash = m['password_hash'] as String;
      if (!BCrypt.checkpw(password, hash)) {
        return jsonRes({'error': 'Неверный email или пароль'}, status: 401);
      }
      final u = userJson(row);
      final token = issueToken(u['id']! as String, u['email']! as String);
      return jsonRes({'token': token, 'user': u});
    } catch (e) {
      return jsonRes({'error': e.toString()}, status: 500);
    }
  });

  router.get('/v1/me', (Request req) async {
    final uid = userIdFromToken(req);
    if (uid == null) return jsonRes({'error': 'Не авторизован'}, status: 401);
    try {
      final rs = await conn.execute(
        Sql.named(
          '''
          SELECT 
            u.id::text AS id, u.email, u.display_name, u.avatar_url, u.last_played_at,
            t.id::text AS t_id, t.title AS t_title, t.artist AS t_artist, 
            t.stream_url AS t_stream, t.artwork_url AS t_artwork, t.duration_seconds AS t_dur
          FROM app_users u
          LEFT JOIN tracks t ON u.last_played_track_id = t.id
          WHERE u.id = @id::uuid
          ''',
        ),
        parameters: {'id': uid},
      );
      if (rs.isEmpty) return jsonRes({'error': 'Пользователь не найден'}, status: 404);
      
      final row = rs.first;
      final m = row.toColumnMap();
      final user = userJson(row);
      
      Map<String, dynamic>? lastTrack;
      if (m['t_id'] != null) {
        lastTrack = {
          'id': m['t_id'].toString(),
          'title': m['t_title'],
          'artist': m['t_artist'],
          'stream_url': m['t_stream'],
          'artwork_url': m['t_artwork'],
          'duration_seconds': m['t_dur'],
        };
      }

      return jsonRes({
        'user': user,
        'last_track': lastTrack,
      });
    } catch (e) {
      return jsonRes({'error': e.toString()}, status: 500);
    }
  });

  router.post('/v1/me/state', (Request req) async {
    final uid = userIdFromToken(req);
    if (uid == null) return jsonRes({'error': 'Не авторизован'}, status: 401);
    try {
      final body = jsonDecode(await req.readAsString());
      final trackId = body['track_id'] as String?;
      if (trackId == null) return jsonRes({'error': 'track_id required'}, status: 400);

      await conn.execute(
        Sql.named('UPDATE app_users SET last_played_track_id = @tid::uuid, last_played_at = NOW() WHERE id = @uid::uuid'),
        parameters: {'tid': trackId, 'uid': uid},
      );
      return jsonRes({'ok': true});
    } catch (e) {
      return jsonRes({'error': e.toString()}, status: 500);
    }
  });

  router.patch('/v1/me', (Request req) async {
    final uid = userIdFromToken(req);
    if (uid == null) return jsonRes({'error': 'Не авторизован'}, status: 401);
    try {
      final map = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final displayName = (map['display_name'] as String?)?.trim() ?? '';
      if (displayName.isEmpty) {
        return jsonRes({'error': 'Введите имя'}, status: 400);
      }
      final clearAvatar = map['clear_avatar'] == true;
      final avatarUrl = map['avatar_url'] as String?;

      if (clearAvatar) {
        await conn.execute(
          Sql.named(
            'UPDATE app_users SET display_name = @name, avatar_url = NULL WHERE id = @id::uuid',
          ),
          parameters: {'name': displayName, 'id': uid},
        );
      } else if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
        await conn.execute(
          Sql.named(
            '''
            UPDATE app_users SET display_name = @name, avatar_url = @av
            WHERE id = @id::uuid
            ''',
          ),
          parameters: {'name': displayName, 'av': avatarUrl.trim(), 'id': uid},
        );
      } else {
        await conn.execute(
          Sql.named(
            'UPDATE app_users SET display_name = @name WHERE id = @id::uuid',
          ),
          parameters: {'name': displayName, 'id': uid},
        );
      }

      final rs = await conn.execute(
        Sql.named(
          '''
          SELECT id::text AS id, email, display_name, avatar_url
          FROM app_users WHERE id = @id::uuid
          ''',
        ),
        parameters: {'id': uid},
      );
      return jsonRes({'user': userJson(rs.first)});
    } catch (e) {
      return jsonRes({'error': e.toString()}, status: 500);
    }
  });

  router.get('/v1/tracks', (Request req) async {
    final uid = userIdFromToken(req);
    final uidStr = uid ?? '';
    try {
      final rs = await conn.execute(
        Sql.named(
          '''
          SELECT
            t.id::text AS id,
            t.title,
            t.artist,
            t.stream_url,
            t.artwork_url,
            t.duration_seconds,
            (SELECT COUNT(*) FROM track_likes WHERE track_id = t.id) AS likes_count,
            CASE
              WHEN @uidStr != '' AND EXISTS(SELECT 1 FROM track_likes WHERE track_id = t.id AND user_id::text = @uidStr)
              THEN true ELSE false
            END AS is_liked,
            CASE
              WHEN @uidStr != '' AND t.owner_id IS NOT NULL AND t.owner_id::text = @uidStr
              THEN true ELSE false
            END AS can_delete
          FROM tracks t
          WHERE t.is_public = TRUE
             OR (@uidStr != '' AND t.owner_id IS NOT NULL AND t.owner_id::text = @uidStr)
          ORDER BY t.title
          ''',
        ),
        parameters: {'uidStr': uidStr},
      );
      final list = rs.map((row) {
        final m = row.toColumnMap();
        return {
          'id': m['id'].toString(),
          'title': m['title'],
          'artist': m['artist'],
          'stream_url': m['stream_url'],
          'artwork_url': m['artwork_url'],
          'duration_seconds': m['duration_seconds'],
          'likes_count': int.tryParse(m['likes_count']?.toString() ?? '0') ?? 0,
          'is_liked': m['is_liked'] == true,
          'can_delete': m['can_delete'] == true,
        };
      }).toList();
      return jsonRes({'tracks': list});
    } catch (e) {
      return jsonRes({'error': e.toString()}, status: 500);
    }
  });

  router.post('/v1/tracks', (Request req) async {
    final uid = userIdFromToken(req);
    if (uid == null) return jsonRes({'error': 'Нужна авторизация'}, status: 401);
    try {
      final map = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final title = (map['title'] as String?)?.trim() ?? '';
      final artist = (map['artist'] as String?)?.trim() ?? '';
      final streamUrl = (map['stream_url'] as String?)?.trim() ?? '';
      final artworkUrl = (map['artwork_url'] as String?)?.trim();
      final duration = int.tryParse(map['duration_seconds']?.toString() ?? '0') ?? 0;
      if (title.isEmpty || artist.isEmpty || streamUrl.isEmpty) {
        return jsonRes({'error': 'Заполните название, исполнителя и URL'}, status: 400);
      }
      if (!streamUrl.startsWith('http://') && !streamUrl.startsWith('https://')) {
        return jsonRes({'error': 'URL должен начинаться с http:// или https://'}, status: 400);
      }
      final rs = await conn.execute(
        Sql.named(
          '''
          INSERT INTO tracks (owner_id, is_public, title, artist, stream_url, artwork_url, duration_seconds)
          VALUES (@owner::uuid, TRUE, @title, @artist, @stream_url, @artwork, @duration)
          RETURNING id::text AS id, title, artist, stream_url, artwork_url, duration_seconds
          ''',
        ),
        parameters: {
          'owner': uid,
          'title': title,
          'artist': artist,
          'stream_url': streamUrl,
          'artwork': artworkUrl != null && artworkUrl.isNotEmpty ? artworkUrl : null,
          'duration': duration,
        },
      );
      final m = rs.first.toColumnMap();
      return jsonRes(
        {
          'track': {
            'id': m['id'].toString(),
            'title': m['title'],
            'artist': m['artist'],
            'stream_url': m['stream_url'],
            'artwork_url': m['artwork_url'],
            'duration_seconds': m['duration_seconds'],
            'likes_count': 0,
            'is_liked': false,
            'can_delete': true,
          },
        },
        status: 201,
      );
    } catch (e) {
      return jsonRes({'error': e.toString()}, status: 500);
    }
  });

  router.delete('/v1/tracks/<id>', (Request req, String id) async {
    final uid = userIdFromToken(req);
    if (uid == null) return jsonRes({'error': 'Нужна авторизация'}, status: 401);
    try {
      final rs = await conn.execute(
        Sql.named(
          r'''
          DELETE FROM tracks
          WHERE id = @tid::uuid AND owner_id = @uid::uuid
          RETURNING id
          ''',
        ),
        parameters: {'tid': id, 'uid': uid},
      );
      if (rs.isEmpty) {
        // Идемпотентность: если трек уже удален, возвращаем 200, чтобы не спамить 404 в консоль
        return jsonRes({'ok': true, 'message': 'Трек уже удален или нет прав'});
      }
      return jsonRes({'ok': true});
    } catch (e) {
      return jsonRes({'error': e.toString()}, status: 500);
    }
  });

  router.patch('/v1/tracks/<id>', (Request req, String id) async {
    final uid = userIdFromToken(req);
    if (uid == null) return jsonRes({'error': 'Нужна авторизация'}, status: 401);
    try {
      final body = jsonDecode(await req.readAsString());
      
      // 1. Проверяем существование трека и владельца
      final rs = await conn.execute(
        Sql.named('SELECT owner_id::text FROM tracks WHERE id = @tid::uuid'),
        parameters: {'tid': id},
      );
      if (rs.isEmpty) return jsonRes({'error': 'Трек не найден'}, status: 404);
      final ownerId = rs.first[0]?.toString();
      final isOwner = ownerId != null && ownerId == uid;

      final updates = <String>[];
      final params = <String, dynamic>{'tid': id};

      // Поля, которые может менять только владелец
      if (isOwner) {
        if (body.containsKey('title')) {
          updates.add('title = @title');
          params['title'] = body['title']?.toString().trim() ?? '';
        }
        if (body.containsKey('artist')) {
          updates.add('artist = @artist');
          params['artist'] = body['artist']?.toString().trim() ?? '';
        }
        if (body.containsKey('artwork_url')) {
          updates.add('artwork_url = @artwork');
          params['artwork'] = body['artwork_url']?.toString().trim();
        }
      }

      // Длительность (может обновить любой, если она 0/NULL, либо владелец всегда)
      if (body.containsKey('duration_seconds')) {
        final dur = int.tryParse(body['duration_seconds']?.toString() ?? '0') ?? 0;
        if (isOwner) {
          updates.add('duration_seconds = @dur');
          params['dur'] = dur;
        } else {
          // Пассивное обновление длительности (например, плеером при первом запуске)
          await conn.execute(
            Sql.named('UPDATE tracks SET duration_seconds = @dur WHERE id = @tid::uuid AND (duration_seconds IS NULL OR duration_seconds = 0)'),
            parameters: {'dur': dur, 'tid': id},
          );
        }
      }

      if (isOwner && updates.isNotEmpty) {
        final sql = 'UPDATE tracks SET ${updates.join(', ')} WHERE id = @tid::uuid';
        await conn.execute(Sql.named(sql), parameters: params);
      } else if (!isOwner && body.keys.any((k) => k != 'duration_seconds')) {
         return jsonRes({'error': 'Нет прав на редактирование метаданных этого трека'}, status: 403);
      }

      return jsonRes({'ok': true});
    } catch (e) {
      return jsonRes({'error': e.toString()}, status: 500);
    }
  });

  router.post('/v1/tracks/<id>/like', (Request req, String id) async {
    final uid = userIdFromToken(req);
    if (uid == null) return jsonRes({'error': 'Нужна авторизация'}, status: 401);
    try {
      await conn.execute(
        Sql.named('INSERT INTO track_likes (user_id, track_id) VALUES (@uid::uuid, @tid::uuid) ON CONFLICT DO NOTHING'),
        parameters: {'uid': uid, 'tid': id},
      );
      return jsonRes({'ok': true});
    } catch (e) {
      return jsonRes({'error': e.toString()}, status: 500);
    }
  });

  router.delete('/v1/tracks/<id>/like', (Request req, String id) async {
    final uid = userIdFromToken(req);
    if (uid == null) return jsonRes({'error': 'Нужна авторизация'}, status: 401);
    try {
      await conn.execute(
        Sql.named('DELETE FROM track_likes WHERE user_id = @uid::uuid AND track_id = @tid::uuid'),
        parameters: {'uid': uid, 'tid': id},
      );
      return jsonRes({'ok': true});
    } catch (e) {
      return jsonRes({'error': e.toString()}, status: 500);
    }
  });

  router.get('/v1/tracks/search', (Request req) async {
    final q = req.url.queryParameters['q']?.trim() ?? '';
    final uid = userIdFromToken(req);
    final uidStr = uid ?? '';
    if (q.isEmpty) return jsonRes({'tracks': []});
    try {
      final rs = await conn.execute(
        Sql.named(
          '''
          SELECT
            t.id::text, t.title, t.artist, t.stream_url, t.artwork_url, t.duration_seconds,
            (SELECT COUNT(*) FROM track_likes WHERE track_id = t.id) AS l_count,
            CASE
              WHEN @uidStr != '' AND EXISTS(SELECT 1 FROM track_likes WHERE track_id = t.id AND user_id::text = @uidStr)
              THEN true ELSE false
            END AS is_l
          FROM tracks t
          WHERE (t.title ILIKE @q OR t.artist ILIKE @q) AND t.is_public = TRUE
          ORDER BY t.title
          LIMIT 20
          ''',
        ),
        parameters: {'q': '%$q%', 'uidStr': uidStr},
      );
      
      final list = rs.map((row) {
        return {
          'id': row[0].toString(),
          'title': row[1].toString(),
          'artist': row[2].toString(),
          'stream_url': row[3].toString(),
          'artwork_url': row[4],
          'duration_seconds': row[5],
          'likes_count': int.tryParse(row[6]?.toString() ?? '0') ?? 0,
          'is_liked': row[7] == true,
          'can_delete': false,
        };
      }).toList();
      
      return jsonRes({'tracks': list});
    } catch (e, st) {
      print('TRACK SEARCH ERROR: $e\n$st');
      return jsonRes({'error': e.toString()}, status: 500);
    }
  });

  // Поиск пользователей по нику
  router.get('/v1/users/search', (Request req) async {
    final q = req.url.queryParameters['q']?.trim() ?? '';
    if (q.isEmpty) return jsonRes({'users': []});
    try {
      final rs = await conn.execute(
        Sql.named('SELECT id::text, display_name, avatar_url FROM app_users WHERE display_name ILIKE @q LIMIT 20'),
        parameters: {'q': '%$q%'},
      );
      
      final users = rs.map((row) {
        return {
          'id': row[0].toString(), 
          'display_name': row[1]?.toString() ?? '',
          'avatar_url': row[2]?.toString(),
        };
      }).toList();
      
      return jsonRes({'users': users});
    } catch (e, stack) {
      print('SEARCH ERROR: $e\n$stack');
      return jsonRes({'error': e.toString()}, status: 500);
    }
  });

  // Получить профиль пользователя и его треки
  router.get('/v1/users/<id>', (Request req, String id) async {
    final uid = userIdFromToken(req);
    final uidStr = uid ?? '';
    try {
      // 1. Профиль
      final userRs = await conn.execute(
        Sql.named('SELECT id::text, email, display_name, avatar_url FROM app_users WHERE id = @id::uuid'),
        parameters: {'id': id},
      );
      if (userRs.isEmpty) return jsonRes({'error': 'Пользователь не найден'}, status: 404);
      final uRow = userRs.first;
      final user = {
        'id': uRow[0].toString(),
        'email': uRow[1].toString(),
        'display_name': uRow[2].toString(),
        'avatar_url': uRow[3],
      };

      // 2. Публичные треки пользователя
      final tracksRs = await conn.execute(
        Sql.named(
          '''
          SELECT
            t.id::text,
            t.title,
            t.artist,
            t.stream_url,
            t.artwork_url,
            t.duration_seconds,
            COUNT(l.user_id) AS l_count,
            CASE
              WHEN @uidStr != '' AND MAX(CASE WHEN l.user_id::text = @uidStr THEN 1 ELSE 0 END) = 1
              THEN true ELSE false
            END AS is_l,
            CASE WHEN t.owner_id = @uidStr::uuid THEN true ELSE false END AS c_del
          FROM tracks t
          LEFT JOIN track_likes l ON t.id = l.track_id
          WHERE t.owner_id = @ownerId::uuid 
            AND (t.is_public = TRUE OR t.owner_id = @uidStr::uuid)
          GROUP BY t.id
          ORDER BY t.created_at DESC
          ''',
        ),
        parameters: {'ownerId': id, 'uidStr': uidStr},
      );

      final tracks = tracksRs.map((row) {
        return {
          'id': row[0].toString(),
          'title': row[1].toString(),
          'artist': row[2].toString(),
          'stream_url': row[3].toString(),
          'artwork_url': row[4],
          'duration_seconds': row[5],
          'likes_count': int.tryParse(row[6]?.toString() ?? '0') ?? 0,
          'is_liked': row[7] == true,
          'can_delete': row[8] == true,
        };
      }).toList();

      return jsonRes({
        'user': user,
        'tracks': tracks,
      });
    } catch (e, st) {
      print('GET USER ERROR: $e\n$st');
      return jsonRes({'error': e.toString()}, status: 500);
    }
  });

  // Избранное пользователя
  router.get('/v1/users/<id>/liked', (Request req, String id) async {
    final uid = userIdFromToken(req);
    final uidStr = uid ?? '';
    try {
      final rs = await conn.execute(
        Sql.named(
          '''
          SELECT
            t.id::text, t.title, t.artist, t.stream_url, t.artwork_url,
            t.duration_seconds, t.owner_id::text, COUNT(l2.user_id),
            CASE
              WHEN @uidStr != '' AND MAX(CASE WHEN l2.user_id::text = @uidStr THEN 1 ELSE 0 END) = 1
              THEN true ELSE false
            END AS is_l
          FROM track_likes l
          JOIN tracks t ON t.id = l.track_id
          LEFT JOIN track_likes l2 ON l2.track_id = t.id
          WHERE l.user_id = @profileId::uuid 
            AND (t.is_public = TRUE OR t.owner_id = @uidStr::uuid)
          GROUP BY t.id, l.created_at
          ORDER BY l.created_at DESC
          ''',
        ),
        parameters: {'profileId': id, 'uidStr': uidStr},
      );
      final tracks = rs.map((row) {
        return {
          'id': row[0].toString(),
          'title': row[1].toString(),
          'artist': row[2].toString(),
          'stream_url': row[3].toString(),
          'artwork_url': row[4],
          'duration_seconds': row[5],
          'owner_id': row[6]?.toString(),
          'likes_count': int.tryParse(row[7]?.toString() ?? '0') ?? 0,
          'is_liked': row[8] == true,
          'can_delete': false,
        };
      }).toList();
      return jsonRes({'tracks': tracks});
    } catch (e, st) {
      print('LIKED ERROR: $e\n$st');
      return jsonRes({'error': e.toString()}, status: 500);
    }
  });

  // --- PLAYLISTS ---

  // Список плейлистов текущего пользователя
  router.get('/v1/playlists', (Request req) async {
    final uid = userIdFromToken(req);
    if (uid == null) return jsonRes({'error': 'Не авторизован'}, status: 401);
    try {
      final rs = await conn.execute(
        Sql.named(
          '''
          SELECT 
            p.id::text, p.name, p.description, p.artwork_url, p.is_public, p.created_at,
            (SELECT COUNT(*) FROM playlist_tracks WHERE playlist_id = p.id) AS track_count
          FROM playlists p
          WHERE p.owner_id = @uid::uuid
          ORDER BY p.created_at DESC
          ''',
        ),
        parameters: {'uid': uid},
      );
      final list = rs.map((row) {
        return {
          'id': row[0].toString(),
          'name': row[1],
          'description': row[2],
          'artwork_url': row[3],
          'is_public': row[4] == true,
          'created_at': row[5]?.toString(),
          'track_count': int.tryParse(row[6]?.toString() ?? '0') ?? 0,
        };
      }).toList();
      return jsonRes({'playlists': list});
    } catch (e) {
      return jsonRes({'error': e.toString()}, status: 500);
    }
  });

  // Создать новый плейлист
  router.post('/v1/playlists', (Request req) async {
    final uid = userIdFromToken(req);
    if (uid == null) return jsonRes({'error': 'Не авторизован'}, status: 401);
    try {
      final body = jsonDecode(await req.readAsString());
      final name = (body['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) return jsonRes({'error': 'Введите название'}, status: 400);

      final rs = await conn.execute(
        Sql.named(
          '''
          INSERT INTO playlists (owner_id, name, description, is_public)
          VALUES (@uid::uuid, @name, @desc, @pub)
          RETURNING id::text, name, description, artwork_url, is_public, created_at
          ''',
        ),
        parameters: {
          'uid': uid,
          'name': name,
          'desc': body['description'],
          'pub': body['is_public'] == true,
        },
      );
      final row = rs.first;
      return jsonRes({
        'playlist': {
          'id': row[0].toString(),
          'name': row[1],
          'description': row[2],
          'artwork_url': row[3],
          'is_public': row[4] == true,
          'created_at': row[5]?.toString(),
          'track_count': 0,
        }
      }, status: 201);
    } catch (e) {
      return jsonRes({'error': e.toString()}, status: 500);
    }
  });

  // Получить детали плейлиста и его треки
  router.get('/v1/playlists/<id>', (Request req, String id) async {
    final uid = userIdFromToken(req);
    final uidStr = uid ?? '';
    try {
      final plRs = await conn.execute(
        Sql.named('SELECT id::text, owner_id::text, name, description, artwork_url, is_public FROM playlists WHERE id = @id::uuid'),
        parameters: {'id': id},
      );
      if (plRs.isEmpty) return jsonRes({'error': 'Плейлист не найден'}, status: 404);
      final plRow = plRs.first;
      if (plRow[5] == false && plRow[1] != uidStr) {
        return jsonRes({'error': 'Доступ ограничен'}, status: 403);
      }

      final trRs = await conn.execute(
        Sql.named(
          '''
          SELECT 
            t.id::text, t.title, t.artist, t.stream_url, t.artwork_url, t.duration_seconds,
            (SELECT COUNT(*) FROM track_likes WHERE track_id = t.id) AS l_count,
            CASE
              WHEN @uidStr != '' AND EXISTS(SELECT 1 FROM track_likes WHERE track_id = t.id AND user_id::text = @uidStr)
              THEN true ELSE false
            END AS is_l
          FROM playlist_tracks pt
          JOIN tracks t ON pt.track_id = t.id
          WHERE pt.playlist_id = @id::uuid
          ORDER BY pt.position, pt.added_at
          ''',
        ),
        parameters: {'id': id, 'uidStr': uidStr},
      );

      final tracks = trRs.map((row) {
        return {
          'id': row[0].toString(),
          'title': row[1].toString(),
          'artist': row[2].toString(),
          'stream_url': row[3].toString(),
          'artwork_url': row[4],
          'duration_seconds': row[5],
          'likes_count': int.tryParse(row[6]?.toString() ?? '0') ?? 0,
          'is_liked': row[7] == true,
        };
      }).toList();

      return jsonRes({
        'playlist': {
          'id': plRow[0],
          'name': plRow[2],
          'description': plRow[3],
          'artwork_url': plRow[4],
          'is_public': plRow[5],
        },
        'tracks': tracks,
      });
    } catch (e) {
      return jsonRes({'error': e.toString()}, status: 500);
    }
  });

  // Редактировать плейлист
  router.patch('/v1/playlists/<id>', (Request req, String id) async {
    final uid = userIdFromToken(req);
    if (uid == null) return jsonRes({'error': 'Не авторизован'}, status: 401);
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final name = body['name'] as String?;
      final description = body['description'] as String?;
      final isPublic = body['is_public'] as bool?;
      final artworkUrl = body['artwork_url'] as String?;

      if (name != null && name.trim().isEmpty) {
        return jsonRes({'error': 'Название не может быть пустым'}, status: 400);
      }

      final rs = await conn.execute(
        Sql.named(
          '''
          UPDATE playlists 
          SET 
            name = COALESCE(@name, name),
            description = COALESCE(@desc, description),
            is_public = COALESCE(@pub, is_public),
            artwork_url = COALESCE(@art, artwork_url)
          WHERE id = @id::uuid AND owner_id = @uid::uuid
          RETURNING id::text, name, description, artwork_url, is_public, created_at
          ''',
        ),
        parameters: {
          'id': id,
          'uid': uid,
          'name': name?.trim(),
          'desc': description?.trim(),
          'pub': isPublic,
          'art': artworkUrl,
        },
      );

      if (rs.isEmpty) {
        return jsonRes({'error': 'Плейлист не найден или нет прав'}, status: 404);
      }

      final row = rs.first;
      // Получаем актуальное количество треков
      final countRs = await conn.execute(
        Sql.named('SELECT COUNT(*) FROM playlist_tracks WHERE playlist_id = @id::uuid'),
        parameters: {'id': id},
      );
      final count = int.tryParse(countRs.first[0]?.toString() ?? '0') ?? 0;

      return jsonRes({
        'playlist': {
          'id': row[0].toString(),
          'name': row[1],
          'description': row[2],
          'artwork_url': row[3],
          'is_public': row[4] == true,
          'created_at': row[5]?.toString(),
          'track_count': count,
        }
      });
    } catch (e) {
      return jsonRes({'error': e.toString()}, status: 500);
    }
  });

  // Удалить плейлист
  router.delete('/v1/playlists/<id>', (Request req, String id) async {
    final uid = userIdFromToken(req);
    if (uid == null) return jsonRes({'error': 'Не авторизован'}, status: 401);
    try {
      final rs = await conn.execute(
        Sql.named('DELETE FROM playlists WHERE id = @id::uuid AND owner_id = @uid::uuid RETURNING id'),
        parameters: {'id': id, 'uid': uid},
      );
      if (rs.isEmpty) return jsonRes({'error': 'Плейлист не найден или нет прав'}, status: 404);
      return jsonRes({'ok': true});
    } catch (e) {
      return jsonRes({'error': e.toString()}, status: 500);
    }
  });

  // Добавить трек в плейлист
  router.post('/v1/playlists/<id>/tracks', (Request req, String id) async {
    final uid = userIdFromToken(req);
    if (uid == null) return jsonRes({'error': 'Не авторизован'}, status: 401);
    try {
      final body = jsonDecode(await req.readAsString());
      final trackId = body['track_id'] as String?;
      if (trackId == null) return jsonRes({'error': 'track_id required'}, status: 400);

      // Проверка прав на плейлист
      final plCheck = await conn.execute(
        Sql.named('SELECT id FROM playlists WHERE id = @id::uuid AND owner_id = @uid::uuid'),
        parameters: {'id': id, 'uid': uid},
      );
      if (plCheck.isEmpty) return jsonRes({'error': 'Плейлист не найден или нет прав'}, status: 404);

      // Получаем текущую макс позицию
      final posRs = await conn.execute(
        Sql.named('SELECT COALESCE(MAX(position), -1) + 1 FROM playlist_tracks WHERE playlist_id = @id::uuid'),
        parameters: {'id': id},
      );
      final pos = posRs.first[0] as int;

      await conn.execute(
        Sql.named('INSERT INTO playlist_tracks (playlist_id, track_id, position) VALUES (@pid::uuid, @tid::uuid, @pos) ON CONFLICT DO NOTHING'),
        parameters: {'pid': id, 'tid': trackId, 'pos': pos},
      );
      return jsonRes({'ok': true});
    } catch (e) {
      return jsonRes({'error': e.toString()}, status: 500);
    }
  });

  // Удалить трек из плейлиста
  router.delete('/v1/playlists/<id>/tracks/<trackId>', (Request req, String id, String trackId) async {
    final uid = userIdFromToken(req);
    if (uid == null) return jsonRes({'error': 'Не авторизован'}, status: 401);
    try {
      final rs = await conn.execute(
        Sql.named(
          '''
          DELETE FROM playlist_tracks 
          WHERE playlist_id = @pid::uuid 
            AND track_id = @tid::uuid
            AND EXISTS (SELECT 1 FROM playlists WHERE id = @pid::uuid AND owner_id = @uid::uuid)
          RETURNING track_id
          ''',
        ),
        parameters: {'pid': id, 'tid': trackId, 'uid': uid},
      );
      if (rs.isEmpty) return jsonRes({'error': 'Трек не найден или нет прав'}, status: 404);
      return jsonRes({'ok': true});
    } catch (e) {
      return jsonRes({'error': e.toString()}, status: 500);
    }
  });

  // Прокси для изображений (для обхода CORS на Web)
  router.get('/v1/proxy/image', (Request req) async {
    final url = req.url.queryParameters['url'];
    if (url == null || url.isEmpty) return Response.notFound('Missing url');

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return Response(response.statusCode);

      return Response.ok(
        response.bodyBytes,
        headers: {
          'Content-Type': response.headers['content-type'] ?? 'image/jpeg',
          'Cache-Control': 'public, max-age=86400', // 1 day cache
          'Access-Control-Allow-Origin': '*',
        },
      );
    } catch (e) {
      return Response.internalServerError(body: e.toString());
    }
  });

  return router.call;
}

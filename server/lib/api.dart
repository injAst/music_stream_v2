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
import 'package:shelf_router/shelf_router.dart';

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

  final conn = await Connection.openFromUrl(dbUrl);
  final app = _buildApp(conn: conn, jwtSecret: jwtSecret);
  final handler = Pipeline().addMiddleware(corsHeaders()).addHandler(app);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('Pulse Music API → http://${server.address.host}:${server.port}');
}

Handler _buildApp({required Connection conn, required String jwtSecret}) {
  final router = Router();

  Response jsonRes(Object? body, {int status = 200}) => Response(
        status,
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );

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
    };
  }

  router.get('/health', (_) => Response.ok('ok'));

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
          SELECT id::text AS id, email, display_name, avatar_url
          FROM app_users WHERE id = @id::uuid
          ''',
        ),
        parameters: {'id': uid},
      );
      if (rs.isEmpty) return jsonRes({'error': 'Пользователь не найден'}, status: 404);
      return jsonRes({'user': userJson(rs.first)});
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
            COUNT(l.user_id) AS likes_count,
            CASE
              WHEN @uidStr != '' AND MAX(CASE WHEN l.user_id::text = @uidStr THEN 1 ELSE 0 END) = 1
              THEN true ELSE false
            END AS is_liked,
            CASE
              WHEN @uidStr != '' AND t.owner_id IS NOT NULL AND t.owner_id::text = @uidStr
              THEN true ELSE false
            END AS can_delete
          FROM tracks t
          LEFT JOIN track_likes l ON t.id = l.track_id
          WHERE t.is_public = TRUE
             OR (@uidStr != '' AND t.owner_id IS NOT NULL AND t.owner_id::text = @uidStr)
          GROUP BY t.id
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
      if (title.isEmpty || artist.isEmpty || streamUrl.isEmpty) {
        return jsonRes({'error': 'Заполните название, исполнителя и URL'}, status: 400);
      }
      if (!streamUrl.startsWith('http://') && !streamUrl.startsWith('https://')) {
        return jsonRes({'error': 'URL должен начинаться с http:// или https://'}, status: 400);
      }
      final rs = await conn.execute(
        Sql.named(
          '''
          INSERT INTO tracks (owner_id, is_public, title, artist, stream_url, artwork_url)
          VALUES (@owner::uuid, FALSE, @title, @artist, @stream_url, @artwork)
          RETURNING id::text AS id, title, artist, stream_url, artwork_url, duration_seconds
          ''',
        ),
        parameters: {
          'owner': uid,
          'title': title,
          'artist': artist,
          'stream_url': streamUrl,
          'artwork': artworkUrl != null && artworkUrl.isNotEmpty ? artworkUrl : null,
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
          WHERE id = @tid::uuid AND owner_id = @uid::uuid AND is_public = FALSE
          RETURNING id
          ''',
        ),
        parameters: {'tid': id, 'uid': uid},
      );
      if (rs.isEmpty) {
        return jsonRes({'error': 'Трек не найден или нет прав'}, status: 404);
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

  return router.call;
}

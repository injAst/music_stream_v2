import 'dart:io';
import 'package:dotenv/dotenv.dart';
import 'package:postgres/postgres.dart';

Future<void> main() async {
  final dotEnv = DotEnv(includePlatformEnvironment: true)..load();
  final dbUrl = dotEnv['DATABASE_URL'];
  
  if (dbUrl == null || dbUrl.isEmpty) {
    print('Ошибка: DATABASE_URL не найден в .env');
    exit(1);
  }

  print('Подключение к БД...');
  final conn = await Connection.openFromUrl(dbUrl);
  print('Успешно подключено!');
  
  try {
    String query = '''
      CREATE TABLE IF NOT EXISTS track_likes (
        user_id UUID REFERENCES app_users (id) ON DELETE CASCADE,
        track_id UUID REFERENCES tracks (id) ON DELETE CASCADE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        PRIMARY KEY (user_id, track_id)
      );
      
      CREATE INDEX IF NOT EXISTS idx_likes_track ON track_likes (track_id);
      CREATE INDEX IF NOT EXISTS idx_likes_user ON track_likes (user_id);
    ''';

    for (var q in query.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty)) {
      print('Выполнение: \${q.substring(0, q.length > 50 ? 50 : q.length)}...');
      await conn.execute(Sql.named(q));
    }
    
    print('Таблица track_likes успешно создана!');
  } catch (e) {
    print('Ошибка: \$e');
  } finally {
    await conn.close();
  }
}

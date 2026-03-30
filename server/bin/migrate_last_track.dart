import 'dart:io';
import 'package:dotenv/dotenv.dart';
import 'package:postgres/postgres.dart';

Future<void> main() async {
  final dotEnv = DotEnv(includePlatformEnvironment: true)..load(['server/.env']);
  final dbUrl = dotEnv['DATABASE_URL'];
  
  if (dbUrl == null || dbUrl.isEmpty) {
    print('Ошибка: DATABASE_URL не найден в .env');
    exit(1);
  }

  print('Подключение к БД...');
  final conn = await Connection.openFromUrl(dbUrl);
  print('Успешно подключено!');

  try {
    print('Добавление колонок в app_users...');
    await conn.execute(Sql.named('''
      ALTER TABLE app_users 
      ADD COLUMN IF NOT EXISTS last_played_track_id UUID REFERENCES tracks(id) ON DELETE SET NULL,
      ADD COLUMN IF NOT EXISTS last_played_at TIMESTAMPTZ;
    '''));
    print('Миграция успешно завершена!');
  } catch (e) {
    print('Ошибка при миграции: $e');
  } finally {
    await conn.close();
  }
}

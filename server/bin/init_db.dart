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

  print('Чтение schema.sql...');
  final schemaFile = File('sql/schema.sql');
  if (!await schemaFile.exists()) {
    print('Ошибка: файл sql/schema.sql не найден');
    exit(1);
  }
  
  final schemaSql = await schemaFile.readAsString();
  
  // postgres packet doesn't support multiple commands in a single execute by default if they return results, 
  // but for DDL statements it usually works, or we can split. Let's try to run it.
  
  try {
    // В пакете `postgres` выполнение нескольких операторов через `execute` иногда выдает ошибку "cannot insert multiple commands". 
    // Вместо этого можно разбить текст по точке с запятой или использовать `execute(Sql.named(query))` для каждого.
    String dropOld = 'DROP TABLE IF EXISTS tracks CASCADE; DROP TABLE IF EXISTS app_users CASCADE;';
    for (var d in dropOld.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty)) {
      await conn.execute(Sql.named(d));
    }

    final queries = schemaSql.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty && !e.startsWith('--'));

    for (final q in queries) {
      print('Выполнение: ${q.substring(0, q.length > 50 ? 50 : q.length)}...');
      await conn.execute(Sql.named(q));
    }
    
    print('Схема базы данных успешно создана и заполнена тестовыми треками!');
  } catch (e) {
    print('Ошибка при создании таблиц: $e');
  } finally {
    await conn.close();
  }
}

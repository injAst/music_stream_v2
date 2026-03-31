import 'package:postgres/postgres.dart';
import 'package:dotenv/dotenv.dart';

Future<void> main() async {
  final dotEnv = DotEnv(includePlatformEnvironment: true)..load();
  final dbUrl = dotEnv['DATABASE_URL'];
  if (dbUrl == null) {
    print('DATABASE_URL not found in .env');
    return;
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

  final conn = await Connection.open(endpoint, settings: ConnectionSettings(sslMode: sslMode));

  print('Applying playlist migrations...');

  await conn.execute('DROP TABLE IF EXISTS playlist_tracks');
  await conn.execute('DROP TABLE IF EXISTS playlists');

  await conn.execute('''
    CREATE TABLE IF NOT EXISTS playlists (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      owner_id UUID NOT NULL REFERENCES app_users (id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      description TEXT,
      artwork_url TEXT,
      is_public BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  ''');

  await conn.execute('''
    CREATE TABLE IF NOT EXISTS playlist_tracks (
      playlist_id UUID REFERENCES playlists (id) ON DELETE CASCADE,
      track_id UUID REFERENCES tracks (id) ON DELETE CASCADE,
      position INT NOT NULL,
      added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (playlist_id, track_id)
    )
  ''');

  await conn.execute('CREATE INDEX IF NOT EXISTS idx_playlists_owner ON playlists (owner_id)');
  await conn.execute('CREATE INDEX IF NOT EXISTS idx_playlist_tracks_playlist ON playlist_tracks (playlist_id)');

  print('Migration completed successfully!');
  await conn.close();
}

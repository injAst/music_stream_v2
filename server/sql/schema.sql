-- Выполните в pgAdmin или: psql -U postgres -d music_stream -f sql/schema.sql

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS app_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  display_name TEXT NOT NULL,
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tracks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID REFERENCES app_users (id) ON DELETE CASCADE,
  is_public BOOLEAN NOT NULL DEFAULT FALSE,
  title TEXT NOT NULL,
  artist TEXT NOT NULL,
  stream_url TEXT NOT NULL,
  artwork_url TEXT,
  duration_seconds INT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tracks_public ON tracks (is_public) WHERE is_public = TRUE;
CREATE INDEX IF NOT EXISTS idx_tracks_owner ON tracks (owner_id);

INSERT INTO tracks (owner_id, is_public, title, artist, stream_url, artwork_url, duration_seconds)
SELECT NULL, TRUE, 'SoundHelix Song 1', 'SoundHelix',
  'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
  'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400', 372
WHERE NOT EXISTS (SELECT 1 FROM tracks WHERE is_public = TRUE AND title = 'SoundHelix Song 1');

INSERT INTO tracks (owner_id, is_public, title, artist, stream_url, artwork_url, duration_seconds)
SELECT NULL, TRUE, 'SoundHelix Song 2', 'SoundHelix',
  'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
  'https://images.unsplash.com/photo-1511379938547-c1f69419868d?w=400', 393
WHERE NOT EXISTS (SELECT 1 FROM tracks WHERE is_public = TRUE AND title = 'SoundHelix Song 2');

INSERT INTO tracks (owner_id, is_public, title, artist, stream_url, artwork_url, duration_seconds)
SELECT NULL, TRUE, 'SoundHelix Song 3', 'SoundHelix',
  'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
  'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=400', 418
WHERE NOT EXISTS (SELECT 1 FROM tracks WHERE is_public = TRUE AND title = 'SoundHelix Song 3');

CREATE TABLE IF NOT EXISTS track_likes (
  user_id UUID REFERENCES app_users (id) ON DELETE CASCADE,
  track_id UUID REFERENCES tracks (id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, track_id)
);

CREATE INDEX IF NOT EXISTS idx_likes_track ON track_likes (track_id);
CREATE INDEX IF NOT EXISTS idx_likes_user ON track_likes (user_id);

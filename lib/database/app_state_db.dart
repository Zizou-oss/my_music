import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppStateDb {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'app_state.db');
    _db = await openDatabase(
      path,
      version: 7,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE downloads (
            song_id INTEGER PRIMARY KEY,
            local_path TEXT NOT NULL,
            downloaded_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE listening_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            song_id INTEGER NOT NULL,
            session_id TEXT NOT NULL UNIQUE,
            started_at TEXT NOT NULL,
            ended_at TEXT NOT NULL,
            seconds_listened INTEGER NOT NULL,
            is_offline INTEGER NOT NULL DEFAULT 0,
            synced INTEGER NOT NULL DEFAULT 0,
            synced_at TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE cached_songs (
            id INTEGER PRIMARY KEY,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            cover TEXT NOT NULL,
            lyrics TEXT,
            lyrics_lrc TEXT,
            file TEXT,
            storage_path TEXT,
            plays_count INTEGER NOT NULL DEFAULT 0,
            created_at TEXT,
            updated_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE pending_download_sync (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            song_id INTEGER NOT NULL,
            app_version TEXT,
            device_id TEXT,
            created_at TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0,
            synced_at TEXT,
            UNIQUE(user_id, song_id)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS cached_songs (
              id INTEGER PRIMARY KEY,
              title TEXT NOT NULL,
              artist TEXT NOT NULL,
              cover TEXT NOT NULL,
              lyrics TEXT,
              lyrics_lrc TEXT,
              file TEXT,
              storage_path TEXT,
              updated_at TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS pending_download_sync (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id TEXT NOT NULL,
              song_id INTEGER NOT NULL,
              app_version TEXT,
              device_id TEXT,
              created_at TEXT NOT NULL,
              synced INTEGER NOT NULL DEFAULT 0,
              synced_at TEXT,
              UNIQUE(user_id, song_id)
            )
          ''');
        }
        if (oldVersion < 4) {
          try {
            await db.execute('''
              ALTER TABLE cached_songs
              ADD COLUMN lyrics TEXT
            ''');
          } catch (_) {
            // Column may already exist on some local states.
          }
        }
        if (oldVersion < 5) {
          try {
            await db.execute('''
              ALTER TABLE cached_songs
              ADD COLUMN plays_count INTEGER NOT NULL DEFAULT 0
            ''');
          } catch (_) {
            // Column may already exist on some local states.
          }
        }
        if (oldVersion < 6) {
          try {
            await db.execute('''
              ALTER TABLE cached_songs
              ADD COLUMN created_at TEXT
            ''');
          } catch (_) {
            // Column may already exist on some local states.
          }
        }
        if (oldVersion < 7) {
          try {
            await db.execute('''
              ALTER TABLE cached_songs
              ADD COLUMN lyrics_lrc TEXT
            ''');
          } catch (_) {
            // Column may already exist on some local states.
          }
        }
      },
    );
    return _db!;
  }
}

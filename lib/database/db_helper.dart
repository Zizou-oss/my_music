import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/song.dart';

class DBHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'music.db');

    return openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await _createSongsTable(db);
        await _populateDB(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await db.execute('DROP TABLE IF EXISTS songs');
        await _createSongsTable(db);
        await _populateDB(db);
      },
      onOpen: (db) async {
        try {
          final count = Sqflite.firstIntValue(
                await db.rawQuery('SELECT COUNT(*) FROM songs'),
              ) ??
              0;
          if (count == 0) {
            await _populateDB(db);
          }
        } catch (_) {
          await _createSongsTable(db);
          await _populateDB(db);
        }
      },
    );
  }

  static Future<void> _createSongsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS songs (
        id INTEGER PRIMARY KEY,
        title TEXT,
        file TEXT,
        cover TEXT,
        artist TEXT
      )
    ''');
  }

  static Future<List<Song>> _loadSongsFromJson() async {
    final data = await rootBundle.loadString('assets/songs.json');
    final jsonResult = json.decode(data) as List<dynamic>;
    return jsonResult
        .map((item) => Song.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  static Future<void> _populateDB(Database db) async {
    final songs = await _loadSongsFromJson();
    for (final song in songs) {
      await db.insert(
        'songs',
        song.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  static Future<List<Song>> getSongs() async {
    if (kIsWeb) {
      return _loadSongsFromJson();
    }

    final db = await database;
    final result = await db.query('songs');
    return result.map((e) => Song.fromMap(e)).toList();
  }
}


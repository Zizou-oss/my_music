import '../database/app_state_db.dart';
import '../models/song.dart';
import '../services/download_service.dart';
import '../services/supabase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

class SongRepository {
  final DownloadService _downloadService = DownloadService();

  Future<List<Song>> getSongs() async {
    final downloadedMap =
        (SupabaseService.isEnabled && SupabaseService.currentUser == null)
            ? <int, String>{}
            : await _downloadService.getDownloadedMap();

    if (!SupabaseService.isEnabled) {
      final cachedSongs = await _getCachedSongs();
      return cachedSongs
          .map((song) => song.copyWith(localPath: downloadedMap[song.id]))
          .toList();
    }

    try {
      dynamic rows;
      try {
        rows = await SupabaseService.client
            .from('songs')
            .select(
              'id, title, artist, cover_url, lyrics, lyrics_lrc, file, storage_path, plays_count, created_at',
            )
            .eq('is_published', true)
            .order('created_at', ascending: false)
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        try {
          rows = await SupabaseService.client
              .from('songs')
              .select(
                'id, title, artist, cover_url, lyrics, lyrics_lrc, file, storage_path, created_at',
              )
              .eq('is_published', true)
              .order('created_at', ascending: false)
              .timeout(const Duration(seconds: 5));
        } catch (_) {
          rows = await SupabaseService.client
              .from('songs')
              .select(
                'id, title, artist, cover_url, lyrics, file, storage_path, plays_count',
              )
              .eq('is_published', true)
              .order('id', ascending: false)
              .timeout(const Duration(seconds: 5));
        }
      }

      final mapped = (rows as List<dynamic>).map((row) {
        final map = row as Map<String, dynamic>;
        final cover =
            (map['cover_url'] ?? map['cover'] ?? 'cover.jpg').toString();
        final id = (map['id'] as num).toInt();
        return Song(
          id: id,
          title: (map['title'] ?? '').toString(),
          file: (map['file'] ?? '').toString(),
          cover: cover,
          artist: (map['artist'] ?? '2Block').toString(),
          lyrics: (map['lyrics'] ?? '').toString(),
          lyricsLrc: (map['lyrics_lrc'] ?? '').toString(),
          storagePath: (map['storage_path'] ?? '').toString(),
          playsCount: (map['plays_count'] as num?)?.toInt() ?? 0,
          localPath: downloadedMap[id],
          createdAt: _tryParseDate(map['created_at']),
        );
      }).toList();

      if (mapped.isNotEmpty) {
        await _cacheSongs(mapped);
        return mapped;
      }
    } catch (e) {
      debugPrint('SongRepository.getSongs remote query failed: $e');
      // fallback cache local
    }

    final cachedSongs = await _getCachedSongs();
    if (cachedSongs.isNotEmpty) {
      return cachedSongs
          .map((song) => song.copyWith(localPath: downloadedMap[song.id]))
          .toList();
    }

    return [];
  }

  Future<void> _cacheSongs(List<Song> songs) async {
    final db = await AppStateDb.database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final song in songs) {
      batch.insert(
        'cached_songs',
        {
          'id': song.id,
          'title': song.title,
          'artist': song.artist,
          'cover': song.cover,
          'lyrics': song.lyrics,
          'lyrics_lrc': song.lyricsLrc,
          'file': song.file,
          'storage_path': song.storagePath,
          'plays_count': song.playsCount,
          'created_at': song.createdAt?.toIso8601String(),
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Song>> _getCachedSongs() async {
    final db = await AppStateDb.database;
    final rows = await db.query(
      'cached_songs',
      orderBy: 'id ASC',
    );
    return rows
        .map(
          (row) => Song(
            id: (row['id'] as num).toInt(),
            title: (row['title'] ?? '').toString(),
            artist: (row['artist'] ?? '2Block').toString(),
            cover: (row['cover'] ?? 'cover.jpg').toString(),
            lyrics: (row['lyrics'] ?? '').toString(),
            lyricsLrc: (row['lyrics_lrc'] ?? '').toString(),
            file: (row['file'] ?? '').toString(),
            storagePath: (row['storage_path'] ?? '').toString(),
            playsCount: (row['plays_count'] as num?)?.toInt() ?? 0,
            createdAt: _tryParseDate(row['created_at'] ?? row['updated_at']),
          ),
        )
        .toList();
  }

  DateTime? _tryParseDate(dynamic value) {
    if (value == null) return null;
    final raw = value.toString();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}

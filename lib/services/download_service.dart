import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_state_db.dart';
import '../models/song.dart';
import 'supabase_service.dart';

class DownloadService {
  static const String _bucketName = 'songs-private';
  static const String _appVersion = '1.2.1+3';

  Future<Map<int, String>> getDownloadedMap() async {
    final db = await AppStateDb.database;
    final rows = await db.query('downloads');
    final map = <int, String>{};

    for (final row in rows) {
      final songId = (row['song_id'] as num).toInt();
      final localPath = (row['local_path'] ?? '').toString();
      final exists = await File(localPath).exists();
      if (exists) {
        map[songId] = localPath;
      } else {
        await db.delete('downloads', where: 'song_id = ?', whereArgs: [songId]);
      }
    }

    return map;
  }

  Future<String?> getLocalPathForSong(int songId) async {
    final db = await AppStateDb.database;
    final rows = await db.query(
      'downloads',
      where: 'song_id = ?',
      whereArgs: [songId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (rows.first['local_path'] ?? '').toString();
  }

  Future<void> downloadSong(
    Song song, {
    void Function(int receivedBytes, int totalBytes)? onProgress,
  }) async {
    if (!SupabaseService.isEnabled) {
      throw Exception('Supabase non configure');
    }
    if (SupabaseService.currentUser == null) {
      throw Exception('Connexion requise');
    }
    if (song.storagePath.isEmpty) {
      throw Exception('storage_path manquant pour ce morceau');
    }

    final signedUrl = await SupabaseService.client.storage
        .from(_bucketName)
        .createSignedUrl(song.storagePath, 60 * 10);

    final appDir = await getApplicationSupportDirectory();
    final songsDir = Directory(p.join(appDir.path, 'downloads', 'songs'));
    if (!await songsDir.exists()) {
      await songsDir.create(recursive: true);
    }

    final ext = p.extension(song.storagePath).isEmpty
        ? '.m4a'
        : p.extension(song.storagePath);
    final localPath = p.join(songsDir.path, '${song.id}$ext');
    final file = File(localPath);

    final client = http.Client();
    IOSink? sink;
    try {
      final request = http.Request('GET', Uri.parse(signedUrl));
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Telechargement impossible (${response.statusCode})');
      }

      if (await file.exists()) {
        await file.delete();
      }

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;
      onProgress?.call(0, totalBytes);

      sink = file.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        onProgress?.call(receivedBytes, totalBytes);
      }

      await sink.flush();
      await sink.close();
      sink = null;
      onProgress?.call(totalBytes > 0 ? totalBytes : receivedBytes, totalBytes);
    } catch (_) {
      try {
        if (sink != null) {
          await sink.close();
        }
      } catch (_) {}
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
      rethrow;
    } finally {
      client.close();
    }

    final db = await AppStateDb.database;
    await db.insert(
      'downloads',
      {
        'song_id': song.id,
        'local_path': localPath,
        'downloaded_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _registerDownloadWithFallback(
        songId: song.id, userId: SupabaseService.currentUser!.id);
  }

  Future<void> syncPendingDownloadRegistrations() async {
    if (!SupabaseService.isEnabled) return;
    final user = SupabaseService.currentUser;
    if (user == null) return;

    final db = await AppStateDb.database;
    final rows = await db.query(
      'pending_download_sync',
      where: 'synced = 0 AND user_id = ?',
      whereArgs: [user.id],
      orderBy: 'id ASC',
      limit: 200,
    );
    if (rows.isEmpty) return;

    for (final row in rows) {
      final id = (row['id'] as num).toInt();
      final songId = (row['song_id'] as num).toInt();
      try {
        await SupabaseService.client.rpc(
          'register_song_download',
          params: {
            'p_song_id': songId,
            'p_app_version': row['app_version'] ?? _appVersion,
            'p_device_id': row['device_id'],
          },
        );
        await db.update(
          'pending_download_sync',
          {
            'synced': 1,
            'synced_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      } catch (_) {
        // Stop early; retry on next sync opportunity.
        break;
      }
    }
  }

  Future<void> resetLocalAppData() async {
    final db = await AppStateDb.database;

    // Remove downloaded audio files stored in app private storage.
    final rows = await db.query('downloads', columns: ['local_path']);
    for (final row in rows) {
      final localPath = (row['local_path'] ?? '').toString();
      if (localPath.isEmpty) continue;
      try {
        final file = File(localPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Continue cleanup even if one file fails.
      }
    }

    // Reset local state to "zero" for next account/session.
    await db.transaction((txn) async {
      await txn.delete('downloads');
      await txn.delete('listening_queue');
      await txn.delete('pending_download_sync');
      await txn.delete('cached_songs');
    });

    // Try to remove empty folders if possible.
    try {
      final appDir = await getApplicationSupportDirectory();
      final songsDir = Directory(p.join(appDir.path, 'downloads', 'songs'));
      if (await songsDir.exists()) {
        await songsDir.delete(recursive: true);
      }
    } catch (_) {
      // Non-blocking cleanup.
    }
  }

  Future<void> _registerDownloadWithFallback({
    required int songId,
    required String userId,
  }) async {
    try {
      await SupabaseService.client.rpc(
        'register_song_download',
        params: {
          'p_song_id': songId,
          'p_app_version': _appVersion,
          'p_device_id': null,
        },
      );
    } catch (_) {
      final db = await AppStateDb.database;
      await db.insert(
        'pending_download_sync',
        {
          'user_id': userId,
          'song_id': songId,
          'app_version': _appVersion,
          'device_id': null,
          'created_at': DateTime.now().toIso8601String(),
          'synced': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
}

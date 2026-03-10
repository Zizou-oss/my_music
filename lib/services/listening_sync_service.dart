import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../database/app_state_db.dart';
import 'download_service.dart';
import 'supabase_service.dart';

class ListeningSyncService {
  static final ListeningSyncService _instance =
      ListeningSyncService._internal();
  factory ListeningSyncService() => _instance;
  ListeningSyncService._internal();

  final Uuid _uuid = const Uuid();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  DateTime? _lastOfflineCheckAt;
  bool _lastOfflineCheckValue = true;
  static const Duration _offlineCheckCacheTtl = Duration(seconds: 8);

  void _cacheOfflineState(bool isOffline) {
    _lastOfflineCheckAt = DateTime.now();
    _lastOfflineCheckValue = isOffline;
  }

  void startAutoSync() {
    _connectivitySubscription ??=
        Connectivity().onConnectivityChanged.listen((results) async {
      if (results.contains(ConnectivityResult.none)) {
        _cacheOfflineState(true);
        return;
      }
      final offline = await isCurrentlyOffline(forceRefresh: true);
      if (offline) return;
      await syncPendingEvents();
      await DownloadService().syncPendingDownloadRegistrations();
    });
  }

  Future<void> stopAutoSync() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  String newSessionId() => _uuid.v4();

  Future<bool> isCurrentlyOffline({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _lastOfflineCheckAt != null &&
        now.difference(_lastOfflineCheckAt!) < _offlineCheckCacheTtl) {
      return _lastOfflineCheckValue;
    }

    final results = await Connectivity().checkConnectivity();
    if (results.contains(ConnectivityResult.none)) {
      _cacheOfflineState(true);
      return true;
    }

    // Connectivity != Internet. Validate with a small Supabase reachability ping.
    if (!SupabaseService.isEnabled) {
      _cacheOfflineState(false);
      return false;
    }

    try {
      await SupabaseService.client
          .from('songs')
          .select('id')
          .eq('is_published', true)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 3));
      _cacheOfflineState(false);
      return false;
    } catch (_) {
      _cacheOfflineState(true);
      return true;
    }
  }

  Future<void> queueListeningEvent({
    required int songId,
    required String sessionId,
    required DateTime startedAt,
    required DateTime endedAt,
    required int secondsListened,
    required bool isOffline,
  }) async {
    final user = SupabaseService.currentUser;
    if (user == null) return;

    final db = await AppStateDb.database;
    await db.insert(
      'listening_queue',
      {
        'user_id': user.id,
        'song_id': songId,
        'session_id': sessionId,
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt.toIso8601String(),
        'seconds_listened': secondsListened,
        'is_offline': isOffline ? 1 : 0,
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> syncPendingEvents() async {
    if (!SupabaseService.isEnabled) return;
    if (await isCurrentlyOffline()) return;
    final user = SupabaseService.currentUser;
    if (user == null) return;

    final db = await AppStateDb.database;
    while (true) {
      final rows = await db.query(
        'listening_queue',
        where: 'synced = 0 AND user_id = ?',
        whereArgs: [user.id],
        orderBy: 'id ASC',
        limit: 200,
      );

      if (rows.isEmpty) return;

      final payload = rows.map((row) {
        return {
          'song_id': row['song_id'],
          'session_id': row['session_id'],
          'started_at': row['started_at'],
          'ended_at': row['ended_at'],
          'seconds_listened': row['seconds_listened'],
          'is_offline': row['is_offline'] == 1,
        };
      }).toList();

      await SupabaseService.client.rpc(
        'sync_listening_events',
        params: {'p_events': payload},
      ).timeout(const Duration(seconds: 6));

      final ids = rows.map((e) => (e['id'] as num).toInt()).toList();
      final now = DateTime.now().toIso8601String();
      final idPlaceholders = List.filled(ids.length, '?').join(',');
      await db.rawUpdate(
        'UPDATE listening_queue SET synced = 1, synced_at = ? WHERE id IN ($idPlaceholders)',
        [now, ...ids],
      );
    }
  }
}

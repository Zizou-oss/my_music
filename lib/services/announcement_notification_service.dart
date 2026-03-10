import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'supabase_service.dart';

class AnnouncementNotificationService {
  static final AnnouncementNotificationService _instance =
      AnnouncementNotificationService._internal();
  factory AnnouncementNotificationService() => _instance;
  AnnouncementNotificationService._internal();

  static const String _channelId = '2block_updates';
  static const String _channelName = '2Block Updates';
  static const String _channelDescription = 'Nouveaux sons et mises a jour';
  static const int _newSongNotifId = 1101;
  static const int _appUpdateNotifId = 1102;
  static const String _defaultReleaseUrl = 'https://2block-web-ctth.vercel.app/';
  static const String _appUpdatePayloadPrefix = 'release_url:';

  static const String _lastSeenSongIdKey = 'notif_last_seen_song_id';
  static const String _lastNotifiedAppVersionKey = 'notif_last_app_version';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Timer? _timer;
  RealtimeChannel? _songsChannel;
  bool _initialized = false;

  Future<void> start() async {
    if (!SupabaseService.isEnabled) return;
    await _initialize();
    await _subscribeToSongRealtime();
    await checkNow();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 10), (_) async {
      await checkNow();
    });
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    if (_songsChannel != null) {
      await SupabaseService.client.removeChannel(_songsChannel!);
      _songsChannel = null;
    }
  }

  Future<void> _initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        unawaited(_handleNotificationResponse(response));
      },
    );

    final androidImpl = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.defaultImportance,
      ),
    );

    final iosImpl = _localNotifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);

    final launchDetails =
        await _localNotifications.getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if (launchDetails?.didNotificationLaunchApp == true && launchResponse != null) {
      await _handleNotificationResponse(launchResponse);
    }

    _initialized = true;
  }

  Future<void> checkNow() async {
    if (!SupabaseService.isEnabled) return;
    try {
      await _checkNewPublishedSong();
      await _checkAppUpdateAnnouncement();
    } catch (e) {
      debugPrint('AnnouncementNotificationService.checkNow failed: $e');
    }
  }

  Future<void> _subscribeToSongRealtime() async {
    if (_songsChannel != null) return;

    _songsChannel = SupabaseService.client
        .channel('public:songs_mobile_announcements')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'songs',
          callback: (payload) async {
            await _handleRealtimeSong(
              payload.newRecord,
              oldRecord: const <String, dynamic>{},
            );
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'songs',
          callback: (payload) async {
            await _handleRealtimeSong(
              payload.newRecord,
              oldRecord: payload.oldRecord,
            );
          },
        )
        .subscribe();
  }

  Future<void> _handleRealtimeSong(
    Map<String, dynamic> newRecord, {
    required Map<String, dynamic> oldRecord,
  }) async {
    final isPublishedNow = _toBool(newRecord['is_published']);
    if (!isPublishedNow) return;

    final wasPublishedBefore = _toBool(oldRecord['is_published']);
    if (wasPublishedBefore) return;

    final songId = (newRecord['id'] as num?)?.toInt();
    if (songId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final lastSeenSongId = prefs.getInt(_lastSeenSongIdKey);
    if (lastSeenSongId != null && songId <= lastSeenSongId) return;

    final title = (newRecord['title'] ?? 'Nouveau son').toString();
    final artist = (newRecord['artist'] ?? '2Block').toString();
    await _showNewSongNotification(title, artist);
    await prefs.setInt(_lastSeenSongIdKey, songId);
  }

  Future<void> _checkNewPublishedSong() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSeenSongId = prefs.getInt(_lastSeenSongIdKey);

    final rows = await SupabaseService.client
        .from('songs')
        .select('id, title, artist')
        .eq('is_published', true)
        .order('id', ascending: false)
        .limit(1);

    if (rows.isEmpty) return;
    final latest = Map<String, dynamic>.from(rows.first as Map);
    final latestSongId = (latest['id'] as num?)?.toInt();
    if (latestSongId == null) return;

    if (lastSeenSongId == null) {
      await prefs.setInt(_lastSeenSongIdKey, latestSongId);
      return;
    }

    if (latestSongId <= lastSeenSongId) return;

    final title = (latest['title'] ?? 'Nouveau son').toString();
    final artist = (latest['artist'] ?? '2Block').toString();
    await _showNewSongNotification(title, artist);

    await prefs.setInt(_lastSeenSongIdKey, latestSongId);
  }

  Future<void> _showNewSongNotification(String title, String artist) async {
    await _localNotifications.show(
      _newSongNotifId,
      'Nouveau son disponible! \n T\'as pas encore écouté ?',
      '$title - $artist',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> _checkAppUpdateAnnouncement() async {
    final prefs = await SharedPreferences.getInstance();

    final row = await SupabaseService.client
        .from('app_settings')
        .select('value')
        .eq('key', 'latest_mobile_release')
        .maybeSingle();

    if (row == null) return;
    final value = row['value'];
    if (value is! Map) return;
    final valueMap = Map<String, dynamic>.from(value);

    final remoteVersion = (valueMap['version'] ?? '').toString().trim();
    if (remoteVersion.isEmpty) return;

    final alreadyNotifiedVersion = prefs.getString(_lastNotifiedAppVersionKey);
    if (alreadyNotifiedVersion == remoteVersion) return;

    final packageInfo = await PackageInfo.fromPlatform();
    final localVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

    if (!_isRemoteVersionNewer(remoteVersion, localVersion)) return;

    final title =
        (valueMap['title'] ?? 'Mise a jour disponible').toString().trim();
    final message = (valueMap['message'] ??
            'Une nouvelle version de 2Block Music est disponible.')
        .toString()
        .trim();
    final releaseUrl =
        (valueMap['download_url'] ?? _defaultReleaseUrl).toString().trim();
    final sizeBytes = (valueMap['apk_size_bytes'] as num?)?.toInt();
    final sha256 = (valueMap['apk_sha256'] ?? '').toString().trim();
    final detailsLine = _buildReleaseDetailsLine(
      sizeBytes: sizeBytes,
      sha256: sha256,
    );
    final notificationBody = [
      message.isEmpty
          ? 'Une nouvelle version de 2Block Music est disponible.'
          : message,
      if (detailsLine != null) detailsLine,
    ].join('\n');

    await _localNotifications.show(
      _appUpdateNotifId,
      title.isEmpty ? 'Mise a jour disponible' : title,
      notificationBody,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: '$_appUpdatePayloadPrefix$releaseUrl',
    );

    await prefs.setString(_lastNotifiedAppVersionKey, remoteVersion);
  }

  Future<void> _handleNotificationResponse(NotificationResponse response) async {
    final payload = response.payload?.trim() ?? '';
    if (!payload.startsWith(_appUpdatePayloadPrefix)) return;

    final url = payload.substring(_appUpdatePayloadPrefix.length).trim();
    if (url.isEmpty) return;

    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  String? _buildReleaseDetailsLine({
    required int? sizeBytes,
    required String sha256,
  }) {
    final parts = <String>[];

    if (sizeBytes != null && sizeBytes > 0) {
      final sizeMb = sizeBytes / (1024 * 1024);
      parts.add('${sizeMb.toStringAsFixed(1)} MB');
    }

    if (sha256.length == 64) {
      parts.add('SHA-256: ${sha256.substring(0, 12)}...');
    }

    if (parts.isEmpty) return null;
    return parts.join(' | ');
  }

  bool _isRemoteVersionNewer(String remote, String local) {
    final remoteParts = _normalizeVersionParts(remote);
    final localParts = _normalizeVersionParts(local);
    final maxLen = remoteParts.length > localParts.length
        ? remoteParts.length
        : localParts.length;

    for (var i = 0; i < maxLen; i++) {
      final r = i < remoteParts.length ? remoteParts[i] : 0;
      final l = i < localParts.length ? localParts[i] : 0;
      if (r > l) return true;
      if (r < l) return false;
    }
    return false;
  }

  List<int> _normalizeVersionParts(String version) {
    final cleaned = version.trim();
    if (cleaned.isEmpty) return <int>[0];

    final split = cleaned.split(RegExp(r'[.+-]'));
    final parts = <int>[];
    for (final token in split) {
      final digits = token.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isEmpty) {
        parts.add(0);
      } else {
        parts.add(int.tryParse(digits) ?? 0);
      }
    }
    return parts;
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    final v = value?.toString().toLowerCase().trim();
    return v == 'true' || v == '1' || v == 't';
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../firebase_options.dart';
import 'supabase_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    final data = <String, dynamic>{...message.data};
    final title = data['title']?.toString().trim() ??
        message.notification?.title?.trim() ??
        '2Block Music';
    final body = data['body']?.toString().trim() ??
        message.notification?.body?.trim() ??
        '';

    if (title.isEmpty && body.isEmpty) {
      debugPrint('Push BG ignore: empty title/body');
      return;
    }

    final plugin = FlutterLocalNotificationsPlugin();
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);
    await plugin.initialize(
      settings,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final androidImpl = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        PushNotificationService._channelId,
        PushNotificationService._channelName,
        description: PushNotificationService._channelDescription,
        importance: Importance.high,
      ),
    );

    await plugin.show(
      message.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          PushNotificationService._channelId,
          PushNotificationService._channelName,
          channelDescription: PushNotificationService._channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(data),
    );
    debugPrint('Push BG local shown: title="$title" data=$data');
  } catch (_) {
    // Keep background handler resilient if Firebase options are unavailable.
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // Launch handling is done on app resume/start using app launch details.
}

class PushNotificationService with WidgetsBindingObserver {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  static const String _channelId = '2block_push_channel';
  static const String _channelName = '2Block Push';
  static const String _channelDescription = 'Notifications push 2Block Music';
  static const String _lastFcmTokenKey = 'last_fcm_token';
  static const String _appDownloadUrl = 'https://2block-web-ctth.vercel.app/';

  FirebaseMessaging? _messagingInstance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<AuthState>? _authSub;
  bool _initialized = false;
  bool _observerRegistered = false;
  String? _pendingUrlToOpen;
  bool _openingPendingUrl = false;
  int _pendingUrlAttemptCount = 0;

  FirebaseMessaging get _messaging {
    final messaging = _messagingInstance;
    if (messaging == null) {
      throw StateError('PushNotificationService is not initialized');
    }
    return messaging;
  }

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    if (!_observerRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _messagingInstance = FirebaseMessaging.instance;
    } catch (e) {
      debugPrint('PushNotificationService: Firebase not configured: $e');
      return;
    }
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _initLocalNotifications();
    await _requestPermissions();
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      await _onMessageOpenedApp(message);
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      // When app starts from a killed state via notification tap, give the app
      // a short moment to resume before opening the external browser.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      await _onMessageOpenedApp(initialMessage);
    }

    await _messaging.subscribeToTopic('song_updates');
    await _messaging.subscribeToTopic('app_updates');

    await _registerCurrentToken();
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) async {
      await _registerToken(token);
    });

    if (SupabaseService.isEnabled) {
      _authSub?.cancel();
      _authSub =
          SupabaseService.client.auth.onAuthStateChange.listen((state) async {
        if (state.event == AuthChangeEvent.signedIn ||
            state.event == AuthChangeEvent.tokenRefreshed) {
          await _registerCurrentToken();
        } else if (state.event == AuthChangeEvent.signedOut) {
          await unregisterCurrentTokenIfPossible();
        }
      });
    }

    _initialized = true;
    await _flushPendingUrlIfPossible();
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _authSub?.cancel();
    _tokenRefreshSub = null;
    _authSub = null;
    _initialized = false;
    if (_observerRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _observerRegistered = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_flushPendingUrlIfPossible());
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final androidImpl =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );

    final launchDetails =
        await _localNotifications.getNotificationAppLaunchDetails();
    final launchedFromNotification =
        launchDetails?.didNotificationLaunchApp ?? false;
    final launchResponse = launchDetails?.notificationResponse;
    if (launchedFromNotification && launchResponse != null) {
      debugPrint('Push launch details hit: ${launchResponse.payload}');
      await _onLocalNotificationTapped(launchResponse);
    }
  }

  Future<void> _requestPermissions() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  Future<void> _registerCurrentToken() async {
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    await _registerToken(token);
  }

  Future<void> _registerToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastFcmTokenKey, token);

    if (!SupabaseService.isEnabled) return;
    final user = SupabaseService.currentUser;
    if (user == null) return;

    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    final platform = defaultTargetPlatform.name;

    try {
      await SupabaseService.client.rpc(
        'register_push_token',
        params: {
          'p_token': token,
          'p_platform': platform,
          'p_app_version': appVersion,
        },
      );
    } catch (_) {
      // Keep app running even if token sync fails.
    }
  }

  Future<void> unregisterCurrentTokenIfPossible() async {
    if (!SupabaseService.isEnabled) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_lastFcmTokenKey);
    if (token == null || token.isEmpty) return;
    try {
      await SupabaseService.client.rpc(
        'unregister_push_token',
        params: {'p_token': token},
      );
    } catch (_) {
      // Ignore if no network / no session.
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final title =
        message.notification?.title ?? message.data['title']?.toString();
    final body = message.notification?.body ?? message.data['body']?.toString();
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    final payloadData = <String, dynamic>{...message.data};
    if (_isAppUpdateNotification(message, payloadData)) {
      payloadData.putIfAbsent('notification_type', () => 'app_update');
      payloadData.putIfAbsent('target_url', () => _appDownloadUrl);
    }

    await _localNotifications.show(
      message.hashCode,
      title ?? '2Block Music',
      body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(payloadData),
    );
  }

  Future<void> _onMessageOpenedApp(RemoteMessage message) async {
    final payloadData = <String, dynamic>{...message.data};
    debugPrint('Push tap (remote) data: $payloadData');
    final targetUrl = payloadData['target_url']?.toString().trim();
    if (targetUrl != null && targetUrl.isNotEmpty) {
      await _queueUrlOpen(targetUrl);
      return;
    }

    if (_isAppUpdateNotification(message, payloadData)) {
      await _queueUrlOpen(_appDownloadUrl);
    }
  }

  Future<void> _onLocalNotificationTapped(NotificationResponse response) async {
    final payload = response.payload;
    debugPrint('Push tap (local) payload: $payload');
    if (payload == null || payload.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return;

      final payloadData = Map<String, dynamic>.from(decoded);
      final targetUrl = payloadData['target_url']?.toString().trim();
      if (targetUrl != null && targetUrl.isNotEmpty) {
        await _queueUrlOpen(targetUrl);
        return;
      }

      if (_isAppUpdateNotification(null, payloadData)) {
        await _queueUrlOpen(_appDownloadUrl);
      }
    } catch (_) {
      // Ignore malformed payload.
    }
  }

  bool _isAppUpdateNotification(
      RemoteMessage? message, Map<String, dynamic> data) {
    final type = data['notification_type']?.toString().toLowerCase().trim();
    if (type == 'app_update') return true;

    final topic = data['topic']?.toString().toLowerCase().trim();
    if (topic == 'app_updates') return true;

    if (data.containsKey('version') && !data.containsKey('song_id')) {
      return true;
    }

    final title = message?.notification?.title?.toLowerCase().trim() ?? '';
    return title.contains('mise a jour') || title.contains('mise à jour');
  }

  Future<void> _queueUrlOpen(String url) async {
    if (url.trim().isEmpty) return;
    _pendingUrlToOpen = url.trim();
    _pendingUrlAttemptCount = 0;
    await _flushPendingUrlIfPossible();
  }

  Future<void> _flushPendingUrlIfPossible() async {
    if (_openingPendingUrl) return;
    final pending = _pendingUrlToOpen;
    if (pending == null || pending.isEmpty) return;

    final state = WidgetsBinding.instance.lifecycleState;
    if (state != AppLifecycleState.resumed) {
      debugPrint('URL en attente (etat app: $state): $pending');
      return;
    }

    _openingPendingUrl = true;
    try {
      // Let route/navigation settle after notification intent resume.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      final opened = await _openUrl(pending);
      if (opened) {
        _pendingUrlToOpen = null;
        _pendingUrlAttemptCount = 0;
      } else {
        _pendingUrlAttemptCount += 1;
        if (_pendingUrlAttemptCount >= 3) {
          _pendingUrlToOpen = null;
          _pendingUrlAttemptCount = 0;
        } else {
          _pendingUrlToOpen = pending;
          unawaited(
            Future<void>.delayed(
                const Duration(milliseconds: 900), _flushPendingUrlIfPossible),
          );
        }
      }
    } finally {
      _openingPendingUrl = false;
    }
  }

  Future<bool> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    debugPrint('Opening update URL: $uri');
    final launchedExternal =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launchedExternal) return true;

    final launchedDefault = await launchUrl(uri);
    if (launchedDefault) return true;

    return launchUrl(uri, mode: LaunchMode.inAppBrowserView);
  }
}

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/home_screen.dart';
import 'player/audio_handler.dart';
import 'config/supabase_config.dart';
import 'firebase_options.dart';
import 'services/announcement_notification_service.dart';
import 'services/download_service.dart';
import 'services/listening_sync_service.dart';
import 'services/push_notification_service.dart';

final AudioHandler audioHandler = AudioHandler();
const String _themeModePrefKey = 'app_theme_mode';
const String _appVersionLabel = 'v1.2.1';
const String _splashDeveloperLabel = 'Developper par THIOMBIANO TECH';
const String _thiombianoLogoAsset = 'assets/images/thiombiano-tech.png';
const String _cdBackdropAsset = 'assets/images/cd_lecture.jpg';
const String _headphonesBackdropAsset = 'assets/images/Homme_avec_casque.jpg';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  2Block Design Tokens
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _C {
  static const bg = Color(0xFF000000);
  static const v400 = Color(0xFFa78bfa);
  static const v500 = Color(0xFF8b5cf6);
  static const v600 = Color(0xFF7c3aed);
  static const p400 = Color(0xFFc084fc);
  static const p500 = Color(0xFFa855f7);
  static const gray500 = Color(0xFF737373);

  static const gradMain = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [v400, p400, p500],
  );
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  Permissions & Init
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
Future<void> _requestPermissions() async {
  if (kIsWeb) return;
  if (!Platform.isAndroid) return;
  final status = await Permission.notification.status;
  if (status.isDenied) await Permission.notification.request();
}

Future<ThemeMode> _loadInitialThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_themeModePrefKey);
  switch (raw) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

Future<void> _saveThemeMode(ThemeMode mode) async {
  final prefs = await SharedPreferences.getInstance();
  final value = switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
  await prefs.setString(_themeModePrefKey, value);
}

Future<void> _postLaunchInit() async {
  var pushReady = false;
  if (SupabaseConfig.isConfigured) {
    try {
      ListeningSyncService().startAutoSync();
      await ListeningSyncService()
          .syncPendingEvents()
          .timeout(const Duration(seconds: 6));
      await DownloadService()
          .syncPendingDownloadRegistrations()
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('main: sync skipped: $e');
    }
  }
  if (!kIsWeb) {
    try {
      await PushNotificationService()
          .initialize()
          .timeout(const Duration(seconds: 8));
      pushReady = PushNotificationService().isInitialized;
    } catch (e) {
      debugPrint('main: push skipped: $e');
    }
    try {
      await _requestPermissions();
    } catch (e) {
      debugPrint('main: permission skipped: $e');
    }
  }
  // Fallback announcements are useful only when Firebase push isn't active.
  if (SupabaseConfig.isConfigured && !pushReady) {
    try {
      await AnnouncementNotificationService()
          .start()
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('main: announcement skipped: $e');
    }
  }
}

Future<void> _bootstrapAppServices() async {
  if (SupabaseConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('main: Supabase init skipped: $e');
    }
  }

  if (!kIsWeb) {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: 8));
      }
    } catch (e) {
      debugPrint('main: Firebase skipped: $e');
    }
  }

  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.example.my_music.channel.audio.v2',
      androidNotificationChannelName: '2Block Music Playback',
      androidNotificationChannelDescription:
          'Lecteur audio 2Block en arriere-plan',
      androidNotificationIcon: 'drawable/ic_stat_2block',
      notificationColor: _C.v500,
      androidShowNotificationBadge: true,
      preloadArtwork: true,
      androidStopForegroundOnPause: true,
      androidNotificationOngoing: true,
    ).timeout(const Duration(seconds: 8));
  } catch (e) {
    debugPrint('main: audio background skipped: $e');
  }

  // Network-dependent tasks run in background so splash is never blocked.
  unawaited(_postLaunchInit());
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  main()
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  MyApp
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;
  late final Future<void> _startupFuture;

  @override
  void initState() {
    super.initState();
    _startupFuture = _bootstrapAppServices();
    _restoreThemeMode();
  }

  Future<void> _restoreThemeMode() async {
    final initialThemeMode = await _loadInitialThemeMode();
    if (!mounted) return;
    setState(() => _themeMode = initialThemeMode);
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    setState(() => _themeMode = mode);
    await _saveThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '2Block Music',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: _C.v500,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        canvasColor: Colors.white,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: _C.v500,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _C.bg,
        useMaterial3: true,
      ),
      themeMode: _themeMode,
      home: StartupGate(
        startupFuture: _startupFuture,
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode,
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  StartupGate
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class StartupGate extends StatefulWidget {
  final Future<void> startupFuture;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const StartupGate({
    Key? key,
    required this.startupFuture,
    required this.themeMode,
    required this.onThemeModeChanged,
  }) : super(key: key);

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late final Future<void> _readyFuture;

  @override
  void initState() {
    super.initState();
    _readyFuture = Future.wait<void>([
      widget.startupFuture.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('main: startup timeout, continue to home');
        },
      ),
      Future<void>.delayed(const Duration(milliseconds: 2000)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _readyFuture,
      builder: (context, snapshot) {
        final isReady = snapshot.connectionState == ConnectionState.done;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: !isReady
              ? const _WelcomeSplash(key: ValueKey('splash'))
              : HomeScreen(
                  key: const ValueKey('home'),
                  themeMode: widget.themeMode,
                  onThemeModeChanged: widget.onThemeModeChanged,
                ),
        );
      },
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  _WelcomeSplash  â€” Simple & Clean
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _WelcomeSplash extends StatefulWidget {
  const _WelcomeSplash({Key? key}) : super(key: key);

  @override
  State<_WelcomeSplash> createState() => _WelcomeSplashState();
}

class _WelcomeSplashState extends State<_WelcomeSplash>
    with TickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  late final AnimationController _dotsCtrl;

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));
    _entranceCtrl.forward();

    _dotsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _dotsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? _C.bg : const Color(0xFFF6F7FB),
      body: Stack(
        children: [
          // Blob haut-gauche
          Positioned(
            top: -130,
            left: -90,
            child: _blob(360, _C.v600.withOpacity(isDark ? 0.22 : 0.12)),
          ),
          // Blob bas-droit
          Positioned(
            bottom: -100,
            right: -80,
            child: _blob(280, _C.p500.withOpacity(isDark ? 0.14 : 0.10)),
          ),
          ..._buildBackgroundMusicIcons(isDark),

          // Contenu principal
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // â”€â”€ Logo dans cercle avec glow â”€â”€
                        const SizedBox(height: 8),
                        ShaderMask(
                          shaderCallback: (b) => _C.gradMain.createShader(b),
                          child: const Text(
                            '2BLOCK',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.9,
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        const Text(
                          'MUSIC',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _C.gray500,
                            letterSpacing: 1.8,
                            shadows: [
                              Shadow(
                                color: _C.v400,
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 46),

                        // â”€â”€ 3 dots loader â”€â”€
                        _buildDots(),

                        const SizedBox(height: 14),

                        const Text(
                          'Chargement...',
                          style: TextStyle(
                            fontSize: 12,
                            color: _C.gray500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Version
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fade,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSignature(),
                  const SizedBox(height: 6),
                  const Text(
                    _appVersionLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: _C.gray500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€ Logo â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildSignature() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFF151515),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
          ),
          child: Image.asset(
            _thiombianoLogoAsset,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.verified_rounded,
              size: 13,
              color: _C.gray500,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          _splashDeveloperLabel,
          style: TextStyle(
            fontSize: 10.8,
            color: _C.gray500.withOpacity(0.9),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildBackgroundMusicIcons(bool isDark) {
    final low = isDark ? 0.32 : 0.24;
    final high = isDark ? 0.52 : 0.44;
    return [
      Positioned(
        top: 18,
        left: -66,
        child: _fadedMusicPhoto(
          asset: _cdBackdropAsset,
          width: 244,
          height: 338,
          angle: -0.14,
          opacity: high,
          isDark: isDark,
        ),
      ),
      Positioned(
        bottom: -8,
        right: -70,
        child: _fadedMusicPhoto(
          asset: _headphonesBackdropAsset,
          width: 232,
          height: 324,
          angle: 0.15,
          opacity: high,
          isDark: isDark,
        ),
      ),
      Positioned(
        bottom: 106,
        left: 6,
        child: Opacity(
          opacity: low,
          child: Transform.rotate(
            angle: 0.08,
            child: const Icon(Icons.speaker_rounded, size: 82, color: _C.v400),
          ),
        ),
      ),
      Positioned(
        bottom: 74,
        right: 8,
        child: Opacity(
          opacity: high,
          child: Transform.rotate(
            angle: -0.16,
            child: const Icon(
              Icons.album_rounded,
              size: 78,
              color: _C.p400,
            ),
          ),
        ),
      ),
    ];
  }

  Widget _fadedMusicPhoto({
    required String asset,
    required double width,
    required double height,
    required double angle,
    required double opacity,
    required bool isDark,
  }) {
    return Opacity(
      opacity: opacity,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.28 : 0.16),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => const RadialGradient(
              center: Alignment.center,
              radius: 0.96,
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFFFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: [0.0, 0.82, 1.0],
            ).createShader(rect),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  asset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Color(0x22000000),
                    child: Center(
                      child: Icon(
                        Icons.music_note_rounded,
                        color: _C.gray500,
                        size: 34,
                      ),
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark
                          ? const [Color(0x12000000), Color(0x36000000)]
                          : const [Color(0x06FFFFFF), Color(0x1A000000)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Loading dots
  Widget _buildDots() {
    return AnimatedBuilder(
      animation: _dotsCtrl,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final t = (_dotsCtrl.value + i / 3) % 1.0;
            final scale = 0.5 + 0.5 * (t < 0.5 ? t * 2 : (1 - t) * 2);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: 0.3 + 0.7 * scale,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _C.v400,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // â”€â”€ Blob â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _blob(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
          child: const SizedBox.expand(),
        ),
      );
}

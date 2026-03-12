// file: screens/home_screen.dart
import 'dart:async';
import 'dart:ui';

import 'package:audio_service/audio_service.dart' show AudioService;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/song.dart';
import '../player/audio_handler.dart';
import '../repositories/song_repository.dart';
import '../services/auth_service.dart';
import '../services/download_service.dart';
import '../services/listening_sync_service.dart';
import '../services/push_notification_service.dart';
import '../services/support_service.dart';
import '../services/auth_callback_service.dart';
import '../services/supabase_service.dart';
import '../services/tutorial_service.dart';
import 'NowPlayingScreen.dart';
import 'auth_screen.dart';

enum LibrarySection { songs, downloaded, favorites }

enum SupportPromptAction { later, support }
enum SupportReturnAction { later, confirmed }

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
//  2Block Design Tokens
// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
class _C {
  static const bg = Color(0xFF000000);
  static const bg2 = Color(0xFF0A0A0F);
  static const v400 = Color(0xFFa78bfa);
  static const v500 = Color(0xFF8b5cf6);
  static const v600 = Color(0xFF7c3aed);
  static const p400 = Color(0xFFc084fc);
  static const p500 = Color(0xFFa855f7);
  static const p600 = Color(0xFF9333ea);
  static const white = Color(0xFFFFFFFF);
  static const gray400 = Color(0xFFa3a3a3);
  static const gray500 = Color(0xFF737373);

  static const gradMain = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [v400, p400, p500],
    stops: [0.0, 0.5, 1.0],
  );
  static const gradBtn = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [v600, p600],
  );
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
//  HomeScreen
// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
class HomeScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final Future<void>? startupFuture;

  const HomeScreen({
    super.key,
    this.themeMode = ThemeMode.system,
    this.onThemeModeChanged,
    this.startupFuture,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const String _favoritesKey = 'favorite_song_ids';
  static const String _supportPromptLaunchCountKey =
      'support_prompt_launch_count_v1';
  static const String _supportPromptLastShownKey =
      'support_prompt_last_shown_ms_v1';
  static const String _supportPromptSnoozeUntilKey =
      'support_prompt_snooze_until_ms_v1';
  static const String _supportPendingAmountKey = 'support_pending_amount_v1';
  static const String _supportPendingStartedAtKey =
      'support_pending_started_at_ms_v1';
  static const int _supportPromptMinLaunches = 2;
  static const int _supportPromptCooldownDays = 21;
  static const int _supportPromptSnoozeDays = 14;
  static const int _supportPromptSupportSnoozeDays = 45;
  static const int _supportPendingExpiryMinutes = 20;
  static const String _supportDonationNumber = '55041279';
  static const String _youtubeUrl =
      'https://youtube.com/@2blockofficiel?si=rzLQehwNQCcmS7qe';
  static const String _tiktokUrl = 'https://www.tiktok.com/@2blockofficiel';
  static const String _facebookUrl = 'https://bit.ly/4mfVSKK';
  static const bool _showSongViewsOnCards = true;

  final AudioHandler _handler = AudioHandler();
  final SongRepository _songRepository = SongRepository();
  final AuthService _authService = AuthService();
  final DownloadService _downloadService = DownloadService();
  final ListeningSyncService _syncService = ListeningSyncService();
  final SupportService _supportService = SupportService();
  final TutorialService _tutorialService = TutorialService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<String>? _authCallbackSubscription;
  StreamSubscription<bool>? _notificationClickSubscription;
  RealtimeChannel? _songViewsChannel;
  Timer? _songsReloadTimer;
  Timer? _connectivityTimer;
  bool _isSilentSongRefreshRunning = false;
  bool _isOpeningNowPlayingFromNotification = false;
  bool _isOffline = false;
  int _featuredIndex = 0;
  bool _homeTutorialScheduled = false;
  bool _isShowingSupportReturnPrompt = false;

  // Entrance animation
  late final AnimationController _entranceCtrl;
  late final Animation<double> _entranceFade;

  List<Song> songs = [];
  List<Song> filteredSongs = [];
  bool _isSearching = false;
  bool _isLoading = true;
  String _sortMode = 'recent';
  LibrarySection _activeSection = LibrarySection.songs;
  Set<int> _favoriteIds = <int>{};
  final Set<int> _downloadingIds = <int>{};
  final Map<int, double?> _downloadProgressBySongId = <int, double?>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _entranceFade =
        CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _entranceCtrl.forward();

    _handler.addListener(_onAudioHandlerChanged);
    _attachAuthListener();
    _attachAuthCallbackListener();
    _attachNotificationClickListener();
    unawaited(_attachSongViewsRealtime());
    _startConnectivityMonitor();

    widget.startupFuture?.whenComplete(() {
      if (!mounted) return;
      _attachAuthListener();
      _attachAuthCallbackListener();
      // Supabase becomes available only after bootstrap. Re-attach and refresh.
      unawaited(_attachSongViewsRealtime());
      unawaited(_refreshSongsSilently(force: true));
    });

    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadUserData();
    await _loadSongs();
    if (!_homeTutorialScheduled) {
      _homeTutorialScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _maybeShowHomeTutorial();
        await _maybeShowSupportPrompt();
      });
    }
  }

  void _onAudioHandlerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _startConnectivityMonitor() {
    unawaited(_refreshConnectivityStatus());
    _connectivityTimer?.cancel();
    _connectivityTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_refreshConnectivityStatus());
    });
  }

  Future<void> _refreshConnectivityStatus() async {
    final offline = await _syncService.isCurrentlyOffline();
    if (!mounted) return;
    if (_isOffline != offline) {
      setState(() => _isOffline = offline);
    }
  }

  Future<bool> _ensureOnline() async {
    final offline = await _syncService.isCurrentlyOffline();
    if (mounted && _isOffline != offline) {
      setState(() => _isOffline = offline);
    }
    if (offline) {
      _showSnack('V\u00e9rifie ta connexion Internet puis r\u00e9essaie.');
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _authCallbackSubscription?.cancel();
    _notificationClickSubscription?.cancel();
    if (_songViewsChannel != null) {
      unawaited(SupabaseService.client.removeChannel(_songViewsChannel!));
      _songViewsChannel = null;
    }
    _songsReloadTimer?.cancel();
    _connectivityTimer?.cancel();
    _handler.removeListener(_onAudioHandlerChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_maybePromptSupportReturn());
    }
  }

  void _attachAuthListener() {
    _authSubscription?.cancel();
    _authSubscription = null;

    if (!SupabaseService.isEnabled) return;

    _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen(
      (state) {
        if (!mounted) return;
        final e = state.event;
        if (e == AuthChangeEvent.signedIn ||
            e == AuthChangeEvent.signedOut ||
            e == AuthChangeEvent.tokenRefreshed ||
            e == AuthChangeEvent.userUpdated) {
          setState(() {});
        }
      },
      onError: (_) {},
    );
  }

  void _attachAuthCallbackListener() {
    _authCallbackSubscription?.cancel();
    _authCallbackSubscription = AuthCallbackService.instance.confirmationStream
        .listen((message) {
      if (!mounted) return;
      _showSnack(message);
      unawaited(_loadUserData());
      unawaited(_refreshSongsSilently(force: true));
    });
  }

  void _attachNotificationClickListener() {
    _notificationClickSubscription =
        AudioService.notificationClicked.listen((clicked) {
      if (!clicked || !mounted) return;
      unawaited(_openNowPlayingFromNotificationClick());
    });
  }

  Future<void> _openNowPlayingFromNotificationClick() async {
    if (!mounted || _isOpeningNowPlayingFromNotification) return;
    final song = _handler.currentSong;
    if (song == null) return;
    _isOpeningNowPlayingFromNotification = true;
    try {
      await Navigator.push(
        context,
        _slideRoute(NowPlayingScreen(song: song)),
      );
      await _loadUserData();
      if (!mounted) return;
      setState(() => _applyFiltersAndSort(_searchController.text));
    } finally {
      _isOpeningNowPlayingFromNotification = false;
    }
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ Data Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  Future<void> _maybeShowHomeTutorial({bool force = false}) async {
    if (!mounted) return;
    if (!force) {
      final alreadySeen = await _tutorialService.hasSeenHomeTutorial();
      if (alreadySeen) return;
    }
    if (!mounted) return;

    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: isLightTheme
                  ? Colors.white.withOpacity(0.96)
                  : const Color(0xFF0f0f17).withOpacity(0.95),
              border: Border.all(
                color: isLightTheme
                    ? const Color(0xFFE2E6F0)
                    : Colors.white.withOpacity(0.08),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tips_and_updates_rounded,
                            color: _C.v400),
                        const SizedBox(width: 8),
                        Text(
                          'Prise en main rapide',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isLightTheme
                                ? const Color(0xFF1A1F2D)
                                : _C.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _tutorialRow(
                      icon: Icons.play_circle_fill_rounded,
                      text: 'Le mini lecteur en bas ouvre le lecteur complet.',
                    ),
                    _tutorialRow(
                      icon: Icons.download_for_offline_rounded,
                      text:
                          'Pour télécharger un son, connecte-toi d\'abord à ton compte.',
                    ),
                    _tutorialRow(
                      icon: Icons.star_rounded,
                      text: 'Top 10 en haut pour voir les morceaux tendances.',
                    ),
                    _tutorialRow(
                      icon: Icons.swipe_rounded,
                      text: 'Glisse horizontalement pour changer de section.',
                    ),
                    _tutorialRow(
                      icon: Icons.tune_rounded,
                      text: 'Le menu a droite ouvre les reglages et options.',
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.v500,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Compris'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (!force) {
      await _tutorialService.markHomeTutorialSeen();
    }
  }

  Future<void> _maybeShowSupportPrompt() async {
    if (!mounted || songs.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final launchCount = (prefs.getInt(_supportPromptLaunchCountKey) ?? 0) + 1;
    await prefs.setInt(_supportPromptLaunchCountKey, launchCount);

    if (launchCount < _supportPromptMinLaunches) return;

    final now = DateTime.now();
    final snoozeUntilMs = prefs.getInt(_supportPromptSnoozeUntilKey);
    if (snoozeUntilMs != null) {
      final snoozeUntil = DateTime.fromMillisecondsSinceEpoch(snoozeUntilMs);
      if (now.isBefore(snoozeUntil)) return;
    }

    final lastShownMs = prefs.getInt(_supportPromptLastShownKey);
    if (lastShownMs != null) {
      final lastShown = DateTime.fromMillisecondsSinceEpoch(lastShownMs);
      if (now.difference(lastShown).inDays < _supportPromptCooldownDays) {
        return;
      }
    }

    await prefs.setInt(_supportPromptLastShownKey, now.millisecondsSinceEpoch);

    if (!mounted) return;
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final action = await showModalBottomSheet<SupportPromptAction>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: isLightTheme
                  ? Colors.white.withOpacity(0.97)
                  : const Color(0xFF0f0f17).withOpacity(0.95),
              border: Border.all(
                color: isLightTheme
                    ? const Color(0xFFE2E6F0)
                    : Colors.white.withOpacity(0.08),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: _C.gradMain,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Soutiens ton artiste',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: isLightTheme
                                      ? const Color(0xFF1A1F2D)
                                      : _C.white,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Un rappel discret, pas une obligation.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isLightTheme
                                      ? const Color(0xFF58617A)
                                      : _C.gray400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '\u{1F3B5} Si cette musique vous touche, soutenez l\u2019artiste.\n\nCr\u00e9er de la musique demande du temps, du travail et beaucoup de passion.\nVotre soutien, m\u00eame petit, aide l\u2019artiste \u00e0 continuer \u00e0 cr\u00e9er.\n\n\u{2764}\u{FE0F} Faites un geste et participez \u00e0 l\u2019aventure.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: isLightTheme
                            ? const Color(0xFF444E67)
                            : _C.gray400,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(
                              context,
                              SupportPromptAction.later,
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isLightTheme
                                  ? const Color(0xFF58617A)
                                  : _C.gray400,
                              side: BorderSide(
                                color: isLightTheme
                                    ? const Color(0xFFD4DAEA)
                                    : Colors.white.withOpacity(0.10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Plus tard'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(
                              context,
                              SupportPromptAction.support,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _C.v500,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Soutenir'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final snoozeDays = action == SupportPromptAction.support
        ? _supportPromptSupportSnoozeDays
        : _supportPromptSnoozeDays;
    await prefs.setInt(
      _supportPromptSnoozeUntilKey,
      DateTime.now()
          .add(Duration(days: snoozeDays))
          .millisecondsSinceEpoch,
    );

    if (action == SupportPromptAction.support) {
      if (mounted) {
        _showSnack('Merci pour ton soutien.');
      }
      await _showSupportArtistSheet();
    }
  }

  Future<void> _showSupportArtistSheet() async {
    if (!mounted) return;

    final amountController = TextEditingController();
    final amountFocusNode = FocusNode();
    final supportScrollController = ScrollController();
    final quickAmounts = <String>['500', '1000', '2000', '5000'];
    String? selectedAmount;
    final isLightTheme = Theme.of(context).brightness == Brightness.light;

    Future<void> scrollAmountFieldIntoView() async {
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (!supportScrollController.hasClients) return;
      final target = supportScrollController.position.maxScrollExtent;
      await supportScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }

    amountFocusNode.addListener(() {
      if (amountFocusNode.hasFocus) {
        unawaited(scrollAmountFieldIntoView());
      }
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final screenHeight = MediaQuery.of(context).size.height;
          final sheetHeight = screenHeight > 820 ? 560.0 : screenHeight * 0.62;
          final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: isLightTheme
                      ? Colors.white.withOpacity(0.97)
                      : const Color(0xFF0f0f17).withOpacity(0.95),
                  border: Border.all(
                    color: isLightTheme
                        ? const Color(0xFFE2E6F0)
                        : Colors.white.withOpacity(0.08),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: sheetHeight,
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            controller: supportScrollController,
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: EdgeInsets.fromLTRB(
                              18,
                              16,
                              18,
                              keyboardInset > 0 ? keyboardInset + 120 : 12,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: _C.gradMain,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.volunteer_activism_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Soutenir l\'artiste',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: isLightTheme
                                        ? const Color(0xFF1A1F2D)
                                        : _C.white,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Le geste compte, peu importe la somme.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isLightTheme
                                        ? const Color(0xFF58617A)
                                        : _C.gray400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Les fonds collectés servent aux maintenances et a garder l\'application stable.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: isLightTheme
                              ? const Color(0xFF444E67)
                              : _C.gray400,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: quickAmounts.map((amount) {
                          final isSelected = selectedAmount == amount;
                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                selectedAmount = amount;
                                amountController.text = amount;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                gradient: isSelected ? _C.gradBtn : null,
                                color: isSelected
                                    ? null
                                    : (isLightTheme
                                        ? const Color(0xFFF6F8FC)
                                        : Colors.white.withOpacity(0.05)),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.transparent
                                      : (isLightTheme
                                          ? const Color(0xFFE2E6F0)
                                          : Colors.white.withOpacity(0.08)),
                                ),
                              ),
                              child: Text(
                                '$amount FCFA',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? Colors.white
                                      : (isLightTheme
                                          ? const Color(0xFF1A1F2D)
                                          : _C.white),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: amountController,
                        focusNode: amountFocusNode,
                        keyboardType: TextInputType.number,
                        scrollPadding: const EdgeInsets.only(bottom: 220),
                        onTap: () {
                          unawaited(scrollAmountFieldIntoView());
                        },
                        onChanged: (_) {
                          setModalState(() {
                            selectedAmount = null;
                          });
                        },
                        style: TextStyle(
                          color:
                              isLightTheme ? const Color(0xFF1A1F2D) : _C.white,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Montant libre',
                          hintText: 'Ex: 1500',
                          suffixText: 'FCFA',
                          filled: true,
                          fillColor: isLightTheme
                              ? const Color(0xFFF6F8FC)
                              : Colors.white.withOpacity(0.05),
                          labelStyle: TextStyle(
                            color: isLightTheme
                                ? const Color(0xFF58617A)
                                : _C.gray400,
                          ),
                          hintStyle: TextStyle(
                            color: isLightTheme
                                ? const Color(0xFF8A90A3)
                                : _C.gray500,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isLightTheme
                                  ? const Color(0xFFE2E6F0)
                                  : Colors.white.withOpacity(0.08),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: _C.v500, width: 1.4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isLightTheme
                              ? const Color(0xFFF8F4FF)
                              : _C.v600.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isLightTheme
                                ? const Color(0xFFE8D8FF)
                                : _C.v500.withOpacity(0.22),
                          ),
                        ),
                        child: Text(
                          'Code USSD lance : *144*2*1*$_supportDonationNumber*Montant#',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: isLightTheme
                                ? const Color(0xFF5F4B7A)
                                : const Color(0xFFD7C3FF),
                          ),
                        ),
                      ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isLightTheme
                                        ? const Color(0xFF58617A)
                                        : _C.gray400,
                                    side: BorderSide(
                                      color: isLightTheme
                                          ? const Color(0xFFD4DAEA)
                                          : Colors.white.withOpacity(0.10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text('Fermer'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final amount = amountController.text.trim();
                                    final launched = await _launchSupportUssd(
                                      amount,
                                    );
                                    if (launched && context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _C.v500,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text('Lancer le soutien'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    amountFocusNode.dispose();
    supportScrollController.dispose();
    amountController.dispose();
  }

  Future<bool> _launchSupportUssd(String rawAmount) async {
    final amount = rawAmount.replaceAll(RegExp(r'[^0-9]'), '');
    if (amount.isEmpty) {
      await _clearPendingSupportDeclaration();
      _showSnack('Entre un montant avant de continuer');
      return false;
    }

    final code = '*144*2*1*$_supportDonationNumber*$amount#';
    final encodedCode = Uri.encodeComponent(code);
    final uri = Uri.parse('tel:$encodedCode');

    var opened = false;
    await _setPendingSupportDeclaration(int.parse(amount));
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}

    if (!opened) {
      await _clearPendingSupportDeclaration();
    }
    if (!opened && mounted) {
      _showSnack('Impossible de lancer le code USSD');
    }
    return opened;
  }

  Future<void> _setPendingSupportDeclaration(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_supportPendingAmountKey, amount);
    await prefs.setInt(
      _supportPendingStartedAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _clearPendingSupportDeclaration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_supportPendingAmountKey);
    await prefs.remove(_supportPendingStartedAtKey);
  }

  Future<void> _maybePromptSupportReturn() async {
    if (!mounted || _isShowingSupportReturnPrompt) return;

    final prefs = await SharedPreferences.getInstance();
    final amount = prefs.getInt(_supportPendingAmountKey);
    final startedAtMs = prefs.getInt(_supportPendingStartedAtKey);

    if (amount == null || startedAtMs == null) return;

    final startedAt = DateTime.fromMillisecondsSinceEpoch(startedAtMs);
    if (DateTime.now().difference(startedAt).inMinutes >
        _supportPendingExpiryMinutes) {
      await _clearPendingSupportDeclaration();
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    _isShowingSupportReturnPrompt = true;
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final action = await showModalBottomSheet<SupportReturnAction>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: isLightTheme
                  ? Colors.white.withOpacity(0.97)
                  : const Color(0xFF0f0f17).withOpacity(0.95),
              border: Border.all(
                color: isLightTheme
                    ? const Color(0xFFE2E6F0)
                    : Colors.white.withOpacity(0.08),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'As-tu effectué le soutien ?',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isLightTheme
                            ? const Color(0xFF1A1F2D)
                            : _C.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Montant lancé : $amount FCFA. Si ton opération a été validée, tu peux nous le signaler ici.',
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: isLightTheme
                            ? const Color(0xFF444E67)
                            : _C.gray400,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(
                              context,
                              SupportReturnAction.later,
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isLightTheme
                                  ? const Color(0xFF58617A)
                                  : _C.gray400,
                              side: BorderSide(
                                color: isLightTheme
                                    ? const Color(0xFFD4DAEA)
                                    : Colors.white.withOpacity(0.10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Plus tard'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(
                              context,
                              SupportReturnAction.confirmed,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _C.v500,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('J\'ai effectué le soutien'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    _isShowingSupportReturnPrompt = false;
    await _clearPendingSupportDeclaration();

    if (action == SupportReturnAction.confirmed) {
      await _registerSupportDeclaration(amount);
    }
  }

  Future<void> _registerSupportDeclaration(int amount) async {
    final displayName = _currentUserDisplayName();

    if (!_isLoggedIn) {
      if (!mounted) return;
      await _showSupportThankYouSheet(
        displayName: displayName,
        recorded: false,
      );
      return;
    }

    var recorded = false;
    try {
      await _supportService.registerSupportDeclaration(amountFcfa: amount);
      recorded = true;
    } catch (_) {
      if (mounted) {
        _showSnack('Impossible d\'enregistrer ton soutien pour le moment');
      }
    }

    if (!mounted) return;
    await _showSupportThankYouSheet(
      displayName: displayName,
      recorded: recorded,
    );
  }

  Future<void> _showSupportThankYouSheet({
    required String displayName,
    required bool recorded,
  }) async {
    if (!mounted) return;

    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: isLightTheme
                  ? Colors.white.withOpacity(0.97)
                  : const Color(0xFF0f0f17).withOpacity(0.95),
              border: Border.all(
                color: isLightTheme
                    ? const Color(0xFFE2E6F0)
                    : Colors.white.withOpacity(0.08),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: _C.gradMain,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Merci pour ton geste, $displayName',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isLightTheme
                            ? const Color(0xFF1A1F2D)
                            : _C.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      recorded
                          ? 'Notre reconnaissance est sincere. Ton soutien a bien ete note et il aide a faire les maintenances de l\'application.'
                          : 'Notre reconnaissance est sincere. Ton geste compte vraiment, meme si nous n\'avons pas pu l\'enregistrer en base cette fois.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: isLightTheme
                            ? const Color(0xFF444E67)
                            : _C.gray400,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.v500,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Fermer'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _currentUserDisplayName() {
    final user = _authService.currentUser;
    if (user == null) return 'ami 2Block';

    final meta = user.userMetadata ?? {};
    final fullName = meta['full_name']?.toString().trim() ?? '';
    if (fullName.isNotEmpty) return fullName;

    final email = user.email?.trim() ?? '';
    if (email.isNotEmpty) {
      return email.split('@').first;
    }

    return 'ami 2Block';
  }

  Widget _tutorialRow({
    required IconData icon,
    required String text,
  }) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              icon,
              size: 18,
              color: isLightTheme ? const Color(0xFF58617A) : _C.gray400,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: isLightTheme ? const Color(0xFF444E67) : _C.gray400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_favoritesKey) ?? [];
    if (!mounted) return;
    setState(() {
      _favoriteIds = raw.map(int.tryParse).whereType<int>().toSet();
    });
  }

  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);
    try {
      final data = await _songRepository.getSongs();
      if (!mounted) return;
      final featuredCount = data.length > 10 ? 10 : data.length;
      setState(() {
        songs = data;
        _isLoading = false;
        _featuredIndex =
            featuredCount == 0 ? 0 : (_featuredIndex % featuredCount);
        _applyFiltersAndSort(_searchController.text);
      });
      _handler.replaceSongs(data);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showSnack(
          'Impossible de rafra\u00eechir. V\u00e9rifie ta connexion puis r\u00e9essaie.');
    }
  }

  bool get _isLoggedIn => _authService.currentUser != null;

  Future<void> _openAuthScreen() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
    if (!mounted) return;
    final message = result?.trim();
    if (message != null && message.isNotEmpty) {
      _showSnack(message);
    }
  }

  Future<void> _playSong(Song song) async {
    if (SupabaseService.isEnabled && !song.isDownloaded) {
      if (!await _ensureOnline()) return;
      if (!_isLoggedIn) {
        if (!mounted) return;
        await _openAuthScreen();
        if (!mounted) return;
        if (!_isLoggedIn) {
          _showSnack('Connecte-toi pour t\u00e9l\u00e9charger ce son');
          return;
        }
      }
      await _downloadSong(song, autoPlayAfterDownload: true);
      return;
    }
    try {
      await _handler.playSong(song);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Lecture impossible');
    }
  }

  Future<void> _openNowPlaying(Song song) async {
    await Navigator.push(context, _slideRoute(NowPlayingScreen(song: song)));
    await _loadUserData();
    if (!mounted) return;
    setState(() => _applyFiltersAndSort(_searchController.text));
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ Sections Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  void _setSection(LibrarySection s) => setState(() {
        _activeSection = s;
        _applyFiltersAndSort(_searchController.text);
      });

  void _onHorizontalSwipe(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v.abs() < 120) return;
    if (v < 0 && _activeSection != LibrarySection.favorites) {
      _setSection(LibrarySection.values[_activeSection.index + 1]);
    } else if (v > 0 && _activeSection != LibrarySection.songs) {
      _setSection(LibrarySection.values[_activeSection.index - 1]);
    }
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ Filter / Sort Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  void _applyFiltersAndSort(String query) {
    final q = query.toLowerCase().trim();
    List<Song> source;
    switch (_activeSection) {
      case LibrarySection.favorites:
        source = songs.where((s) => _favoriteIds.contains(s.id)).toList();
        break;
      case LibrarySection.downloaded:
        source = songs.where((s) => s.isDownloaded).toList();
        break;
      default:
        source = List.from(songs);
    }
    List<Song> result = q.isEmpty
        ? source
        : source
            .where((s) =>
                s.title.toLowerCase().contains(q) ||
                s.artist.toLowerCase().contains(q))
            .toList();

    if (_sortMode == 'az') {
      result.sort((a, b) => a.title.compareTo(b.title));
    } else if (_sortMode == 'za') {
      result.sort((a, b) => b.title.compareTo(a.title));
    } else {
      result.sort(_compareSongsByRecent);
    }
    filteredSongs = result;
  }

  int _compareSongsByRecent(Song a, Song b) {
    final aDate = a.createdAt;
    final bDate = b.createdAt;

    if (aDate != null && bDate != null) {
      final byDate = bDate.compareTo(aDate);
      if (byDate != 0) return byDate;
    } else if (aDate == null && bDate != null) {
      return 1;
    } else if (aDate != null && bDate == null) {
      return -1;
    }

    return b.id.compareTo(a.id);
  }

  void _moveFeatured(int delta, int length) {
    if (length <= 0) return;
    setState(() {
      _featuredIndex = (_featuredIndex + delta) % length;
      if (_featuredIndex < 0) _featuredIndex += length;
    });
  }

  void _setSortMode(String m) => setState(() {
        _sortMode = m;
        _applyFiltersAndSort(_searchController.text);
      });

  String _sortLabel() {
    switch (_sortMode) {
      case 'az':
        return 'A-Z';
      case 'za':
        return 'Z-A';
      case 'recent':
        return 'Plus récent';
      default:
        return 'Plus récent';
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (_isSearching) {
        _searchFocusNode.requestFocus();
      } else {
        _searchController.clear();
        _searchFocusNode.unfocus();
        _applyFiltersAndSort('');
      }
    });
  }

  Future<void> _downloadSong(
    Song song, {
    bool autoPlayAfterDownload = false,
  }) async {
    if (song.isDownloaded) {
      if (autoPlayAfterDownload) {
        await _handler.playSong(song);
      } else {
        _showSnack('D\u00e9j\u00e0 t\u00e9l\u00e9charg\u00e9');
      }
      return;
    }
    if (_downloadingIds.contains(song.id)) return;
    if (!await _ensureOnline()) return;
    if (!_isLoggedIn) {
      if (!mounted) return;
      await _openAuthScreen();
      if (!mounted) return;
      if (!_isLoggedIn) {
        _showSnack('Connecte-toi pour t\u00e9l\u00e9charger');
        return;
      }
    }
    setState(() {
      _downloadingIds.add(song.id);
      _downloadProgressBySongId[song.id] = 0;
    });
    try {
      final localPath = await _downloadService.downloadSong(
        song,
        onProgress: (receivedBytes, totalBytes) {
          if (!mounted) return;
          final progress = totalBytes > 0
              ? (receivedBytes / totalBytes).clamp(0.0, 1.0)
              : null;
          setState(() {
            _downloadProgressBySongId[song.id] = progress;
          });
        },
      );
      if (!mounted) return;
      final downloadedSong = song.copyWith(localPath: localPath);
      setState(() {
        songs = songs
            .map((s) => s.id == song.id
                ? s.copyWith(localPath: localPath)
                : s)
            .toList();
        _applyFiltersAndSort(_searchController.text);
      });
      _handler.replaceSongs(songs);
      if (!mounted) return;
      if (autoPlayAfterDownload) {
        await _handler.playSong(downloadedSong);
      }
    } catch (_) {
      if (!mounted) return;
      _showSnack(
          'Action impossible pour le moment. V\u00e9rifie ta connexion puis r\u00e9essaie.');
    } finally {
      if (mounted) {
        setState(() {
          _downloadingIds.remove(song.id);
          _downloadProgressBySongId.remove(song.id);
        });
      }
    }
  }

  Future<void> _attachSongViewsRealtime() async {
    if (!SupabaseService.isEnabled || _songViewsChannel != null) return;

    _songViewsChannel = SupabaseService.client
        .channel('public:songs_mobile_views')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'songs',
          callback: (_) => _scheduleSilentSongsReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'songs',
          callback: (_) => _scheduleSilentSongsReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'songs',
          callback: (payload) => _applyRealtimeSong(payload.newRecord),
        )
        .subscribe();
  }

  void _scheduleSilentSongsReload([
    Duration delay = const Duration(milliseconds: 900),
  ]) {
    _songsReloadTimer?.cancel();
    _songsReloadTimer = Timer(delay, () {
      unawaited(_refreshSongsSilently(force: true));
    });
  }

  Future<void> _refreshSongsSilently({bool force = false}) async {
    if (!mounted) return;
    if (_isSilentSongRefreshRunning) return;
    if (_isLoading && !force) return;

    _isSilentSongRefreshRunning = true;
    try {
      final data = await _songRepository.getSongs();
      if (!mounted) return;
      if (!_hasSongsChanged(songs, data)) return;

      setState(() {
        songs = data;
        _applyFiltersAndSort(_searchController.text);
      });
      _handler.replaceSongs(data);
    } catch (_) {
      // Silent refresh fallback should never interrupt UI.
    } finally {
      _isSilentSongRefreshRunning = false;
    }
  }

  bool _hasSongsChanged(List<Song> current, List<Song> next) {
    if (current.length != next.length) return true;
    for (var i = 0; i < current.length; i++) {
      final a = current[i];
      final b = next[i];
      if (a.id != b.id ||
          a.title != b.title ||
          a.artist != b.artist ||
          a.cover != b.cover ||
          a.lyrics != b.lyrics ||
          a.storagePath != b.storagePath ||
          a.localPath != b.localPath ||
          a.createdAt != b.createdAt ||
          a.playsCount != b.playsCount) {
        return true;
      }
    }
    return false;
  }

  void _applyRealtimeSong(Map<String, dynamic> row) {
    if (!mounted) return;
    final songId = (row['id'] as num?)?.toInt();
    if (songId == null) return;

    final songIndex = songs.indexWhere((s) => s.id == songId);
    if (songIndex < 0) {
      _scheduleSilentSongsReload();
      return;
    }

    final isPublished = row['is_published'];
    if (isPublished is bool && !isPublished) {
      _scheduleSilentSongsReload();
      return;
    }

    final currentSong = songs[songIndex];
    final updatedSong = currentSong.copyWith(
      title: (row['title'] ?? currentSong.title).toString(),
      artist: (row['artist'] ?? currentSong.artist).toString(),
      cover: (row['cover_url'] ?? row['cover'] ?? currentSong.cover).toString(),
      lyrics: (row['lyrics'] ?? currentSong.lyrics).toString(),
      storagePath: (row['storage_path'] ?? currentSong.storagePath).toString(),
      createdAt: _tryParseDateTime(row['created_at']),
      playsCount:
          (row['plays_count'] as num?)?.toInt() ?? currentSong.playsCount,
    );

    final didChange = currentSong.title != updatedSong.title ||
        currentSong.artist != updatedSong.artist ||
        currentSong.cover != updatedSong.cover ||
        currentSong.lyrics != updatedSong.lyrics ||
        currentSong.storagePath != updatedSong.storagePath ||
        currentSong.createdAt != updatedSong.createdAt ||
        currentSong.playsCount != updatedSong.playsCount;

    if (!didChange) return;

    setState(() {
      final updated = List<Song>.from(songs);
      updated[songIndex] = updatedSong;
      songs = updated;
      _applyFiltersAndSort(_searchController.text);
    });
  }

  DateTime? _tryParseDateTime(dynamic raw) {
    if (raw == null) return null;
    final value = raw.toString();
    if (value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ Helpers Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  void _showSnack(String msg) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final topInset = MediaQuery.of(context).padding.top;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        msg,
        style: TextStyle(
          color: isLightTheme ? const Color(0xFF161616) : _C.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: isLightTheme ? Colors.white : const Color(0xFF1a1a2e),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(16, topInset + 12, 16, 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color:
              isLightTheme ? const Color(0xFFE7E9F0) : _C.v500.withOpacity(0.4),
        ),
      ),
      duration: const Duration(seconds: 2),
    ));
  }

  PageRoute _slideRoute(Widget page) => PageRouteBuilder(
        pageBuilder: (_, a, __) => page,
        transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 380),
      );

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  //  BUILD
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  @override
  Widget build(BuildContext context) {
    final currentSong = _handler.currentSong;
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isLightTheme ? Colors.white : _C.bg,
      extendBodyBehindAppBar: true,
      endDrawer: _buildDrawer(),
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _entranceFade,
        child: Stack(
          children: [
            // Ambient blobs
            _blob(
                offset: const Offset(-80, -40),
                size: 300,
                color: _C.v600.withOpacity(isLightTheme ? 0.11 : 0.25)),
            _blob(
                offset: const Offset(180, 300),
                size: 260,
                color: _C.p500.withOpacity(isLightTheme ? 0.08 : 0.15)),
            _blob(
                offset: const Offset(-60, 600),
                size: 220,
                color: _C.v500.withOpacity(isLightTheme ? 0.07 : 0.12)),

            Column(
              children: [
                const SizedBox(height: 100),

                _buildFeaturedTopBlock(),

                const SizedBox(height: 12),

                // Ã¢â€â‚¬Ã¢â€â‚¬ Section tabs Ã¢â€â‚¬Ã¢â€â‚¬
                _buildSectionTabs(),

                const SizedBox(height: 12),

                // Ã¢â€â‚¬Ã¢â€â‚¬ Filter bar Ã¢â€â‚¬Ã¢â€â‚¬
                _buildFilterBar(),

                const SizedBox(height: 8),

                // Ã¢â€â‚¬Ã¢â€â‚¬ Song list Ã¢â€â‚¬Ã¢â€â‚¬
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragEnd: _onHorizontalSwipe,
                    child: _isLoading
                        ? _buildLoadingState()
                        : _buildSongsListView(),
                  ),
                ),

                // Ã¢â€â‚¬Ã¢â€â‚¬ Mini player Ã¢â€â‚¬Ã¢â€â‚¬
                if (currentSong != null && !isKeyboardOpen)
                  StreamBuilder<Duration>(
                    stream: _handler.player.positionStream,
                    builder: (context, snap) {
                      final pos = snap.data ?? _handler.player.position;
                      final dur = _handler.player.duration ?? Duration.zero;
                      final progress = dur.inMilliseconds == 0
                          ? 0.0
                          : pos.inMilliseconds / dur.inMilliseconds;
                      return _buildMiniPlayer(currentSong, progress);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  //  AppBar
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  PreferredSizeWidget _buildAppBar() {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: isLightTheme
                ? Colors.white.withOpacity(0.75)
                : _C.bg.withOpacity(0.6),
          ),
        ),
      ),
      title: _isSearching
          ? TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (q) => setState(() => _applyFiltersAndSort(q)),
              style: TextStyle(
                fontSize: 17,
                color: isLightTheme ? const Color(0xFF161616) : _C.white,
              ),
              cursorColor: _C.v400,
              decoration: InputDecoration(
                hintText: 'Rechercher un son...',
                hintStyle: TextStyle(
                  fontSize: 17,
                  color: isLightTheme ? const Color(0xFF8A90A3) : _C.gray500,
                ),
                border: InputBorder.none,
              ),
            )
          : ShaderMask(
              shaderCallback: (b) => _C.gradMain.createShader(b),
              child: const Text(
                '2Block Music',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.05,
                ),
              ),
            ),
      leading: IconButton(
        icon: _appBarBtn(
          _isSearching ? Icons.close_rounded : Icons.search_rounded,
        ),
        onPressed: _toggleSearch,
      ),
      actions: [
        if (_isOffline)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _offlineBadge(),
          ),
        IconButton(
          icon: _appBarBtn(Icons.tune_rounded),
          onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _appBarBtn(IconData icon) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light
              ? const Color(0xFFF4F5FA)
              : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.light
                ? const Color(0xFFE7E9F0)
                : Colors.white.withOpacity(0.09),
          ),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).brightness == Brightness.light
              ? const Color(0xFF4A4E5C)
              : _C.gray400,
          size: 18,
        ),
      );

  Widget _offlineBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEDEB),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: const Color(0xFFFAC4BF)),
        ),
        child: const Row(
          children: [
            Icon(Icons.wifi_off_rounded, size: 14, color: Color(0xFFD84A3B)),
            SizedBox(width: 5),
            Text(
              'Hors ligne',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFFD84A3B),
              ),
            ),
          ],
        ),
      );

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  //  Section Tabs
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  Widget _buildSectionTabs() {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: isLightTheme
                  ? Colors.white.withOpacity(0.9)
                  : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isLightTheme
                    ? const Color(0xFFE7E9F0)
                    : Colors.white.withOpacity(0.07),
              ),
            ),
            child: Row(
              children: [
                _sectionTab(LibrarySection.songs, 'Nos songs'),
                _sectionTab(
                    LibrarySection.downloaded, 'T\u00e9l\u00e9charg\u00e9s'),
                _sectionTab(LibrarySection.favorites, 'Favoris'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Song> _featuredTopSongs() {
    final ranked = List<Song>.from(songs)
      ..sort((a, b) => b.playsCount.compareTo(a.playsCount));
    return ranked.take(10).toList();
  }

  Widget _buildFeaturedTopBlock() {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final topSongs = _featuredTopSongs();
    final hasSongs = topSongs.isNotEmpty;
    final activeIndex = hasSongs ? _featuredIndex % topSongs.length : 0;
    final currentSong = hasSongs ? topSongs[activeIndex] : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Top 10 du moment',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isLightTheme ? const Color(0xFF636A80) : _C.gray400,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 116,
            child: !hasSongs
                ? Container(
                    decoration: BoxDecoration(
                      color: isLightTheme
                          ? const Color(0xFFF6F8FD)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isLightTheme
                            ? const Color(0xFFE4E8F2)
                            : Colors.white.withOpacity(0.07),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Top 10 indisponible',
                        style: TextStyle(
                          fontSize: 12,
                          color: isLightTheme
                              ? const Color(0xFF7A8197)
                              : _C.gray500,
                        ),
                      ),
                    ),
                  )
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragEnd: (details) {
                      final velocity = details.primaryVelocity ?? 0;
                      if (velocity < -100) {
                        _moveFeatured(1, topSongs.length);
                      } else if (velocity > 100) {
                        _moveFeatured(-1, topSongs.length);
                      }
                    },
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 420),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.08, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        key: ValueKey(currentSong!.id),
                        decoration: BoxDecoration(
                          color: isLightTheme
                              ? const Color(0xFFF7F9FF)
                              : const Color(0xFF111322),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isLightTheme
                                ? const Color(0xFFE4E8F2)
                                : Colors.white.withOpacity(0.08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isLightTheme
                                  ? const Color(0x181E2230)
                                  : Colors.black.withOpacity(0.24),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: _buildSongArt(currentSong),
                            ),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.1),
                                      Colors.black.withOpacity(0.62),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: _C.gradBtn,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '#${activeIndex + 1}',
                                  style: const TextStyle(
                                    color: _C.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 10,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentSong.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    currentSong.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.86),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          if (hasSongs) ...[
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              children: List.generate(topSongs.length, (index) {
                final isActive = index == activeIndex;
                return GestureDetector(
                  onTap: () =>
                      _moveFeatured(index - activeIndex, topSongs.length),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    width: isActive ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive
                          ? (isLightTheme ? _C.v600 : _C.v400)
                          : (isLightTheme
                              ? const Color(0xFFC8CCDA)
                              : Colors.white.withOpacity(0.35)),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTab(LibrarySection section, String label) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final selected = _activeSection == section;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setSection(section),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: selected ? _C.gradBtn : null,
            color: selected
                ? null
                : isLightTheme
                    ? const Color(0xFFF3F4F9)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [BoxShadow(color: _C.p500.withOpacity(0.35), blurRadius: 12)]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? _C.white
                    : isLightTheme
                        ? const Color(0xFF4A4E5C)
                        : _C.gray500,
                letterSpacing: selected ? 0.02 : 0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  //  Filter Bar
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  Widget _buildFilterBar() {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final menuTextColor = isLightTheme ? const Color(0xFF1F2433) : _C.white;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${filteredSongs.length} son${filteredSongs.length > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isLightTheme ? const Color(0xFF6C7388) : _C.gray500,
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: _setSortMode,
            color: isLightTheme ? Colors.white : const Color(0xFF1a1a2e),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'recent',
                child: Text(
                  'Plus récent',
                  style: TextStyle(color: menuTextColor),
                ),
              ),
              PopupMenuItem(
                value: 'az',
                child: Text(
                  'A-Z',
                  style: TextStyle(color: menuTextColor),
                ),
              ),
              PopupMenuItem(
                value: 'za',
                child: Text(
                  'Z-A',
                  style: TextStyle(color: menuTextColor),
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isLightTheme
                    ? const Color(0xFFF5F6FB)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isLightTheme
                      ? const Color(0xFFE0E4EE)
                      : Colors.white.withOpacity(0.08),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.sort_rounded,
                    size: 15,
                    color: isLightTheme ? const Color(0xFF4A4E5C) : _C.gray400,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _sortLabel(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          isLightTheme ? const Color(0xFF4A4E5C) : _C.gray400,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: isLightTheme ? const Color(0xFF7A8197) : _C.gray500,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  //  Loading State
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  Widget _buildLoadingState() {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: const AlwaysStoppedAnimation(_C.v400),
              backgroundColor: isLightTheme
                  ? const Color(0xFFE8EBF5)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chargement...',
            style: TextStyle(
              color: isLightTheme ? const Color(0xFF6C7388) : _C.gray500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  //  Songs List
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  Widget _buildSongsListView() {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    if (filteredSongs.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 24).clamp(0, double.infinity),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isLightTheme
                          ? const Color(0xFFF2F4FA)
                          : Colors.white.withOpacity(0.04),
                      border: Border.all(
                        color: isLightTheme
                            ? const Color(0xFFE0E4EE)
                            : Colors.white.withOpacity(0.07),
                      ),
                    ),
                    child: Icon(
                      _isSearching
                          ? Icons.search_off_rounded
                          : Icons.music_off_rounded,
                      size: 36,
                      color:
                          isLightTheme ? const Color(0xFF8B92A8) : _C.gray500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isSearching
                        ? 'Aucun r\u00e9sultat'
                        : 'Aucun son disponible',
                    style: TextStyle(
                      fontSize: 16,
                      color:
                          isLightTheme ? const Color(0xFF4A4E5C) : _C.gray400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (!_isSearching) ...[
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _loadSongs,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: _C.gradBtn,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: _C.p500.withOpacity(0.3),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: const Text(
                          'Recharger',
                          style: TextStyle(
                            color: _C.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSongs,
      color: _C.v400,
      backgroundColor: isLightTheme ? Colors.white : _C.bg2,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        itemCount: filteredSongs.length,
        itemBuilder: (context, index) {
          final song = filteredSongs[index];
          final isCurrent = _handler.currentSong?.id == song.id;
          final isRemote = SupabaseService.isEnabled;
          final isDownloading = _downloadingIds.contains(song.id);
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 200 + (index * 15).clamp(0, 300)),
            curve: Curves.easeOutCubic,
            builder: (_, v, child) => Opacity(
              opacity: v,
              child: Transform.translate(
                  offset: Offset(0, (1 - v) * 14), child: child),
            ),
            child: _SongTile(
              song: song,
              index: index,
              isLightTheme: Theme.of(context).brightness == Brightness.light,
              isCurrent: isCurrent,
              isRemote: isRemote,
              isDownloading: isDownloading,
              playsCount: song.playsCount,
              showViews: _showSongViewsOnCards,
              downloadProgress: _downloadProgressBySongId[song.id],
              onTap: () => _playSong(song),
              onLongPress: () => _openNowPlaying(song),
              onDownload: () => _downloadSong(song),
              buildArt: (s) => _buildSongArt(s),
            ),
          );
        },
      ),
    );
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  //  Mini Player
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  Widget _buildMiniPlayer(Song song, double progress) {
    final isPlaying = _handler.player.playing;
    final isLightTheme = Theme.of(context).brightness == Brightness.light;

    return GestureDetector(
      onTap: () => _openNowPlaying(song),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: isLightTheme
                    ? Colors.white.withOpacity(0.94)
                    : const Color(0xFF0f0f1a).withOpacity(0.92),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isLightTheme
                      ? const Color(0xFFE4E8F2)
                      : _C.v500.withOpacity(0.25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isLightTheme
                        ? const Color(0x221E2230)
                        : _C.p500.withOpacity(0.25),
                    blurRadius: isLightTheme ? 18 : 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress bar
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(22)),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 2.5,
                      backgroundColor: isLightTheme
                          ? const Color(0xFFE8EBF5)
                          : Colors.white.withOpacity(0.08),
                      valueColor: const AlwaysStoppedAnimation(_C.v400),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                    child: Row(
                      children: [
                        // Thumbnail
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: _C.p500.withOpacity(0.25),
                                  blurRadius: 10)
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _buildSongArt(song),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Title / Artist
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _C.white,
                                  letterSpacing: -0.2,
                                ).copyWith(
                                  color: isLightTheme
                                      ? const Color(0xFF1B1F2A)
                                      : _C.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isLightTheme
                                      ? const Color(0xFF7A8197)
                                      : _C.gray400,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Controls
                        _miniCtrl(
                          Icons.skip_previous_rounded,
                          isLightTheme: isLightTheme,
                          onTap: () {
                            _handler.previousSong();
                            setState(() {});
                          },
                        ),
                        _MiniPlayBtn(
                          isPlaying: isPlaying,
                          onTap: () async {
                            if (isPlaying) {
                              await _handler.pause();
                            } else {
                              await _playSong(song);
                            }
                            setState(() {});
                          },
                        ),
                        _miniCtrl(
                          Icons.skip_next_rounded,
                          isLightTheme: isLightTheme,
                          onTap: () {
                            _handler.nextSong();
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniCtrl(
    IconData icon, {
    required bool isLightTheme,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 22,
            color: isLightTheme ? const Color(0xFF4A4E5C) : _C.gray400,
          ),
        ),
      );

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  //  Drawer
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Clair';
      case ThemeMode.dark:
        return 'Sombre';
      case ThemeMode.system:
        return 'Syst\u00e8me';
    }
  }

  void _handleThemeChange(ThemeMode mode) {
    if (widget.themeMode == mode) return;
    widget.onThemeModeChanged?.call(mode);
    setState(() {});
    _showSnack('Th\u00e8me ${_themeLabel(mode)} activ\u00e9');
  }

  Widget _themeChip({
    required ThemeMode mode,
    required IconData icon,
    required String label,
  }) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final selected = widget.themeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => _handleThemeChange(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? _C.v500.withOpacity(isLightTheme ? 0.18 : 0.26)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? _C.v500.withOpacity(isLightTheme ? 0.4 : 0.55)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? (isLightTheme ? const Color(0xFF3D2A78) : _C.white)
                    : (isLightTheme ? const Color(0xFF7A8197) : _C.gray400),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? (isLightTheme ? const Color(0xFF3D2A78) : _C.white)
                      : (isLightTheme ? const Color(0xFF7A8197) : _C.gray400),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeModeChooser() {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isLightTheme
            ? const Color(0xFFF4F6FB)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLightTheme
              ? const Color(0xFFE0E4EE)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          _themeChip(
            mode: ThemeMode.light,
            icon: Icons.light_mode_rounded,
            label: 'Clair',
          ),
          const SizedBox(width: 4),
          _themeChip(
            mode: ThemeMode.dark,
            icon: Icons.dark_mode_rounded,
            label: 'Sombre',
          ),
          const SizedBox(width: 4),
          _themeChip(
            mode: ThemeMode.system,
            icon: Icons.settings_suggest_rounded,
            label: 'Syst\u00e8me',
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final email = _authService.currentUser?.email ?? 'Connecte toi';
    return Drawer(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: isLightTheme
                  ? Colors.white.withOpacity(0.96)
                  : const Color(0xFF0a0a14).withOpacity(0.96),
              border: Border(
                left: BorderSide(
                  color: isLightTheme
                      ? const Color(0xFFE3E7F1)
                      : _C.v500.withOpacity(0.2),
                ),
              ),
            ),
            child: SafeArea(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                builder: (_, v, child) => Opacity(
                  opacity: v,
                  child: Transform.translate(
                      offset: Offset((1 - v) * 28, 0), child: child),
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _C.v600.withOpacity(isLightTheme ? 0.12 : 0.2),
                            Colors.transparent,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border(
                            bottom: BorderSide(
                                color: isLightTheme
                                    ? const Color(0xFFE3E7F1)
                                    : Colors.white.withOpacity(0.06))),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShaderMask(
                            shaderCallback: (b) => _C.gradMain.createShader(b),
                            child: const Text(
                              '2Block Music',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.05,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            email,
                            style: TextStyle(
                              fontSize: 12,
                              color: isLightTheme
                                  ? const Color(0xFF7A8197)
                                  : _C.gray500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        children: [
                          _drawerTile(
                            icon: Icons.account_circle_outlined,
                            label: 'Profil',
                            onTap: () {
                              Navigator.pop(context);
                              _showProfileDialog(context);
                            },
                          ),
                          if (!_isLoggedIn)
                            _drawerTile(
                              icon: Icons.login_rounded,
                              label: 'Se connecter',
                              onTap: () async {
                                Navigator.pop(context);
                                await _handleAccountAction();
                              },
                            ),
                          const SizedBox(height: 8),
                          _drawerDivider('Theme'),
                          _buildThemeModeChooser(),
                          const SizedBox(height: 8),
                          _drawerDivider('R\u00e9seaux sociaux'),
                          _drawerTile(
                            icon: Icons.facebook_rounded,
                            label: 'Facebook',
                            iconColor: const Color(0xFF1877F2),
                            onTap: () {
                              Navigator.pop(context);
                              _openExternalLink(_facebookUrl);
                            },
                          ),
                          _drawerTile(
                            icon: FontAwesomeIcons.tiktok,
                            label: 'TikTok',
                            onTap: () {
                              Navigator.pop(context);
                              _openExternalLink(_tiktokUrl);
                            },
                          ),
                          _drawerTile(
                            icon: Icons.smart_display_rounded,
                            label: 'YouTube',
                            iconColor: Colors.red,
                            onTap: () {
                              Navigator.pop(context);
                              _openExternalLink(_youtubeUrl);
                            },
                          ),
                          const SizedBox(height: 8),
                          _drawerDivider('App'),
                          _drawerTile(
                            icon: Icons.volunteer_activism_rounded,
                            label: 'Soutenir l\'artiste',
                            iconColor: _C.v400,
                            onTap: () async {
                              Navigator.pop(context);
                              await _showSupportArtistSheet();
                            },
                          ),
                          _drawerTile(
                            icon: Icons.privacy_tip_outlined,
                            label: 'Politique de confidentialité',
                            onTap: () {
                              Navigator.pop(context);
                              _showPrivacyPolicyDialog(context);
                            },
                          ),
                          _drawerTile(
                            icon: Icons.info_outline_rounded,
                            label: '\u00c0 propos',
                            onTap: () {
                              Navigator.pop(context);
                              _showAboutDialog(context);
                            },
                          ),
                        ],
                      ),
                    ),

                    if (_isLoggedIn)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: _drawerTile(
                          icon: Icons.logout_rounded,
                          label: 'Se d\u00e9connecter',
                          iconColor: Colors.redAccent,
                          onTap: () async {
                            Navigator.pop(context);
                            await _handleAccountAction();
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _drawerDivider(String label) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isLightTheme ? const Color(0xFF8A90A3) : _C.gray500,
          letterSpacing: 0.14,
        ),
      ),
    );
  }

  Widget _drawerTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = _C.gray400,
  }) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isLightTheme ? const Color(0xFFF7F8FC) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border:
              isLightTheme ? Border.all(color: const Color(0xFFE6EAF3)) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: iconColor.withOpacity(0.2)),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isLightTheme ? const Color(0xFF1F2433) : _C.white,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: isLightTheme ? const Color(0xFF8A90A3) : _C.gray500,
            ),
          ],
        ),
      ),
    );
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  //  Profile Dialog
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  void _showProfileDialog(BuildContext context) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final user = _authService.currentUser;
    if (user == null) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: isLightTheme ? Colors.white : _C.bg2,
          title: Text(
            'Profil',
            style: TextStyle(
              color: isLightTheme ? const Color(0xFF1F2433) : _C.white,
            ),
          ),
          content: Text(
            'Aucun compte connect\u00e9',
            style: TextStyle(
              color: isLightTheme ? const Color(0xFF6C7388) : _C.gray400,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer', style: TextStyle(color: _C.v400)),
            ),
          ],
        ),
      );
      return;
    }

    final meta = user.userMetadata ?? {};
    final fullName = (meta['full_name']?.toString().trim().isNotEmpty ?? false)
        ? meta['full_name'].toString()
        : (user.email?.split('@').first ?? 'Utilisateur');
    final email = user.email ?? '--';
    final created = user.createdAt.toString();
    final createdLabel =
        created.length >= 10 ? created.substring(0, 10) : created;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProfileSheet(
        fullName: fullName,
        email: email,
        createdAt: createdLabel,
      ),
    );
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  //  About Dialog
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  void _showAboutDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AboutSheet(),
    );
  }

  void _showPrivacyPolicyDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PrivacyPolicySheet(),
    );
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  //  Account Action
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  Future<void> _handleAccountAction() async {
    if (_isLoggedIn) {
      final offline = await _syncService.isCurrentlyOffline();
      if (!offline) {
        try {
          await _syncService.syncPendingEvents();
          await _downloadService.syncPendingDownloadRegistrations();
        } catch (_) {}
      }
      await PushNotificationService().unregisterCurrentTokenIfPossible();
      await _authService.signOut();
      await _handler.pause();
      _handler.currentSong = null;
      await _downloadService.resetLocalAppData();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_favoritesKey);
      _favoriteIds.clear();
      _searchController.clear();
      if (!mounted) return;
      _showSnack(offline ? 'Déconnexion réussie.' : 'Déconnexion réussie.');
      if (_activeSection == LibrarySection.downloaded) {
        _activeSection = LibrarySection.songs;
      }
      await _loadSongs();
      setState(() {});
      return;
    }

    if (!await _ensureOnline()) return;
    if (!mounted) return;
    await _openAuthScreen();
    if (!mounted) return;
    if (!_isLoggedIn) {
      _showSnack('V\u00e9rifie ta connexion Internet puis r\u00e9essaie.');
      return;
    }
    await _syncService.syncPendingEvents();
    await _downloadService.syncPendingDownloadRegistrations();
    await _loadSongs();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openExternalLink(String url) async {
    Uri uri = Uri.parse(url.trim());
    if (!uri.hasScheme) uri = Uri.parse('https://${url.trim()}');
    bool opened = false;
    try {
      if (await canLaunchUrl(uri)) opened = await launchUrl(uri);
      if (!opened) {
        opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
    } catch (_) {}
    if (!opened && mounted) _showSnack('Impossible d\'ouvrir le lien');
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  //  Misc helpers
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  Widget _blob(
          {required Offset offset,
          required double size,
          required Color color}) =>
      Positioned(
        left: offset.dx,
        top: offset.dy,
        child: IgnorePointer(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );

  Widget _buildSongArt(Song song) {
    if (song.cover.startsWith('http://') || song.cover.startsWith('https://')) {
      return Image.network(song.cover,
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallbackArt());
    }
    return Image.asset('assets/images/${song.cover}',
        fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallbackArt());
  }

  Widget _fallbackArt() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1a0533), Color(0xFF2d1b69)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
            child: Icon(Icons.music_note_rounded, color: _C.v400, size: 24)),
      );
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
//  Song Tile Widget
// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
class _SongTile extends StatelessWidget {
  final Song song;
  final int index;
  final bool isLightTheme;
  final bool isCurrent;
  final bool isRemote;
  final bool isDownloading;
  final int playsCount;
  final bool showViews;
  final double? downloadProgress;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDownload;
  final Widget Function(Song) buildArt;

  const _SongTile({
    required this.song,
    required this.index,
    required this.isLightTheme,
    required this.isCurrent,
    required this.isRemote,
    required this.isDownloading,
    required this.playsCount,
    this.showViews = false,
    required this.downloadProgress,
    required this.onTap,
    required this.onLongPress,
    required this.onDownload,
    required this.buildArt,
  });

  String _formatViews(int value) {
    if (value >= 1000000) {
      final n = value / 1000000;
      return '${n.toStringAsFixed(n >= 10 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      final n = value / 1000;
      return '${n.toStringAsFixed(n >= 10 ? 0 : 1)}K';
    }
    return value.toString();
  }

  String _formatSongAge(DateTime? createdAt) {
    if (createdAt == null) return '';

    final now = DateTime.now().toLocal();
    var totalSeconds = now.difference(createdAt.toLocal()).inSeconds;
    if (totalSeconds < 0) totalSeconds = 0;

    if (totalSeconds < 60) {
      final count = totalSeconds == 0 ? 1 : totalSeconds;
      return '$count s';
    }

    final totalMinutes = totalSeconds ~/ 60;
    if (totalMinutes < 60) {
      return '$totalMinutes mn';
    }

    final totalHours = totalMinutes ~/ 60;
    if (totalHours < 24) {
      return '$totalHours h';
    }

    var days = totalHours ~/ 24;
    if (days < 0) days = 0;

    if (days < 7) {
      final count = days == 0 ? 1 : days;
      return '$count j';
    }
    if (days < 30) {
      final count = (days / 7).floor().clamp(1, 4);
      return '$count sem';
    }
    if (days < 365) {
      final count = (days / 30).floor().clamp(1, 12);
      return '$count mois';
    }

    final count = (days / 365).floor().clamp(1, 1000);
    return '$count an';
  }

  @override
  Widget build(BuildContext context) {
    final songAgeLabel = _formatSongAge(song.createdAt);
    final metaParts = <String>[
      if (showViews) '${_formatViews(playsCount)} vues',
      if (songAgeLabel.isNotEmpty) songAgeLabel,
    ];
    final metaText = metaParts.join(' • ');

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isCurrent
              ? _C.v600.withOpacity(isLightTheme ? 0.14 : 0.18)
              : (isLightTheme
                  ? const Color(0xFFF8F9FD)
                  : Colors.white.withOpacity(0.04)),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isCurrent
                ? _C.v500.withOpacity(isLightTheme ? 0.45 : 0.5)
                : (isLightTheme
                    ? const Color(0xFFE4E8F2)
                    : Colors.white.withOpacity(0.06)),
          ),
          boxShadow: isCurrent
              ? [
                  BoxShadow(
                      color: _C.p500.withOpacity(0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 4))
                ]
              : isLightTheme
                  ? [
                      const BoxShadow(
                        color: Color(0x1A1E2230),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              // Index
              SizedBox(
                width: 30,
                child: Text(
                  '${index + 1}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isCurrent
                        ? _C.v500
                        : (isLightTheme ? const Color(0xFF8A90A3) : _C.gray500),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Art
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: buildArt(song),
                ),
              ),
              const SizedBox(width: 14),

              // Title / Artist
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isCurrent
                                  ? _C.v500
                                  : (isLightTheme
                                      ? const Color(0xFF1F2433)
                                      : _C.white),
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        if (isRemote && !song.isDownloaded)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: _C.gradBtn,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                  color: _C.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            isLightTheme ? const Color(0xFF7A8197) : _C.gray500,
                      ),
                    ),
                    if (metaText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        metaText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isLightTheme
                              ? const Color(0xFF8A90A3)
                              : _C.gray500,
                          letterSpacing: 0.05,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Download (hidden once downloaded)
              if (isRemote && (isDownloading || !song.isDownloaded))
                SizedBox(
                  width: 42,
                  height: 42,
                  child: isDownloading
                      ? Container(
                          decoration: BoxDecoration(
                            color: isLightTheme
                                ? const Color(0xFFF2F4FA)
                                : Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isLightTheme
                                  ? const Color(0xFFE2E6F0)
                                  : Colors.white.withOpacity(0.08),
                            ),
                          ),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: downloadProgress,
                                    strokeWidth: 2.4,
                                    valueColor:
                                        const AlwaysStoppedAnimation(_C.v400),
                                    backgroundColor: isLightTheme
                                        ? const Color(0xFFDCE2F0)
                                        : Colors.white.withOpacity(0.10),
                                  ),
                                  if (downloadProgress != null)
                                    Text(
                                      '${(downloadProgress! * 100).round()}%',
                                      style: TextStyle(
                                        fontSize: 7,
                                        fontWeight: FontWeight.w700,
                                        color: isLightTheme
                                            ? const Color(0xFF4E566C)
                                            : _C.gray400,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : GestureDetector(
                          onTap: song.isDownloaded ? null : onDownload,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isLightTheme
                                  ? const Color(0xFFF2F4FA)
                                  : Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isLightTheme
                                    ? const Color(0xFFE2E6F0)
                                    : Colors.white.withOpacity(0.08),
                              ),
                            ),
                            child: Icon(
                              Icons.download_rounded,
                              size: 22,
                              color: isLightTheme
                                  ? const Color(0xFF6F768B)
                                  : _C.gray400,
                            ),
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
//  Mini Play Button
// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
class _MiniPlayBtn extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;
  const _MiniPlayBtn({required this.isPlaying, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _C.gradBtn,
          boxShadow: [
            BoxShadow(
              color: _C.p500.withOpacity(isPlaying ? 0.5 : 0.25),
              blurRadius: isPlaying ? 16 : 8,
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            key: ValueKey(isPlaying),
            size: 22,
            color: _C.white,
          ),
        ),
      ),
    );
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
//  Profile Sheet
// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
class _ProfileSheet extends StatelessWidget {
  final String fullName;
  final String email;
  final String createdAt;
  const _ProfileSheet(
      {required this.fullName, required this.email, required this.createdAt});

  @override
  Widget build(BuildContext context) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: isLightTheme
                    ? Colors.white.withOpacity(0.97)
                    : const Color(0xFF0f0f1a).withOpacity(0.96),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isLightTheme
                      ? const Color(0xFFE4E8F2)
                      : _C.v500.withOpacity(0.2),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isLightTheme
                          ? const Color(0xFFD0D5E3)
                          : _C.gray500.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Avatar
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _C.gradBtn,
                      boxShadow: [
                        BoxShadow(
                            color: _C.p500.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 6))
                      ],
                    ),
                    child: Center(
                      child: Text(
                        fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: _C.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(fullName,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isLightTheme
                              ? const Color(0xFF1F2433)
                              : _C.white)),
                  const SizedBox(height: 4),
                  Text(email,
                      style: TextStyle(
                          fontSize: 13,
                          color: isLightTheme
                              ? const Color(0xFF7A8197)
                              : _C.gray500)),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isLightTheme
                            ? const Color(0xFFF6F8FC)
                            : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isLightTheme
                              ? const Color(0xFFE4E8F2)
                              : Colors.white.withOpacity(0.07),
                        ),
                      ),
                      child: Column(
                        children: [
                          _infoRow(Icons.calendar_month_rounded,
                              'Compte cr\u00e9\u00e9 le', createdAt,
                              isLightTheme: isLightTheme),
                          Divider(
                              height: 1,
                              color: isLightTheme
                                  ? const Color(0xFFE4E8F2)
                                  : Colors.white.withOpacity(0.06)),
                          _infoRow(
                              Icons.verified_user_rounded, 'Statut', 'Actif',
                              isLightTheme: isLightTheme),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: _C.gradBtn,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                                color: _C.p500.withOpacity(0.3), blurRadius: 16)
                          ],
                        ),
                        child: const Center(
                          child: Text('Fermer',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _C.white,
                                  fontSize: 15)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    required bool isLightTheme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _C.v600.withOpacity(0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: _C.v400),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: isLightTheme
                            ? const Color(0xFF8A90A3)
                            : _C.gray500)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color:
                            isLightTheme ? const Color(0xFF1F2433) : _C.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
//  About Sheet
// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
class _AboutSheet extends StatelessWidget {
  const _AboutSheet();

  @override
  Widget build(BuildContext context) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: isLightTheme
                    ? Colors.white.withOpacity(0.97)
                    : const Color(0xFF0f0f1a).withOpacity(0.96),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isLightTheme
                      ? const Color(0xFFE4E8F2)
                      : _C.v500.withOpacity(0.2),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isLightTheme
                          ? const Color(0xFFD0D5E3)
                          : _C.gray500.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _C.gradBtn,
                      boxShadow: [
                        BoxShadow(
                            color: _C.p500.withOpacity(0.4), blurRadius: 24)
                      ],
                    ),
                    child: const Icon(Icons.library_music_rounded,
                        color: _C.white, size: 36),
                  ),
                  const SizedBox(height: 14),
                  ShaderMask(
                    shaderCallback: (b) => _C.gradMain.createShader(b),
                    child: const Text('2Block Music',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                  ),
                  const SizedBox(height: 4),
                  Text('Version 1.3.1',
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            isLightTheme ? const Color(0xFF7A8197) : _C.gray500,
                      )),
                  const SizedBox(height: 4),
                  Text(
                    'Développé par THIOMBIANO TECH',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          isLightTheme ? const Color(0xFF6A7288) : _C.gray400,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isLightTheme
                            ? const Color(0xFFF6F8FC)
                            : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isLightTheme
                              ? const Color(0xFFE4E8F2)
                              : Colors.white.withOpacity(0.07),
                        ),
                      ),
                      child: Text(
                        'Application mobile 2Block pour \u00e9couter vos morceaux t\u00e9l\u00e9charg\u00e9s, '
                        'avec lecture hors ligne, favoris, paroles et exp\u00e9rience audio optimis\u00e9e.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.55,
                          color: isLightTheme
                              ? const Color(0xFF4A4E5C)
                              : _C.gray400,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: _C.gradBtn,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                                color: _C.p500.withOpacity(0.3), blurRadius: 16)
                          ],
                        ),
                        child: const Center(
                          child: Text('Fermer',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _C.white,
                                  fontSize: 15)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyPolicySheet extends StatelessWidget {
  const _PrivacyPolicySheet();

  @override
  Widget build(BuildContext context) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: isLightTheme
                    ? Colors.white.withOpacity(0.97)
                    : const Color(0xFF0f0f1a).withOpacity(0.96),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isLightTheme
                      ? const Color(0xFFE4E8F2)
                      : _C.v500.withOpacity(0.2),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isLightTheme
                          ? const Color(0xFFD0D5E3)
                          : _C.gray500.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Politique de confidentialité',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: isLightTheme ? const Color(0xFF1F2433) : _C.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isLightTheme
                            ? const Color(0xFFF6F8FC)
                            : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isLightTheme
                              ? const Color(0xFFE4E8F2)
                              : Colors.white.withOpacity(0.07),
                        ),
                      ),
                      child: Text(
                        '2Block Music collecte uniquement les données nécessaires '
                        'au fonctionnement de l\'application : compte utilisateur, '
                        'téléchargements, écoutes et notifications.\n\n'
                        'Tes données ne sont pas revendues. Elles servent à '
                        'améliorer ton expérience, synchroniser ton compte et '
                        'proposer les fonctionnalités audio.\n\n'
                        'Tu peux supprimer tes données locales en te déconnectant. '
                        'Pour toute demande, contacte l\'équipe 2Block.',
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.55,
                          color: isLightTheme
                              ? const Color(0xFF4A4E5C)
                              : _C.gray400,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: _C.gradBtn,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: _C.p500.withOpacity(0.3),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'Fermer',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _C.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

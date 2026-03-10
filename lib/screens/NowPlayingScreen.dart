import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/song.dart';
import '../models/song_social.dart';
import '../player/audio_handler.dart';
import '../services/auth_service.dart';
import '../services/song_social_service.dart';
import 'auth_screen.dart';

//  2Block Design Tokens
class _C {
  static const bg = Color(0xFF000000);
  static const v400 = Color(0xFFa78bfa);
  static const v500 = Color(0xFF8b5cf6);
  static const v600 = Color(0xFF7c3aed);
  static const p500 = Color(0xFFa855f7);
  static const p600 = Color(0xFF9333ea);
  static const white = Color(0xFFFFFFFF);
  static const gray400 = Color(0xFFa3a3a3);
  static const gray500 = Color(0xFF737373);

  static const gradBtn = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [v600, p600],
  );
}

enum _NowPlayingAction {
  equalizer,
  details,
  share,
  reportIssue,
}

enum _IssueContactChannel {
  email,
  whatsapp,
}

class _LrcLine {
  final Duration start;
  final String text;

  const _LrcLine({
    required this.start,
    required this.text,
  });
}

//  Main Screen
class NowPlayingScreen extends StatefulWidget {
  final Song song;
  const NowPlayingScreen({super.key, required this.song});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with TickerProviderStateMixin {
  static const String _favoritesKey = 'favorite_song_ids';
  static const String _shareWebsiteUrl = 'https://2block-web-ctth.vercel.app/';
  static const String _supportEmail = 'thzizou7@gmail.com';
  static const String _supportWhatsApp = '22655041279';

  final AudioHandler _handler = AudioHandler();
  final AuthService _authService = AuthService();
  final SongSocialService _songSocialService = SongSocialService();
  final PageController _pageController = PageController();
  final ScrollController _lyricsScrollController = ScrollController();
  final Map<int, GlobalKey> _lyricLineKeys = <int, GlobalKey>{};
  Set<int> _favoriteIds = <int>{};
  SongSocialStats? _socialStats;
  int? _socialSongId;
  int? _commentsPreviewSongId;
  bool _commentsPreviewLoading = false;
  List<SongComment> _commentPreviewComments = <SongComment>[];
  int _pageIndex = 0;
  int _lastAutoScrolledLyricIndex = -1;
  int? _lyricsSongId;
  DateTime? _manualLyricsScrollUntil;
  double _playbackSpeed = 1.0;
  double _playbackPitch = 1.0;
  bool _pitchControlSupported = true;

  // CD spin
  late final AnimationController _spinCtrl;
  // CD shine sweep
  late final AnimationController _shineCtrl;
  // Entrance fade
  late final AnimationController _entranceCtrl;
  late final Animation<double> _entranceFade;
  late final Animation<Offset> _entranceSlide;
  // Play button pulse
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  StreamSubscription<PlayerState>? _playerStateSub;

  @override
  void initState() {
    super.initState();
    _playbackSpeed = _handler.player.speed;
    try {
      _playbackPitch = _handler.player.pitch;
    } catch (_) {
      _playbackPitch = 1.0;
      _pitchControlSupported = false;
    }

    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
    _shineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _entranceFade =
        CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _entranceSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _entranceCtrl.forward();
    unawaited(_loadFavorites());
    unawaited(_loadSongSocialStats(widget.song.id));
    unawaited(_loadCommentPreview(widget.song.id));

    _playerStateSub = _handler.player.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.playing) {
        if (!_spinCtrl.isAnimating) _spinCtrl.repeat();
      } else {
        _spinCtrl.stop();
      }
    });

    if (_handler.player.playing) _spinCtrl.repeat();

    if (_handler.currentSong?.id != widget.song.id) {
      _handler.playSong(widget.song).catchError((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lecture impossible pour ce morceau')),
        );
      });
    }
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_favoritesKey) ?? [];
    if (!mounted) return;
    setState(() {
      _favoriteIds = raw.map(int.tryParse).whereType<int>().toSet();
    });
  }

  Future<void> _setFavoriteState(int songId, bool isFavorite) async {
    setState(() {
      if (isFavorite) {
        _favoriteIds.add(songId);
      } else {
        _favoriteIds.remove(songId);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _favoritesKey,
      _favoriteIds.map((id) => id.toString()).toList(),
    );
  }

  bool _isFavorite(Song song) => _favoriteIds.contains(song.id);

  bool get _isLoggedIn => _authService.currentUser != null;

  Future<void> _openAuthScreen() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
    if (!mounted) return;
    final message = result?.trim();
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _loadSongSocialStats(int songId) async {
    _socialSongId = songId;
    final statsBySong = await _songSocialService.getStatsForSongs(<int>[songId]);
    if (!mounted || _socialSongId != songId) return;
    final stats = statsBySong[songId] ??
        SongSocialStats(songId: songId, likesCount: 0, commentsCount: 0);
    if (stats.hasLiked && !_favoriteIds.contains(songId)) {
      unawaited(_setFavoriteState(songId, true));
    }
    setState(() {
      _socialStats = stats;
    });
  }

  void _ensureSongSocialState(Song song) {
    if (_socialSongId == song.id) return;
    _socialSongId = song.id;
    _socialStats = SongSocialStats(songId: song.id, likesCount: 0, commentsCount: 0);
    _commentsPreviewSongId = song.id;
    _commentsPreviewLoading = true;
    _commentPreviewComments = <SongComment>[];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadSongSocialStats(song.id));
      unawaited(_loadCommentPreview(song.id));
    });
  }

  String _formatCompactCount(int value) {
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

    final days = (totalHours ~/ 24).clamp(1, 10000);
    if (days < 7) return '$days j';
    if (days < 30) return '${(days / 7).floor().clamp(1, 4)} sem';
    if (days < 365) return '${(days / 30).floor().clamp(1, 12)} mois';
    return '${(days / 365).floor().clamp(1, 1000)} an';
  }

  String _buildSongMetaText(Song song) {
    final parts = <String>[
      '${_formatCompactCount(song.playsCount)} vues',
    ];
    final age = _formatSongAge(song.createdAt);
    if (age.isNotEmpty) {
      parts.add(age);
    }
    return parts.join(' • ');
  }

  Future<void> _loadCommentPreview(int songId) async {
    _commentsPreviewSongId = songId;
    if (mounted) {
      setState(() => _commentsPreviewLoading = true);
    }
    final comments = await _songSocialService.getComments(songId, limit: 2);
    if (!mounted || _commentsPreviewSongId != songId) return;
    setState(() {
      _commentPreviewComments = comments;
      _commentsPreviewLoading = false;
    });
  }

  Future<void> _toggleFavoriteLike(Song song) async {
    final nextIsFavorite = !_isFavorite(song);
    await _setFavoriteState(song.id, nextIsFavorite);

    if (!_isLoggedIn) return;

    final stats = _socialStats;
    final shouldLike = nextIsFavorite;
    if (stats != null && stats.hasLiked == shouldLike) {
      return;
    }

    final updated = await _songSocialService.toggleLike(song.id);
    if (!mounted) return;
    if (updated == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d enregistrer le like.')),
      );
      return;
    }

    setState(() {
      _socialStats = updated;
      _socialSongId = song.id;
    });
  }

  Future<void> _openCommentsSheet(Song song) async {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final commentCtrl = TextEditingController();
    final commentsFocus = FocusNode();
    var comments = <SongComment>[];
    var isLoading = true;
    var isSending = false;
    var hasLoaded = false;

    Future<void> loadComments(StateSetter setModalState) async {
      setModalState(() => isLoading = true);
      final loaded = await _songSocialService.getComments(song.id);
      if (!mounted) return;
      comments = loaded;
      setModalState(() => isLoading = false);
    }

    Future<void> submitComment(StateSetter setModalState) async {
      final message = commentCtrl.text.trim();
      if (message.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ecris un commentaire avant d envoyer.')),
        );
        return;
      }
      if (!_isLoggedIn) {
        await _openAuthScreen();
        if (!_isLoggedIn || !mounted) return;
      }

      setModalState(() => isSending = true);
      final error = await _songSocialService.addComment(song.id, message);
      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
        setModalState(() => isSending = false);
        return;
      }

      commentCtrl.clear();
      await loadComments(setModalState);
      await _loadSongSocialStats(song.id);
      await _loadCommentPreview(song.id);
      if (!mounted) return;
      setModalState(() => isSending = false);
    }

    Future<void> deleteComment(
      StateSetter setModalState,
      SongComment comment,
    ) async {
      final error = await _songSocialService.deleteComment(comment.id);
      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
        return;
      }
      await loadComments(setModalState);
      await _loadSongSocialStats(song.id);
      await _loadCommentPreview(song.id);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          if (!hasLoaded) {
            hasLoaded = true;
            unawaited(loadComments(setModalState));
          }

          return AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.78,
                  decoration: BoxDecoration(
                    color: isLightTheme
                        ? Colors.white.withOpacity(0.97)
                        : const Color(0xFF0f0f17).withOpacity(0.96),
                    border: Border.all(
                      color: isLightTheme
                          ? const Color(0xFFE2E6F0)
                          : Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isLightTheme
                                ? const Color(0xFFD0D5E3)
                                : _C.gray500.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Commentaires',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: isLightTheme
                                            ? const Color(0xFF1A1F2D)
                                            : _C.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_socialStats?.commentsCount ?? comments.length} avis sur ${song.title}',
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
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : comments.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 28,
                                        ),
                                        child: Text(
                                          'Aucun commentaire pour le moment. Lance la conversation.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13,
                                            height: 1.5,
                                            color: isLightTheme
                                                ? const Color(0xFF707A92)
                                                : _C.gray400,
                                          ),
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      physics: const BouncingScrollPhysics(),
                                      padding: const EdgeInsets.fromLTRB(
                                        18,
                                        0,
                                        18,
                                        18,
                                      ),
                                      itemCount: comments.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 12),
                                      itemBuilder: (context, index) {
                                        final comment = comments[index];
                                        return Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: isLightTheme
                                                ? const Color(0xFFF6F7FB)
                                                : Colors.white.withOpacity(0.04),
                                            borderRadius: BorderRadius.circular(18),
                                            border: Border.all(
                                              color: isLightTheme
                                                  ? const Color(0xFFE2E6F0)
                                                  : Colors.white.withOpacity(0.06),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      comment.userName,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: isLightTheme
                                                            ? const Color(
                                                                0xFF1A1F2D)
                                                            : _C.white,
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    _fmtDate(comment.createdAt),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: isLightTheme
                                                          ? const Color(
                                                              0xFF7A8197)
                                                          : _C.gray500,
                                                    ),
                                                  ),
                                                  if (comment.isMine) ...[
                                                    const SizedBox(width: 4),
                                                    IconButton(
                                                      onPressed: () => unawaited(
                                                        deleteComment(
                                                          setModalState,
                                                          comment,
                                                        ),
                                                      ),
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                      splashRadius: 18,
                                                      icon: Icon(
                                                        Icons
                                                            .delete_outline_rounded,
                                                        size: 18,
                                                        color: isLightTheme
                                                            ? const Color(
                                                                0xFF7A8197)
                                                            : _C.gray400,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                comment.body,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  height: 1.45,
                                                  color: isLightTheme
                                                      ? const Color(0xFF3A4257)
                                                      : const Color(0xFFE8E9F2),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: commentCtrl,
                                  focusNode: commentsFocus,
                                  minLines: 1,
                                  maxLines: 4,
                                  textInputAction: TextInputAction.newline,
                                  decoration: InputDecoration(
                                    hintText: _isLoggedIn
                                        ? 'Ton commentaire...'
                                        : 'Connecte-toi pour commenter',
                                    filled: true,
                                    fillColor: isLightTheme
                                        ? const Color(0xFFF6F7FB)
                                        : Colors.white.withOpacity(0.04),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide(
                                        color: isLightTheme
                                            ? const Color(0xFFE2E6F0)
                                            : Colors.white.withOpacity(0.06),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide(
                                        color: isLightTheme
                                            ? const Color(0xFFE2E6F0)
                                            : Colors.white.withOpacity(0.06),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide:
                                          const BorderSide(color: _C.v500),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: _C.gradBtn,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _C.v500.withOpacity(0.24),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  onPressed: isSending
                                      ? null
                                      : () => unawaited(submitComment(setModalState)),
                                  icon: isSending
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.send_rounded,
                                          color: Colors.white,
                                        ),
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

    commentCtrl.dispose();
    commentsFocus.dispose();
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _spinCtrl.dispose();
    _shineCtrl.dispose();
    _entranceCtrl.dispose();
    _pulseCtrl.dispose();
    _pageController.dispose();
    _lyricsScrollController.dispose();
    super.dispose();
  }

  Future<void> _openDownloadedSongsList() async {
    await _handler.refreshSongs();
    if (!mounted) return;
    final downloadedSongs =
        _handler.songs.where((s) => s.isDownloaded).toList();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _DownloadedSongsSheet(
        handler: _handler,
        downloadedSongs: downloadedSongs,
        buildArt: _buildSongArt,
        onSongTap: (song) async {
          Navigator.pop(context);
          try {
            await _handler.playSong(song);
            if (!mounted) return;
            setState(() {});
          } catch (_) {}
        },
      ),
    );
  }

  Widget _buildSongArt(Song song) {
    if (song.cover.startsWith('http://') || song.cover.startsWith('https://')) {
      return Image.network(
        song.cover,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackCover(),
      );
    }
    return Image.asset(
      'assets/images/${song.cover}',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _fallbackCover(),
    );
  }

  Widget _fallbackCover() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a0533), Color(0xFF2d1b69), Color(0xFF1a0533)],
          ),
        ),
        child: const Center(
          child: Icon(Icons.music_note_rounded, size: 80, color: _C.v400),
        ),
      );

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _fmtDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  Future<String> _resolveAddedAtLabel(Song song) async {
    if (!song.isDownloaded ||
        song.localPath == null ||
        song.localPath!.isEmpty) {
      return 'Non t\u00E9l\u00E9charg\u00E9';
    }
    try {
      final file = File(song.localPath!);
      if (!await file.exists()) return 'Non disponible';
      final modifiedAt = await file.lastModified();
      return _fmtDate(modifiedAt.toLocal());
    } catch (_) {
      return 'Non disponible';
    }
  }

  Future<void> _openMoreActions(Song song) async {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final selected = await showModalBottomSheet<_NowPlayingAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isLightTheme
                          ? const Color(0xFFD0D5E3)
                          : _C.gray500.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.graphic_eq_rounded),
                    title: const Text('Egaliseur'),
                    onTap: () =>
                        Navigator.pop(context, _NowPlayingAction.equalizer),
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: const Text('Voir les d\u00E9tails'),
                    onTap: () =>
                        Navigator.pop(context, _NowPlayingAction.details),
                  ),
                  ListTile(
                    leading: const Icon(Icons.ios_share_rounded),
                    title: const Text('Partager'),
                    onTap: () =>
                        Navigator.pop(context, _NowPlayingAction.share),
                  ),
                  ListTile(
                    leading: const Icon(Icons.report_problem_outlined),
                    title: const Text('Signaler un probl\u00E8me'),
                    onTap: () =>
                        Navigator.pop(context, _NowPlayingAction.reportIssue),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (!mounted || selected == null) return;

    switch (selected) {
      case _NowPlayingAction.equalizer:
        await _openEqualizer();
      case _NowPlayingAction.details:
        await _showSongDetails(song);
      case _NowPlayingAction.share:
        await _shareSong(song);
      case _NowPlayingAction.reportIssue:
        await _openIssueReport(song);
    }
  }

  Future<void> _openEqualizer() async {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    var speedValue = _playbackSpeed;
    var pitchValue = _playbackPitch;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Text(
                          'Audio Lab',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Vitesse: ${speedValue.toStringAsFixed(2)}x',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Slider(
                        value: speedValue,
                        min: 0.75,
                        max: 1.50,
                        divisions: 15,
                        onChanged: (v) {
                          setModalState(() => speedValue = v);
                          unawaited(_setPlaybackSpeed(v));
                        },
                      ),
                      const SizedBox(height: 6),
                      if (_pitchControlSupported) ...[
                        Text(
                          'Tonalite: ${pitchValue.toStringAsFixed(2)}x',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Slider(
                          value: pitchValue,
                          min: 0.70,
                          max: 1.30,
                          divisions: 12,
                          onChanged: (v) {
                            setModalState(() => pitchValue = v);
                            unawaited(_setPlaybackPitch(v));
                          },
                        ),
                      ] else
                        const Padding(
                          padding: EdgeInsets.only(top: 4, bottom: 8),
                          child: Text(
                            'Controle de tonalite non supporte sur cet appareil.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _presetChip('Normal', () {
                            setModalState(() {
                              speedValue = 1.0;
                              pitchValue = 1.0;
                            });
                            unawaited(
                                _applyVoicePreset(speed: 1.0, pitch: 1.0));
                          }),
                          _presetChip('Grave', () {
                            setModalState(() {
                              speedValue = 0.95;
                              pitchValue = 0.86;
                            });
                            unawaited(
                                _applyVoicePreset(speed: 0.95, pitch: 0.86));
                          }),
                          _presetChip('Aigu', () {
                            setModalState(() {
                              speedValue = 1.05;
                              pitchValue = 1.15;
                            });
                            unawaited(
                                _applyVoicePreset(speed: 1.05, pitch: 1.15));
                          }),
                          _presetChip('Nightcore', () {
                            setModalState(() {
                              speedValue = 1.22;
                              pitchValue = 1.18;
                            });
                            unawaited(
                                _applyVoicePreset(speed: 1.22, pitch: 1.18));
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _presetChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      avatar: const Icon(Icons.tune_rounded, size: 16),
    );
  }

  Future<void> _setPlaybackSpeed(double value) async {
    final clamped = value.clamp(0.75, 1.50).toDouble();
    try {
      await _handler.player.setSpeed(clamped);
      if (!mounted) return;
      setState(() => _playbackSpeed = clamped);
    } catch (_) {}
  }

  Future<void> _setPlaybackPitch(double value) async {
    final clamped = value.clamp(0.70, 1.30).toDouble();
    try {
      await _handler.player.setPitch(clamped);
      if (!mounted) return;
      setState(() => _playbackPitch = clamped);
    } catch (_) {
      if (!mounted) return;
      setState(() => _pitchControlSupported = false);
    }
  }

  Future<void> _applyVoicePreset({
    required double speed,
    required double pitch,
  }) async {
    await _setPlaybackSpeed(speed);
    if (_pitchControlSupported) {
      await _setPlaybackPitch(pitch);
    }
  }

  Future<void> _showSongDetails(Song song) async {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final duration =
        _handler.currentSong?.id == song.id ? _handler.player.duration : null;
    final addedAtLabel = await _resolveAddedAtLabel(song);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 14),
                  Text(
                    'D\u00E9tails du son',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isLightTheme ? const Color(0xFF1A1F2D) : _C.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    leading: const Icon(Icons.music_note_rounded),
                    title: const Text('Titre'),
                    subtitle: Text(song.title),
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_outline_rounded),
                    title: const Text('Artiste'),
                    subtitle: Text(song.artist),
                  ),
                  ListTile(
                    leading: const Icon(Icons.schedule_rounded),
                    title: const Text('Dur\u00E9e'),
                    subtitle: Text(
                        duration == null ? 'Non disponible' : _fmt(duration)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Date d\u2019ajout'),
                    subtitle: Text(addedAtLabel),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _shareSong(Song song) async {
    final text = '${song.title} - ${song.artist}\n'
        'D\u00E9couvre 2Block Music ici:\n$_shareWebsiteUrl';
    try {
      final result = await Share.share(
        text,
        subject: '2Block Music - ${song.title}',
      );
      if (result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.dismissed) {
        return;
      }
    } on MissingPluginException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Partage non initialis\u00E9. Red\u00E9marre compl\u00E8tement l\u2019application.',
          ),
        ),
      );
      return;
    } catch (_) {
      // Second essai minimaliste (lien seul).
      try {
        final result = await Share.shareUri(
          Uri.parse(_shareWebsiteUrl),
        );
        if (result.status == ShareResultStatus.success ||
            result.status == ShareResultStatus.dismissed) {
          return;
        }
      } catch (_) {}
    }

    if (!mounted) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Partage indisponible. Texte copi\u00E9 dans le presse-papiers.',
        ),
      ),
    );
  }

  Future<void> _openIssueReport(Song song) async {
    final issues = <String>[
      'Audio coup\u00E9',
      'Mauvais titre',
      'Mauvais artiste',
      'Paroles incorrectes',
      'Autre probl\u00E8me',
    ];

    final selectedIssue = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Container(
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : const Color(0xFF10101A),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                const Text(
                  'Signaler un probl\u00E8me',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...issues.map(
                  (issue) => ListTile(
                    leading: const Icon(Icons.bug_report_outlined),
                    title: Text(issue),
                    onTap: () => Navigator.pop(context, issue),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );

    if (!mounted || selectedIssue == null) return;
    final channel = await _openIssueChannelPicker();
    if (!mounted || channel == null) return;
    if (channel == _IssueContactChannel.email) {
      await _launchIssueEmail(song: song, issue: selectedIssue);
    } else {
      await _launchIssueWhatsApp(song: song, issue: selectedIssue);
    }
  }

  Future<_IssueContactChannel?> _openIssueChannelPicker() {
    return showModalBottomSheet<_IssueContactChannel>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Container(
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : const Color(0xFF10101A),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                const Text(
                  'Envoyer le signalement via',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.mail_outline_rounded),
                  title: const Text('Email'),
                  subtitle: Text(_supportEmail),
                  onTap: () =>
                      Navigator.pop(context, _IssueContactChannel.email),
                ),
                ListTile(
                  leading: const FaIcon(
                    FontAwesomeIcons.whatsapp,
                    color: Color(0xFF25D366),
                    size: 20,
                  ),
                  title: const Text('WhatsApp'),
                  subtitle: const Text('+226 55 04 12 79'),
                  onTap: () =>
                      Navigator.pop(context, _IssueContactChannel.whatsapp),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchIssueEmail({
    required Song song,
    required String issue,
  }) async {
    final subject = '[2Block Music] Signalement - $issue';
    final body = '''
Bonjour 2Block,

Je signale un probl\u00E8me sur ce morceau :
- Titre : ${song.title}
- Artiste : ${song.artist}
- Probl\u00E8me : $issue

D\u00E9tails suppl\u00E9mentaires :

--
Envoy\u00E9 depuis l'application 2Block Music
''';

    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: <String, String>{
        'subject': subject,
        'body': body,
      },
    );

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched || !mounted) return;

    final fallbackText = 'Sujet: $subject\n\n$body';
    await Clipboard.setData(ClipboardData(text: fallbackText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Aucune app mail trouv\u00E9e. Le message a \u00E9t\u00E9 copi\u00E9 dans le presse-papiers.',
        ),
      ),
    );
  }

  Future<void> _launchIssueWhatsApp({
    required Song song,
    required String issue,
  }) async {
    final message = '''
Bonjour 2Block,
Je signale un probl\u00E8me sur ce morceau :
- Titre : ${song.title}
- Artiste : ${song.artist}
- Probl\u00E8me : $issue
''';

    final uri = Uri.parse(
      'https://wa.me/$_supportWhatsApp?text=${Uri.encodeComponent(message)}',
    );

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched || !mounted) return;

    await Clipboard.setData(ClipboardData(text: message));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'WhatsApp indisponible. Le message a \u00E9t\u00E9 copi\u00E9 dans le presse-papiers.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final currentSong = _handler.currentSong ?? widget.song;
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    _ensureSongSocialState(currentSong);

    return Scaffold(
      backgroundColor: isLightTheme ? const Color(0xFFF8F9FC) : _C.bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isLightTheme
                  ? const Color(0xFFF1F3F9)
                  : Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isLightTheme
                    ? const Color(0xFFE2E6F0)
                    : Colors.white.withOpacity(0.08),
              ),
            ),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: isLightTheme ? const Color(0xFF525A70) : _C.gray400,
              size: 22,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'EN LECTURE',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.18,
          ).copyWith(
            color: isLightTheme ? const Color(0xFF7A8197) : _C.gray500,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isLightTheme
                    ? const Color(0xFFF1F3F9)
                    : Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isLightTheme
                      ? const Color(0xFFE2E6F0)
                      : Colors.white.withOpacity(0.08),
                ),
              ),
              child: Icon(
                Icons.more_vert_rounded,
                color: isLightTheme ? const Color(0xFF525A70) : _C.gray400,
                size: 20,
              ),
            ),
            onPressed: () => _openMoreActions(currentSong),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<Duration>(
        stream: _handler.player.positionStream,
        builder: (context, snapshot) {
          final position = snapshot.data ?? _handler.player.position;
          final duration = _handler.player.duration ?? Duration.zero;

          return Stack(
            children: [
              _AmbientBlob(
                offset: const Offset(-80, -60),
                size: 320,
                color: const Color(0xFF7c3aed).withOpacity(
                  isLightTheme ? 0.12 : 0.3,
                ),
              ),
              _AmbientBlob(
                offset: const Offset(200, 180),
                size: 280,
                color: const Color(0xFFa855f7).withOpacity(
                  isLightTheme ? 0.10 : 0.2,
                ),
              ),
              _AmbientBlob(
                offset: const Offset(-60, 560),
                size: 240,
                color: const Color(0xFF6d28d9).withOpacity(
                  isLightTheme ? 0.08 : 0.15,
                ),
              ),
              FadeTransition(
                opacity: _entranceFade,
                child: SlideTransition(
                  position: _entranceSlide,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        const SizedBox(height: 110),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _buildMediaSwiper(currentSong, position),
                        ),
                        const SizedBox(height: 28),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: _buildSongInfo(currentSong),
                        ),
                        const SizedBox(height: 28),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: _buildProgress(position, duration),
                        ),
                        const SizedBox(height: 28),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildControlsBar(messenger, currentSong),
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildCommentsSection(currentSong),
                        ),
                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  //  Media Swiper (Cover CD + Lyrics)
  Widget _buildMediaSwiper(Song song, Duration position) {
    final syncedLyrics = _parseLrc(song.lyricsLrc);
    final hasLyrics = syncedLyrics.isNotEmpty || song.lyrics.trim().isNotEmpty;
    final pageCount = hasLyrics ? 2 : 1;

    return Column(
      children: [
        SizedBox(
          height: 300,
          child: PageView(
            controller: _pageController,
            onPageChanged: (i) {
              setState(() => _pageIndex = i);
              if (i == 1 && syncedLyrics.isNotEmpty) {
                _focusCurrentLyricLine(syncedLyrics);
              }
            },
            children: [
              _buildCdCoverPage(song),
              if (hasLyrics) _buildLyricsPage(song, position, syncedLyrics),
            ],
          ),
        ),
        if (pageCount > 1) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pageCount, (i) {
              final sel = i == _pageIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 5,
                width: sel ? 22 : 5,
                decoration: BoxDecoration(
                  gradient: sel ? _C.gradBtn : null,
                  color: sel ? null : _C.gray500.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildCdCoverPage(Song song) {
    return SizedBox(
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: const Offset(28, 0),
            child: RotationTransition(
              turns: _spinCtrl,
              child: _buildVinylDisc(),
            ),
          ),
          Transform.translate(
            offset: const Offset(-10, 20),
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _C.p500.withOpacity(0.35),
                    blurRadius: 60,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(-14, 0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.55),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: _C.v500.withOpacity(0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    _buildSongArt(song),
                    // Gloss overlay
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.center,
                            colors: [
                              Colors.white.withOpacity(0.12),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsPage(
    Song song,
    Duration position,
    List<_LrcLine> syncedLines,
  ) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    if (syncedLines.isNotEmpty) {
      if (_lyricsSongId != song.id) {
        _lyricsSongId = song.id;
        _lyricLineKeys.clear();
        _lastAutoScrolledLyricIndex = -1;
        if (_lyricsScrollController.hasClients) {
          _lyricsScrollController.jumpTo(0);
        }
      }
      final activeIndex = _findActiveLrcIndex(syncedLines, position);
      _scheduleLyricsAutoScroll(activeIndex);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (notification.direction != ScrollDirection.idle) {
              _pauseLyricsAutoScroll(const Duration(seconds: 2));
            }
            return false;
          },
          child: ListView.builder(
            controller: _lyricsScrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 120),
            itemCount: syncedLines.length,
            itemBuilder: (context, index) {
              final line = syncedLines[index];
              final isActive = index == activeIndex;
              final lineKey =
                  _lyricLineKeys.putIfAbsent(index, () => GlobalKey());
              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => _onTapLyricLine(line),
                child: AnimatedContainer(
                  key: lineKey,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    style: TextStyle(
                      fontSize: isActive ? 19 : 16.5,
                      height: 1.55,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                      color: isActive
                          ? (isLightTheme ? const Color(0xFF20273A) : _C.white)
                          : (isLightTheme
                              ? const Color(0xFF6C7388)
                              : _C.gray500.withOpacity(0.9)),
                      letterSpacing: 0.15,
                    ),
                    child: Text(
                      line.text,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Text(
          song.lyrics,
          style: TextStyle(
            fontSize: 17,
            height: 1.7,
            fontWeight: FontWeight.w400,
            color: isLightTheme ? const Color(0xFF40485D) : _C.gray400,
            letterSpacing: 0.2,
            shadows: isLightTheme
                ? null
                : [
                    Shadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 8,
                    ),
                  ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  List<_LrcLine> _parseLrc(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return const [];
    final lines = <_LrcLine>[];
    final timestampRegex = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]');

    for (final rawLine in input.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final matches = timestampRegex.allMatches(line).toList();
      if (matches.isEmpty) continue;

      final text = line.replaceAll(timestampRegex, '').trim();
      if (text.isEmpty) continue;

      for (final match in matches) {
        final minute = int.tryParse(match.group(1) ?? '') ?? 0;
        final second = int.tryParse(match.group(2) ?? '') ?? 0;
        final fractionRaw = match.group(3) ?? '0';
        final fraction = int.tryParse(fractionRaw) ?? 0;
        final millis = switch (fractionRaw.length) {
          1 => fraction * 100,
          2 => fraction * 10,
          _ => fraction,
        };
        lines.add(
          _LrcLine(
            start: Duration(
              minutes: minute,
              seconds: second,
              milliseconds: millis,
            ),
            text: text,
          ),
        );
      }
    }

    lines.sort((a, b) => a.start.compareTo(b.start));
    return lines;
  }

  int _findActiveLrcIndex(List<_LrcLine> lines, Duration position) {
    if (lines.isEmpty) return -1;
    for (var i = lines.length - 1; i >= 0; i--) {
      if (position >= lines[i].start) return i;
    }
    return -1;
  }

  void _focusCurrentLyricLine(List<_LrcLine> syncedLines) {
    final currentPos = _handler.player.position;
    final activeIndex = _findActiveLrcIndex(syncedLines, currentPos);
    if (activeIndex < 0) return;
    _lastAutoScrolledLyricIndex = activeIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerLyricIndex(activeIndex, immediate: true);
    });
  }

  void _pauseLyricsAutoScroll(Duration duration) {
    _manualLyricsScrollUntil = DateTime.now().add(duration);
  }

  Future<void> _onTapLyricLine(_LrcLine line) async {
    _pauseLyricsAutoScroll(const Duration(seconds: 1));
    try {
      final duration = _handler.player.duration;
      final target = duration == null
          ? line.start
          : (line.start > duration ? duration : line.start);
      await _handler.player.seek(target);
      if (!_handler.player.playing) {
        await _handler.player.play();
      }
    } catch (_) {
      // Ignore seek/play errors to avoid breaking playback UI.
    }
  }

  void _scheduleLyricsAutoScroll(int activeIndex) {
    if (activeIndex < 0 || activeIndex == _lastAutoScrolledLyricIndex) return;
    if (_manualLyricsScrollUntil != null &&
        DateTime.now().isBefore(_manualLyricsScrollUntil!)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _lyricLineKeys[activeIndex]?.currentContext;
      if (context != null) {
        _lastAutoScrolledLyricIndex = activeIndex;
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
        return;
      }
      // Fallback when target line widget is not built yet.
      _lastAutoScrolledLyricIndex = activeIndex;
      _centerLyricIndex(activeIndex);
    });
  }

  void _centerLyricIndex(int index, {bool immediate = false}) {
    if (!_lyricsScrollController.hasClients || index < 0) return;
    const itemExtentEstimate = 42.0;
    const topPadding = 120.0;
    final viewport = _lyricsScrollController.position.viewportDimension;
    final rawTarget =
        topPadding + (index * itemExtentEstimate) - (viewport / 2) + 22.0;
    final max = _lyricsScrollController.position.maxScrollExtent;
    final target = rawTarget.clamp(0.0, max);
    if (immediate) {
      _lyricsScrollController.jumpTo(target);
      return;
    }
    _lyricsScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  //  Vinyl Disc Widget
  Widget _buildVinylDisc() {
    return SizedBox(
      width: 232,
      height: 232,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base disc
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                stops: [0.09, 0.42, 0.72, 1.0],
                colors: [
                  Color(0xFF3a3a3a),
                  Color(0xFF1c1c1c),
                  Color(0xFF101010),
                  Color(0xFF080808),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
          ),

          // Concentric groove rings
          for (final d in [190.0, 164.0, 140.0, 116.0, 92.0, 68.0])
            Container(
              width: d,
              height: d,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.055),
                  width: 0.8,
                ),
              ),
            ),

          // Subtle violet groove tint
          Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  _C.v600.withOpacity(0.0),
                  _C.v600.withOpacity(0.08),
                  _C.v600.withOpacity(0.0),
                  _C.v600.withOpacity(0.05),
                  _C.v600.withOpacity(0.0),
                ],
              ),
            ),
          ),

          // Shine sweep (animated)
          AnimatedBuilder(
            animation: _shineCtrl,
            builder: (context, child) {
              final angle = _shineCtrl.value * 2 * math.pi;
              return Transform.rotate(angle: angle, child: child);
            },
            child: Container(
              width: 188,
              height: 188,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    Colors.white.withOpacity(0.20),
                    Colors.white.withOpacity(0.0),
                    Colors.white.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // Center hub
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFFF0F0F0), Color(0xFFD0D0D0)],
              ),
              border: Border.all(color: Colors.black54, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  //  Song Info
  Widget _buildSongInfo(Song song) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final isFavorite = _isFavorite(song);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: isLightTheme ? const Color(0xFF1A1F2D) : _C.white,
                  letterSpacing: -0.5,
                  height: 1.15,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                song.artist,
                style: TextStyle(
                  fontSize: 16,
                  color: isLightTheme ? const Color(0xFF636C83) : _C.gray400,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _buildSongMetaText(song),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isLightTheme ? const Color(0xFF7A8197) : _C.gray500,
                  letterSpacing: 0.05,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => unawaited(_toggleFavoriteLike(song)),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isLightTheme
                  ? const Color(0xFFF1F3F9)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isLightTheme
                    ? const Color(0xFFE2E6F0)
                    : Colors.white.withOpacity(0.08),
              ),
            ),
            child: Icon(
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: isFavorite
                  ? _C.v500
                  : (isLightTheme ? const Color(0xFF636C83) : _C.gray400),
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentsSection(Song song) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final commentsCount =
        _socialStats?.commentsCount ?? _commentPreviewComments.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: isLightTheme
                ? Colors.white.withOpacity(0.88)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isLightTheme
                  ? const Color(0xFFE2E6F0)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Commentaires',
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
                          '$commentsCount commentaire${commentsCount > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isLightTheme
                                ? const Color(0xFF7A8197)
                                : _C.gray500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => unawaited(_openCommentsSheet(song)),
                    child: const Text('Voir tout'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_commentsPreviewLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_commentPreviewComments.isEmpty)
                Text(
                  'Aucun commentaire pour le moment. Lance la conversation.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: isLightTheme
                        ? const Color(0xFF707A92)
                        : _C.gray400,
                  ),
                )
              else
                Column(
                  children: _commentPreviewComments
                      .map(
                        (comment) => Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isLightTheme
                                ? const Color(0xFFF6F7FB)
                                : Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isLightTheme
                                  ? const Color(0xFFE2E6F0)
                                  : Colors.white.withOpacity(0.06),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      comment.userName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isLightTheme
                                            ? const Color(0xFF1A1F2D)
                                            : _C.white,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _fmtDate(comment.createdAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isLightTheme
                                          ? const Color(0xFF7A8197)
                                          : _C.gray500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                comment.body,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: isLightTheme
                                      ? const Color(0xFF454D62)
                                      : _C.gray400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => unawaited(_openCommentsSheet(song)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.v500,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Ouvrir les commentaires'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //  Progress Bar
  Widget _buildProgress(Duration position, Duration duration) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final maxMs = duration.inMilliseconds <= 0 ? 1 : duration.inMilliseconds;
    final val = position.inMilliseconds.clamp(0, maxMs).toDouble();

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3.5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: _C.v400,
            inactiveTrackColor: isLightTheme
                ? const Color(0xFFD8DDE9)
                : Colors.white.withOpacity(0.1),
            thumbColor: isLightTheme ? const Color(0xFFFBFCFF) : _C.white,
            overlayColor: _C.v400.withOpacity(0.2),
          ),
          child: Slider(
            value: val,
            max: maxMs.toDouble(),
            onChanged: (v) =>
                _handler.player.seek(Duration(milliseconds: v.toInt())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(position),
                  style: TextStyle(
                    fontSize: 12,
                    color: isLightTheme ? const Color(0xFF7A8197) : _C.gray500,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.05,
                  )),
              Text(_fmt(duration),
                  style: TextStyle(
                    fontSize: 12,
                    color: isLightTheme ? const Color(0xFF7A8197) : _C.gray500,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.05,
                  )),
            ],
          ),
        ),
      ],
    );
  }

  //  Controls Bar
  Widget _buildControlsBar(ScaffoldMessengerState messenger, Song currentSong) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isLightTheme
                ? Colors.white.withOpacity(0.88)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isLightTheme
                  ? const Color(0xFFE2E6F0)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CtrlIconBtn(
                icon: _handler.isShuffle
                    ? Icons.shuffle_rounded
                    : (_handler.isRepeatOne
                        ? Icons.repeat_one_rounded
                        : Icons.repeat_rounded),
                isActive: true,
                activeColor: _C.v400,
                isLightTheme: isLightTheme,
                onTap: () {
                  _handler.cyclePlaybackControlMode();
                  setState(() {});
                },
              ),
              _CtrlIconBtn(
                icon: Icons.skip_previous_rounded,
                size: 32,
                isLightTheme: isLightTheme,
                onTap: () {
                  _handler.previousSong();
                  setState(() {});
                },
              ),
              StreamBuilder<PlayerState>(
                stream: _handler.player.playerStateStream,
                builder: (context, snap) {
                  final isPlaying = snap.data?.playing ?? _handler.isPlaying;
                  return _PlayButton(
                    isPlaying: isPlaying,
                    isLightTheme: isLightTheme,
                    pulseAnim: _pulseAnim,
                    onTap: () {
                      if (isPlaying) {
                        _handler.pause();
                      } else {
                        _handler
                            .playSong(_handler.currentSong ?? widget.song)
                            .catchError((_) {
                          if (!mounted) return;
                          messenger.showSnackBar(const SnackBar(
                            content: Text(
                                'T\u00E9l\u00E9charge le son avant la lecture'),
                          ));
                        });
                      }
                    },
                  );
                },
              ),
              _CtrlIconBtn(
                icon: Icons.skip_next_rounded,
                size: 32,
                isLightTheme: isLightTheme,
                onTap: () {
                  _handler.nextSong();
                  setState(() {});
                },
              ),
              _CtrlIconBtn(
                icon: Icons.queue_music_rounded,
                isLightTheme: isLightTheme,
                onTap: _openDownloadedSongsList,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//  Play Button
class _PlayButton extends StatelessWidget {
  final bool isPlaying;
  final bool isLightTheme;
  final Animation<double> pulseAnim;
  final VoidCallback onTap;

  const _PlayButton({
    required this.isPlaying,
    required this.isLightTheme,
    required this.pulseAnim,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: pulseAnim,
        builder: (context, child) {
          final glow = isPlaying ? 30.0 + pulseAnim.value * 20 : 14.0;
          final glowOpacity = isPlaying ? 0.40 + pulseAnim.value * 0.25 : 0.25;
          return Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _C.gradBtn,
              boxShadow: [
                BoxShadow(
                  color: _C.p500.withOpacity(glowOpacity),
                  blurRadius: glow,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: isLightTheme
                      ? const Color(0x221E2230)
                      : Colors.black.withOpacity(0.4),
                  blurRadius: isLightTheme ? 10 : 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: child,
          );
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            key: ValueKey(isPlaying),
            size: 32,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

//  Control Icon Button
class _CtrlIconBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool isActive;
  final Color activeColor;
  final bool isLightTheme;
  final VoidCallback onTap;

  const _CtrlIconBtn({
    required this.icon,
    required this.onTap,
    required this.isLightTheme,
    this.size = 26,
    this.isActive = false,
    this.activeColor = _C.v400,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon,
                size: size,
                color: isActive
                    ? activeColor
                    : (isLightTheme ? const Color(0xFF5C647A) : _C.gray400)),
            if (isActive)
              Positioned(
                bottom: 6,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: activeColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

//  Ambient Blob
class _AmbientBlob extends StatelessWidget {
  final Offset offset;
  final double size;
  final Color color;

  const _AmbientBlob({
    required this.offset,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

//  Downloaded Songs Bottom Sheet
class _DownloadedSongsSheet extends StatelessWidget {
  final AudioHandler handler;
  final List<Song> downloadedSongs;
  final Widget Function(Song) buildArt;
  final void Function(Song) onSongTap;

  const _DownloadedSongsSheet({
    required this.handler,
    required this.downloadedSongs,
    required this.buildArt,
    required this.onSongTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isLightTheme
                ? Colors.white.withOpacity(0.96)
                : const Color(0xFF0f0f17).withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isLightTheme
                  ? const Color(0xFFE2E6F0)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: SafeArea(
            child: SizedBox(
              height: downloadedSongs.isEmpty ? 180 : 420,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isLightTheme
                          ? const Color(0xFFD0D5E3)
                          : _C.gray500.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sons t\u00E9l\u00E9charg\u00E9s',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isLightTheme ? const Color(0xFF1A1F2D) : _C.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (downloadedSongs.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'Aucun son t\u00E9l\u00E9charg\u00E9',
                          style: TextStyle(
                            color: isLightTheme
                                ? const Color(0xFF7A8197)
                                : _C.gray500,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: downloadedSongs.length,
                        itemBuilder: (context, index) {
                          final song = downloadedSongs[index];
                          final isCurrent = handler.currentSong?.id == song.id;
                          return GestureDetector(
                            onTap: () => onSongTap(song),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? _C.v600
                                        .withOpacity(isLightTheme ? 0.12 : 0.15)
                                    : (isLightTheme
                                        ? const Color(0xFFF6F8FC)
                                        : Colors.white.withOpacity(0.04)),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isCurrent
                                      ? _C.v500.withOpacity(0.4)
                                      : (isLightTheme
                                          ? const Color(0xFFE2E6F0)
                                          : Colors.white.withOpacity(0.06)),
                                ),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: buildArt(song),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(song.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: isCurrent
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: isCurrent
                                                  ? _C.v400
                                                  : (isLightTheme
                                                      ? const Color(0xFF1A1F2D)
                                                      : _C.white),
                                              fontSize: 14,
                                            )),
                                        const SizedBox(height: 3),
                                        Text(song.artist,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isLightTheme
                                                  ? const Color(0xFF7A8197)
                                                  : _C.gray500,
                                            )),
                                      ],
                                    ),
                                  ),
                                  if (isCurrent)
                                    const Icon(Icons.equalizer_rounded,
                                        color: _C.v400, size: 20),
                                ],
                              ),
                            ),
                          );
                        },
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

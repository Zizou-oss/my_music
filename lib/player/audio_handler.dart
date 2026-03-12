import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/song.dart';
import '../repositories/song_repository.dart';
import '../services/listening_sync_service.dart';

class AudioHandler extends ChangeNotifier {
  static final AudioHandler _instance = AudioHandler._internal();
  factory AudioHandler() => _instance;

  AudioHandler._internal() {
    _player.playerStateStream.listen((state) {
      _handlePlaybackStateChange(state);
      notifyListeners();
    });

    _player.currentIndexStream.listen((index) {
      _handleCurrentIndexChange(index);
    });

    unawaited(_applyPlaybackModes());
  }

  final AudioPlayer _player = AudioPlayer();
  final SongRepository _songRepository = SongRepository();
  final ListeningSyncService _syncService = ListeningSyncService();

  Song? currentSong;
  List<Song> _songs = [];
  List<Song> _playableQueue = [];
  List<int> _queueSongIds = [];
  final Map<int, Uri> _localCoverUriBySongId = {};

  bool _isShuffle = false;
  bool _isRepeat = true;
  bool _isRepeatOne = false;

  DateTime? _sessionStart;
  String? _sessionId;
  int? _sessionSongId;
  bool _wasPlaying = false;

  AudioPlayer get player => _player;
  bool get isPlaying => _player.playing;
  bool get isShuffle => _isShuffle;
  bool get isRepeat => _isRepeat;
  bool get isRepeatOne => _isRepeatOne;
  List<Song> get songs => _songs;

  Future<void> refreshSongs() async {
    _songs = await _songRepository.getSongs();
    _refreshCurrentSongReference();
    notifyListeners();
  }

  void replaceSongs(List<Song> songs) {
    _songs = List<Song>.from(songs);
    _refreshCurrentSongReference();
    notifyListeners();
  }

  Future<void> _ensureSongsLoaded() async {
    if (_songs.isNotEmpty) return;
    _songs = await _songRepository.getSongs();
    _refreshCurrentSongReference();
  }

  Future<void> playSong(Song song) async {
    await _ensureSongsLoaded();

    Song resolved = _songs.firstWhere(
      (s) => s.id == song.id,
      orElse: () => song,
    );

    if (!_isPlayable(resolved)) {
      // Retry once with a fresh catalog for recent download state changes.
      _songs = await _songRepository.getSongs();
      _refreshCurrentSongReference();
      resolved = _songs.firstWhere(
        (s) => s.id == song.id,
        orElse: () => song,
      );
    }

    if (!_isPlayable(resolved)) {
      throw Exception('Le morceau doit etre telecharge avant lecture');
    }

    final playable = _songs.where(_isPlayable).toList();
    if (playable.isEmpty) {
      throw Exception('Aucun morceau telecharge');
    }

    final targetIndex = playable.indexWhere((s) => s.id == resolved.id);
    if (targetIndex < 0) {
      throw Exception('Morceau introuvable dans la file');
    }

    final sameSong = currentSong?.id == resolved.id;
    final queueChanged = !_isQueueSame(playable);
    final hasLoadedSource = _player.audioSource != null;

    if (!queueChanged && hasLoadedSource && sameSong && !_player.playing) {
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero, index: targetIndex);
      }
      await _player.play();
      return;
    }

    if (queueChanged || !hasLoadedSource) {
      if (_player.playing) {
        await _flushListeningSession();
      }
      await _loadPlayableQueue(playable, initialIndex: targetIndex);
    } else if (_player.currentIndex != targetIndex) {
      if (_player.playing) {
        await _flushListeningSession();
      }
      await _player.seek(Duration.zero, index: targetIndex);
      currentSong = playable[targetIndex];
    } else if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero, index: targetIndex);
    }

    await _player.play();
    notifyListeners();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> nextSong() async {
    await _ensureQueueReady();
    if (_playableQueue.isEmpty) return;

    if (_player.hasNext) {
      await _player.seekToNext();
    } else if (_isRepeat) {
      await _player.seek(Duration.zero, index: 0);
    } else {
      return;
    }

    if (!_player.playing) {
      await _player.play();
    }
  }

  Future<void> previousSong() async {
    await _ensureQueueReady();
    if (_playableQueue.isEmpty) return;

    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }

    if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else if (_isRepeat) {
      await _player.seek(Duration.zero, index: _playableQueue.length - 1);
    } else {
      return;
    }

    if (!_player.playing) {
      await _player.play();
    }
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    unawaited(_applyPlaybackModes());
    notifyListeners();
  }

  void cyclePlaybackMode() {
    // Cycle: off -> shuffle -> repeat all -> repeat one -> off
    if (!_isShuffle && !_isRepeat && !_isRepeatOne) {
      _isShuffle = true;
      _isRepeat = false;
      _isRepeatOne = false;
    } else if (_isShuffle) {
      _isShuffle = false;
      _isRepeat = true;
      _isRepeatOne = false;
    } else if (_isRepeat && !_isRepeatOne) {
      _isShuffle = false;
      _isRepeat = false;
      _isRepeatOne = true;
    } else {
      _isShuffle = false;
      _isRepeat = false;
      _isRepeatOne = false;
    }

    unawaited(_applyPlaybackModes());
    notifyListeners();
  }

  void toggleRepeat() {
    if (!_isRepeat && !_isRepeatOne) {
      _isRepeat = true;
      _isRepeatOne = false;
    } else if (_isRepeat && !_isRepeatOne) {
      _isRepeat = false;
      _isRepeatOne = true;
    } else {
      _isRepeat = false;
      _isRepeatOne = false;
    }

    unawaited(_applyPlaybackModes());
    notifyListeners();
  }

  void cyclePlaybackControlMode() {
    // Cycle: repeat all -> shuffle -> repeat one -> repeat all
    if (_isRepeat && !_isShuffle && !_isRepeatOne) {
      _isRepeat = false;
      _isShuffle = true;
      _isRepeatOne = false;
    } else if (_isShuffle) {
      _isRepeat = false;
      _isShuffle = false;
      _isRepeatOne = true;
    } else {
      _isRepeat = true;
      _isShuffle = false;
      _isRepeatOne = false;
    }

    unawaited(_applyPlaybackModes());
    notifyListeners();
  }

  Future<void> _ensureQueueReady() async {
    await _ensureSongsLoaded();
    final playable = _songs.where(_isPlayable).toList();
    if (playable.isEmpty) return;

    final queueChanged = !_isQueueSame(playable);
    if (!queueChanged && _player.audioSource != null) return;

    final currentId = currentSong?.id;
    var targetIndex = 0;
    if (currentId != null) {
      final found = playable.indexWhere((song) => song.id == currentId);
      if (found >= 0) targetIndex = found;
    }
    await _loadPlayableQueue(playable, initialIndex: targetIndex);
  }

  Future<void> _loadPlayableQueue(
    List<Song> playable, {
    required int initialIndex,
  }) async {
    final sources = <AudioSource>[];
    for (final song in playable) {
      final mediaItem = MediaItem(
        id: song.id.toString(),
        album: '2Block Music Offline',
        title: song.title,
        artist: song.artist,
        artUri: await _resolveMediaArtUri(song),
        displayTitle: song.title,
        displaySubtitle: song.artist,
        displayDescription: '2Block Music',
      );
      sources.add(AudioSource.file(song.localPath!, tag: mediaItem));
    }

    final source = ConcatenatingAudioSource(
      useLazyPreparation: true,
      children: sources,
    );

    _playableQueue = playable;
    _queueSongIds = playable.map((song) => song.id).toList();

    await _player.setAudioSource(source, initialIndex: initialIndex);
    currentSong = playable[initialIndex];
    await _applyPlaybackModes();
  }

  bool _isQueueSame(List<Song> playable) {
    if (_queueSongIds.length != playable.length) return false;
    for (var i = 0; i < playable.length; i++) {
      if (_queueSongIds[i] != playable[i].id) return false;
    }
    return true;
  }

  Future<void> _applyPlaybackModes() async {
    if (_isRepeatOne) {
      await _player.setLoopMode(LoopMode.one);
    } else if (_isRepeat) {
      await _player.setLoopMode(LoopMode.all);
    } else {
      await _player.setLoopMode(LoopMode.off);
    }

    if (_isShuffle) {
      await _player.shuffle();
      await _player.setShuffleModeEnabled(true);
    } else {
      await _player.setShuffleModeEnabled(false);
    }
  }

  void _handleCurrentIndexChange(int? index) {
    if (index == null) return;
    if (index < 0 || index >= _playableQueue.length) return;

    final nextSong = _playableQueue[index];
    if (currentSong?.id == nextSong.id) return;

    currentSong = nextSong;
    if (_player.playing) {
      unawaited(_rolloverListeningSessionForTrackChange());
    }
    notifyListeners();
  }

  void _refreshCurrentSongReference() {
    final currentId = currentSong?.id;
    if (currentId == null) return;
    final updatedIndex = _songs.indexWhere((song) => song.id == currentId);
    if (updatedIndex >= 0) {
      currentSong = _songs[updatedIndex];
    }
  }

  Future<void> _rolloverListeningSessionForTrackChange() async {
    await _flushListeningSession();
    if (_player.playing && currentSong != null) {
      _startListeningSessionForCurrentSong();
    }
  }

  void _handlePlaybackStateChange(PlayerState state) {
    final isNowPlaying = state.playing;
    final hasCurrentSong = currentSong != null;

    if (isNowPlaying && !_wasPlaying && hasCurrentSong) {
      _startListeningSessionForCurrentSong();
    }

    if (!isNowPlaying && _wasPlaying) {
      unawaited(_flushListeningSession());
    }

    _wasPlaying = isNowPlaying;
  }

  void _startListeningSessionForCurrentSong() {
    if (currentSong == null) return;
    _sessionStart = DateTime.now();
    _sessionSongId = currentSong!.id;
    _sessionId = _syncService.newSessionId();
  }

  Future<void> _flushListeningSession() async {
    if (_sessionStart == null || _sessionId == null || _sessionSongId == null) return;

    final end = DateTime.now();
    final seconds = end.difference(_sessionStart!).inSeconds;
    if (seconds >= 3) {
      final isOffline = await _syncService.isCurrentlyOffline();
      await _syncService.queueListeningEvent(
        songId: _sessionSongId!,
        sessionId: _sessionId!,
        startedAt: _sessionStart!,
        endedAt: end,
        secondsListened: seconds,
        isOffline: isOffline,
      );
      await _syncService.syncPendingEvents();
    }

    _sessionStart = null;
    _sessionId = null;
    _sessionSongId = null;
  }

  bool _isPlayable(Song song) {
    return song.isDownloaded && (song.localPath?.isNotEmpty ?? false);
  }

  Future<Uri?> _resolveMediaArtUri(Song song) async {
    final raw = song.cover.trim();
    if (raw.isEmpty) return null;

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return Uri.tryParse(raw);
    }

    if (raw.startsWith('/')) {
      return Uri.file(raw);
    }

    if (raw.startsWith('file://')) {
      return Uri.tryParse(raw);
    }

    final cachedUri = _localCoverUriBySongId[song.id];
    if (cachedUri != null) {
      final file = File(cachedUri.toFilePath());
      if (await file.exists()) return cachedUri;
    }

    final assetPath = raw.startsWith('assets/') ? raw : 'assets/images/$raw';
    try {
      final bytes = await rootBundle.load(assetPath);
      final appDir = await getApplicationSupportDirectory();
      final coversDir = Directory(p.join(appDir.path, 'downloads', 'covers'));
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      final ext = p.extension(assetPath).isEmpty ? '.jpg' : p.extension(assetPath);
      final filePath = p.join(coversDir.path, 'song_cover_${song.id}$ext');
      final file = File(filePath);

      if (!await file.exists() || await file.length() == 0) {
        await file.writeAsBytes(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          flush: false,
        );
      }

      final uri = Uri.file(filePath);
      _localCoverUriBySongId[song.id] = uri;
      return uri;
    } catch (_) {
      // Ignore missing/invalid asset cover.
    }

    return null;
  }
}

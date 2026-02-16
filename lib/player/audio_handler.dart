import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../database/db_helper.dart';

class AudioHandler extends ChangeNotifier {
  static final AudioHandler _instance = AudioHandler._internal();
  factory AudioHandler() => _instance;

  AudioHandler._internal() {
    _player.playerStateStream.listen((_) => notifyListeners());

    _player.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && index < _songs.length) {
        _currentIndex = index;
        if (_hasUserStartedPlayback) {
          currentSong = _songs[index];
        }
        notifyListeners();
      }
    });

    _loadSongs();
  }

  final AudioPlayer _player = AudioPlayer();
  final ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(children: []);

  Song? currentSong;
  int _currentIndex = -1;
  List<Song> _songs = [];
  bool _hasUserStartedPlayback = false;

  bool _isShuffle = false;
  bool _isRepeat = false;
  bool _isRepeatOne = false;

  AudioPlayer get player => _player;

  bool get isPlaying => _player.playing;
  bool get isShuffle => _isShuffle;
  bool get isRepeat => _isRepeat;
  bool get isRepeatOne => _isRepeatOne;
  List<Song> get songs => _songs;

  MediaItem _mediaItemFor(Song song) {
    return MediaItem(
      id: song.id.toString(),
      album: '2Block Music',
      title: song.title,
      artist: song.artist,
      artUri: Uri.parse('asset:///assets/images/${song.cover}'),
    );
  }

  Future<void> _loadSongs() async {
    try {
      _songs = await DBHelper.getSongs();
      if (_songs.isEmpty) {
        notifyListeners();
        return;
      }

      _playlist.clear();
      _playlist.addAll(
        _songs
            .map<AudioSource>(
              (song) => AudioSource.asset(
                'assets/audio/${song.file}',
                tag: _mediaItemFor(song),
              ),
            )
            .toList(),
      );

      await _player.setAudioSource(_playlist);
      _currentIndex = _player.currentIndex ?? -1;
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur lors du chargement des chansons : $e');
    }
  }

  Future<void> playSong(Song song) async {
    if (_songs.isEmpty) {
      await _loadSongs();
      if (_songs.isEmpty) return;
    }

    final index = _songs.indexWhere((s) => s.id == song.id);
    final targetIndex = index == -1 ? 0 : index;

    _hasUserStartedPlayback = true;
    await _player.seek(Duration.zero, index: targetIndex);
    await _player.play();
  }

  Future<void> nextSong() async {
    if (_songs.isEmpty) {
      await _loadSongs();
      if (_songs.isEmpty) return;
    }

    _hasUserStartedPlayback = true;
    if (_player.hasNext) {
      await _player.seekToNext();
    } else {
      await _player.seek(Duration.zero, index: 0);
    }
    await _player.play();
  }

  Future<void> previousSong() async {
    if (_songs.isEmpty) {
      await _loadSongs();
      if (_songs.isEmpty) return;
    }

    _hasUserStartedPlayback = true;
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }

    if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else {
      await _player.seek(Duration.zero, index: _songs.length - 1);
    }
    await _player.play();
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    _player.setShuffleModeEnabled(_isShuffle);
    notifyListeners();
  }

  void toggleRepeat() {
    if (!_isRepeat && !_isRepeatOne) {
      _isRepeat = true;
      _isRepeatOne = false;
      _player.setLoopMode(LoopMode.all);
    } else if (_isRepeat && !_isRepeatOne) {
      _isRepeat = false;
      _isRepeatOne = true;
      _player.setLoopMode(LoopMode.one);
    } else {
      _isRepeat = false;
      _isRepeatOne = false;
      _player.setLoopMode(LoopMode.off);
    }
    notifyListeners();
  }

  Future<void> refreshSongs() async {
    await _loadSongs();
  }
}




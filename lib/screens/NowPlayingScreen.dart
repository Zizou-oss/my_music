import 'dart:async';

import 'package:flutter/material.dart';

import '../models/song.dart';
import '../player/audio_handler.dart';

class NowPlayingScreen extends StatefulWidget {
  final Song song;
  const NowPlayingScreen({Key? key, required this.song}) : super(key: key);

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  final AudioHandler _handler = AudioHandler();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (_handler.currentSong?.id != widget.song.id) {
      _handler.playSong(widget.song);
    }

    _timer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final position = _handler.player.position;
    final duration = _handler.player.duration ?? Duration.zero;

    return Scaffold(
      appBar: AppBar(title: const Text('')),
      body: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.asset(
                'assets/images/${_handler.currentSong?.cover ?? widget.song.cover}',
                width: 300,
                height: 300,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.music_note, size: 100, color: Colors.grey),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Text(
                  _handler.currentSong?.title ?? widget.song.title,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  _handler.currentSong?.artist ?? '2Block',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: position.inMilliseconds.toDouble(),
                max: duration.inMilliseconds.toDouble(),
                activeColor: Colors.red,
                inactiveColor: Colors.grey[300],
                onChanged: (value) {
                  _handler.player.seek(Duration(milliseconds: value.toInt()));
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(position),
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                Text(
                  _formatDuration(duration),
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.shuffle,
                    size: 28,
                    color: _handler.isShuffle ? Colors.red : Colors.grey,
                  ),
                  onPressed: () {
                    _handler.toggleShuffle();
                    setState(() {});
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 36),
                  onPressed: () {
                    _handler.previousSong();
                    setState(() {});
                  },
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      _handler.isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 36,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      if (_handler.isPlaying) {
                        _handler.player.pause();
                      } else {
                        _handler.playSong(_handler.currentSong ?? widget.song);
                      }
                      setState(() {});
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 36),
                  onPressed: () {
                    _handler.nextSong();
                    setState(() {});
                  },
                ),
                IconButton(
                  icon: Icon(
                    _handler.isRepeatOne ? Icons.repeat_one : Icons.repeat,
                    size: 28,
                    color: (_handler.isRepeat || _handler.isRepeatOne)
                        ? Colors.red
                        : Colors.grey,
                  ),
                  onPressed: () {
                    _handler.toggleRepeat();
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

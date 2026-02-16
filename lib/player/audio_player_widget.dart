// file: player/audio_player_widget.dart
import 'package:flutter/material.dart';
import '../models/song.dart';
import '../player/audio_handler.dart';

class AudioPlayerWidget extends StatelessWidget {
  final Song song;
  const AudioPlayerWidget({Key? key, required this.song}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => AudioHandler().playSong(song), // lecture directe
      child: Card(
        child: ListTile(
          leading: Image.asset('assets/images/${song.cover}'),
          title: Text(song.title),
        ),
      ),
    );
  }
}

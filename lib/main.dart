import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/home_screen.dart';
import 'player/audio_handler.dart';

final AudioHandler audioHandler = AudioHandler();

Future<void> _requestPermissions() async {
  if (kIsWeb) return;
  if (!Platform.isAndroid) return;

  final status = await Permission.notification.status;
  if (status.isDenied) {
    await Permission.notification.request();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.my_music.channel.audio',
    androidNotificationChannelName: '2Block Music',
    androidNotificationOngoing: true,
  );

  await _requestPermissions();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '2Block Music',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

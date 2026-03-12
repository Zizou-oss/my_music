import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  static const String _homeDoneKey = 'tutorial_home_done_v1';
  static const String _nowPlayingDoneKey = 'tutorial_now_playing_done_v1';

  Future<bool> hasSeenHomeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_homeDoneKey) ?? false;
  }

  Future<void> markHomeTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_homeDoneKey, true);
  }

  Future<bool> hasSeenNowPlayingTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_nowPlayingDoneKey) ?? false;
  }

  Future<void> markNowPlayingTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_nowPlayingDoneKey, true);
  }

  Future<void> resetGuides() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_homeDoneKey);
    await prefs.remove(_nowPlayingDoneKey);
  }
}

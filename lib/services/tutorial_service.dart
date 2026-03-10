import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  static const String _homeDoneKey = 'tutorial_home_done_v1';

  Future<bool> hasSeenHomeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_homeDoneKey) ?? false;
  }

  Future<void> markHomeTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_homeDoneKey, true);
  }

  Future<void> resetGuides() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_homeDoneKey);
  }
}

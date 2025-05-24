import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefs {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static bool isOnboardingCompleted() {
    return _prefs.getBool('onboarding_completed') ?? false;
  }

  static Future<void> setOnboardingCompleted() async {
    await _prefs.setBool('onboarding_completed', true);
  }

  static Future<void> saveScanToTimeline(String scanId) async {
    List<String> savedScans = _prefs.getStringList('saved_scans') ?? [];
    if (!savedScans.contains(scanId)) {
      savedScans.add(scanId);
      await _prefs.setStringList('saved_scans', savedScans);
    }
  }

  static List<String> getSavedScans() {
    return _prefs.getStringList('saved_scans') ?? [];
  }

  static Future<void> removeScanFromTimeline(String scanId) async {
    List<String> savedScans = _prefs.getStringList('saved_scans') ?? [];
    savedScans.remove(scanId);
    await _prefs.setStringList('saved_scans', savedScans);
  }
}

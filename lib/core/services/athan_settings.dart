import 'package:shared_preferences/shared_preferences.dart';
import '../constants/athan.dart';

class AthanSettings {
  static const _kEnabled = 'athan_notifications_enabled';
  static const _kReciterId = 'athan_reciter_id';

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabled) ?? false;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, value);
  }

  static Future<AthanOption> getReciter() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kReciterId);
    return kAthanOptions.firstWhere(
      (a) => a.id == id,
      orElse: () => kAthanMakkah,
    );
  }

  static Future<void> setReciter(AthanOption athan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kReciterId, athan.id);
  }
}

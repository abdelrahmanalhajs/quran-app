import 'package:shared_preferences/shared_preferences.dart';

/// Whether the morning/evening athkar reminders (tied to Fajr/Asr prayer
/// times rather than a fixed clock time) are enabled.
class AthkarPrayerReminderSettings {
  static const _kEnabled = 'athkar_prayer_reminders_enabled';

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabled) ?? false;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, value);
  }
}

// ignore_for_file: prefer_initializing_formals
import 'package:shared_preferences/shared_preferences.dart';

/// A simple on/off preference backing one of the fixed-clock-time
/// notification toggles in Settings (daily hadith, hourly zikr, sleep
/// athkar, Jumu'ah athkar). Centralized here (rather than as private
/// constants inside the settings screen) so app startup can also read
/// these to (re-)schedule anything the user has enabled — toggling a
/// switch isn't the only moment a notification should get scheduled.
class BoolNotificationSetting {
  final String _key;
  final bool _defaultValue;

  const BoolNotificationSetting(this._key, {bool defaultValue = false})
    : _defaultValue = defaultValue;

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? _defaultValue;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

const hadithNotificationSetting = BoolNotificationSetting(
  'hadith_notifications_enabled',
  defaultValue: true,
);
const hourlyZikrNotificationSetting = BoolNotificationSetting(
  'hourly_zikr_notifications_enabled',
  defaultValue: true,
);
const sleepAthkarNotificationSetting = BoolNotificationSetting(
  'sleep_athkar_notifications_enabled',
  defaultValue: true,
);
const jumaaAthkarNotificationSetting = BoolNotificationSetting(
  'jumaa_athkar_notifications_enabled',
  defaultValue: true,
);

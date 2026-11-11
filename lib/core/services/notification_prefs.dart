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

/// A wall-clock time of day stored as minutes since midnight.
class ReminderTime {
  final int minutes;
  const ReminderTime(this.minutes);
  int get hour => (minutes ~/ 60) % 24;
  int get minute => minutes % 60;

  /// "HH:mm" (24-hour), e.g. "07:30".
  String format() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// User-chosen timing for the reminders that run on a fixed clock schedule:
/// how often the zikr reminder repeats and between which hours, and when
/// the sleep athkar and Jumu'ah reminders fire.
class ReminderSchedulePrefs {
  static const _kZikrInterval = 'zikr_interval_minutes';
  static const _kZikrStart = 'zikr_window_start';
  static const _kZikrEnd = 'zikr_window_end';
  static const _kSleepTime = 'sleep_reminder_time';
  static const _kJumaaTime = 'jumaa_reminder_time';

  /// Interval choices offered in Settings, in minutes.
  static const zikrIntervalChoices = [15, 30, 60, 120, 180];

  static Future<int> zikrIntervalMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_kZikrInterval) ?? 60;
    return zikrIntervalChoices.contains(v) ? v : 60;
  }

  static Future<void> setZikrIntervalMinutes(int v) async =>
      (await SharedPreferences.getInstance()).setInt(_kZikrInterval, v);

  /// First reminder of the day (default 07:00).
  static Future<ReminderTime> zikrStart() async => ReminderTime(
    (await SharedPreferences.getInstance()).getInt(_kZikrStart) ?? 7 * 60,
  );

  /// Reminders stop after this time (default 22:00). Earlier than or equal
  /// to [zikrStart] means the window runs past midnight.
  static Future<ReminderTime> zikrEnd() async => ReminderTime(
    (await SharedPreferences.getInstance()).getInt(_kZikrEnd) ?? 22 * 60,
  );

  static Future<void> setZikrStart(ReminderTime t) async =>
      (await SharedPreferences.getInstance()).setInt(_kZikrStart, t.minutes);

  static Future<void> setZikrEnd(ReminderTime t) async =>
      (await SharedPreferences.getInstance()).setInt(_kZikrEnd, t.minutes);

  /// Sleep athkar reminder (default 22:00).
  static Future<ReminderTime> sleepTime() async => ReminderTime(
    (await SharedPreferences.getInstance()).getInt(_kSleepTime) ?? 22 * 60,
  );

  static Future<void> setSleepTime(ReminderTime t) async =>
      (await SharedPreferences.getInstance()).setInt(_kSleepTime, t.minutes);

  /// Friday Jumu'ah sunan reminder (default 10:00).
  static Future<ReminderTime> jumaaTime() async => ReminderTime(
    (await SharedPreferences.getInstance()).getInt(_kJumaaTime) ?? 10 * 60,
  );

  static Future<void> setJumaaTime(ReminderTime t) async =>
      (await SharedPreferences.getInstance()).setInt(_kJumaaTime, t.minutes);
}

const fastingReminderSetting = BoolNotificationSetting(
  'fasting_reminders_enabled',
);

const ayahOfDayNotificationSetting = BoolNotificationSetting(
  'ayah_of_day_notifications_enabled',
);

const readingReminderSetting = BoolNotificationSetting(
  'reading_reminder_enabled',
);
const hifzReminderSetting = BoolNotificationSetting('hifz_reminder_enabled');

/// Times for the reading-plan and Hifz-review daily reminders.
class PlanReminderPrefs {
  static const _kReading = 'reading_reminder_time';
  static const _kHifz = 'hifz_reminder_time';

  static Future<ReminderTime> readingTime() async => ReminderTime(
    (await SharedPreferences.getInstance()).getInt(_kReading) ?? 20 * 60,
  );
  static Future<void> setReadingTime(ReminderTime t) async =>
      (await SharedPreferences.getInstance()).setInt(_kReading, t.minutes);

  static Future<ReminderTime> hifzTime() async => ReminderTime(
    (await SharedPreferences.getInstance()).getInt(_kHifz) ?? 18 * 60,
  );
  static Future<void> setHifzTime(ReminderTime t) async =>
      (await SharedPreferences.getInstance()).setInt(_kHifz, t.minutes);
}

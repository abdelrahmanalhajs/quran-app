import 'package:audio_session/audio_session.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:just_audio/just_audio.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../../data/hadith_repository.dart';
import '../constants/athan.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static const int _dailyHadithId = 1001;
  static const int _hourlyZikrId = 1002;
  // Prayer athan ids: 2001 (fajr) .. 2005 (isha), one per entry in kPrayerNotificationNames.
  static const int _athanIdBase = 2001;

  static final AudioPlayer _athanPlayer = AudioPlayer();

  static const List<Map<String, String>> _zikrPhrases = [
    {'ar': 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ', 'en': 'Glory be to Allah and praise be to Him.'},
    {'ar': 'لَا إِلَهَ إِلَّا اللَّهُ', 'en': 'There is no deity except Allah.'},
    {'ar': 'اللَّهُ أَكْبَرُ', 'en': 'Allah is the Greatest.'},
    {'ar': 'الْحَمْدُ لِلَّهِ', 'en': 'Praise be to Allah.'},
    {'ar': 'أَسْتَغْفِرُ اللَّهَ', 'en': 'I seek the forgiveness of Allah.'},
    {'ar': 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ', 'en': 'There is no power and no strength except with Allah.'},
    {'ar': 'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ', 'en': 'Allah is sufficient for me; there is no deity except Him.'},
  ];

  static Future<void> init() async {
    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Defaults to UTC if the device timezone can't be resolved.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  static void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == kAthanMakkah.id) {
      playAthan(kAthanMakkah);
    } else if (payload == kAthanMadina.id) {
      playAthan(kAthanMadina);
    }
  }

  /// Plays the full athan recording in-app. Used as a fallback on platforms
  /// (iOS) where the notification's own alert sound can't carry the full
  /// multi-minute recording, and as a manual replay action everywhere.
  static Future<void> playAthan(AthanOption athan) async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    await _athanPlayer.setAsset(athan.assetPath);
    await _athanPlayer.play();
  }

  static bool get isAthanPlaying => _athanPlayer.playing;

  /// Stops the in-app athan playback. Called whenever the user interacts
  /// with any button while the real prayer-time athan is sounding, so it
  /// doubles as a "dismiss" action without needing a dedicated stop button.
  static Future<void> stopAthan() => _athanPlayer.stop();

  static Future<bool> requestPermission() async {
    final androidGranted = await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    final iosGranted = await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return (androidGranted ?? true) && (iosGranted ?? true);
  }

  static Future<void> scheduleDailyHadith({int hour = 8, int minute = 0, bool arabic = false}) async {
    final repo = HadithRepository();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final hadith = await repo.getHadithForDay(tomorrow);

    await _plugin.zonedSchedule(
      _dailyHadithId,
      arabic ? 'حديث اليوم' : 'Hadith of the Day',
      arabic ? hadith.ar : hadith.en,
      _nextInstanceOf(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_hadith',
          'Daily Hadith',
          channelDescription: 'A new hadith every day',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      matchDateTimeComponents: DateTimeComponents.time,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelDailyHadith() => _plugin.cancel(_dailyHadithId);

  static Future<void> scheduleHourlyZikr({bool arabic = true}) async {
    final phrase = _zikrPhrases[DateTime.now().hour % _zikrPhrases.length];
    await _plugin.periodicallyShow(
      _hourlyZikrId,
      arabic ? 'تذكير بالذكر' : 'Zikr Reminder',
      arabic ? phrase['ar'] : phrase['en'],
      RepeatInterval.hourly,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'hourly_zikr',
          'Hourly Zikr',
          channelDescription: 'A short remembrance of Allah every hour',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> cancelHourlyZikr() => _plugin.cancel(_hourlyZikrId);

  /// Schedules a notification for each of today's remaining prayer times
  /// (Fajr, Dhuhr, Asr, Maghrib, Isha), using [athan]'s recording as the
  /// Android notification-channel sound (Android has no length limit on
  /// custom channel sounds, so the full athan plays automatically). iOS caps
  /// custom alert sounds at ~30s, so iOS uses the default system sound and
  /// relies on the user tapping the notification to hear the full athan via
  /// [playAthan]. Times are strings like "04:09" in the device's local time,
  /// as returned by PrayerRepository. Call this again whenever the day's
  /// prayer times are refreshed (times shift daily) or the chosen athan changes.
  static Future<void> schedulePrayerAthans({
    required Map<String, String> times,
    required AthanOption athan,
    required bool arabic,
  }) async {
    await cancelPrayerAthans();

    final labelsAr = {
      'fajr': 'الفجر',
      'dhuhr': 'الظهر',
      'asr': 'العصر',
      'maghrib': 'المغرب',
      'isha': 'العشاء',
    };
    final labelsEn = {
      'fajr': 'Fajr',
      'dhuhr': 'Dhuhr',
      'asr': 'Asr',
      'maghrib': 'Maghrib',
      'isha': 'Isha',
    };

    for (var i = 0; i < kPrayerNotificationNames.length; i++) {
      final key = kPrayerNotificationNames[i];
      final timeStr = times[key];
      if (timeStr == null) continue;
      final parts = timeStr.split(':');
      if (parts.length != 2) continue;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;

      final scheduled = _nextInstanceOf(hour, minute);
      final label = arabic ? labelsAr[key]! : labelsEn[key]!;

      await _plugin.zonedSchedule(
        _athanIdBase + i,
        arabic ? 'حان وقت صلاة $label' : 'It is time for $label prayer',
        arabic ? athan.nameAr : athan.nameEn,
        scheduled,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'athan_${athan.id}',
            arabic ? 'أذان الصلاة' : 'Prayer Athan',
            channelDescription: arabic
                ? 'إشعار بدخول وقت الصلاة مع صوت الأذان'
                : 'Prayer time notification with athan sound',
            importance: Importance.max,
            priority: Priority.high,
            sound: RawResourceAndroidNotificationSound(athan.androidRawResource),
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
          iOS: const DarwinNotificationDetails(
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        matchDateTimeComponents: DateTimeComponents.time,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: athan.id,
      );
    }
  }

  static Future<void> cancelPrayerAthans() async {
    for (var i = 0; i < kPrayerNotificationNames.length; i++) {
      await _plugin.cancel(_athanIdBase + i);
    }
  }

  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

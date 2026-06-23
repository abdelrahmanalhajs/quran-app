import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../../data/hadith_repository.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static const int _dailyHadithId = 1001;
  static const int _hourlyZikrId = 1002;

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
    );
  }

  static Future<bool> requestPermission() async {
    final androidGranted = await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    final iosGranted = await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return (androidGranted ?? true) && (iosGranted ?? true);
  }

  static Future<void> scheduleDailyHadith({int hour = 8, int minute = 0}) async {
    final repo = HadithRepository();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final hadith = await repo.getHadithForDay(tomorrow);

    await _plugin.zonedSchedule(
      _dailyHadithId,
      'Hadith of the Day',
      hadith.en,
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

  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

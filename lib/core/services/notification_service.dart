import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:provider/provider.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../../data/hadith_repository.dart';
import '../../state/audio_provider.dart';
import '../../state/navigation_provider.dart';
import '../constants/athan.dart';

/// Payload values used to route a notification tap to the right page — see
/// [NotificationService._onNotificationTapped]. Distinct from the old scheme
/// of using the athan id as the payload, which made tapping a prayer
/// notification replay the athan instead of opening the app on the prayer
/// page (the actual expected behavior).
class _NotifRoute {
  static const prayer = 'route:prayer';
  static const hadith = 'route:hadith';
  static const sleep = 'route:sleep';
  static const jumaa = 'route:jumaa';
  static const morningAthkar = 'route:morning_athkar';
  static const eveningAthkar = 'route:evening_athkar';
  static const athkar = 'route:athkar';
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const int _dailyHadithId = 1001;
  static const int _hourlyZikrId = 1002;
  static const int _sleepReminderId = 1003;
  static const int _jumaaReminderId = 1004;
  static const int _morningAthkarReminderId = 1005;
  static const int _eveningAthkarReminderId = 1006;
  // Prayer athan ids: 2001 (fajr) .. 2005 (isha), one per entry in kPrayerNotificationNames.
  static const int _athanIdBase = 2001;

  /// Set from main() before the app's first frame, so a notification tap can
  /// switch tabs/sub-tabs without any screen needing to hold its own
  /// reference to the navigator.
  static GlobalKey<NavigatorState>? navigatorKey;

  /// Set from main() alongside [navigatorKey] — [playAthan] plays through
  /// this same shared player rather than one of its own, since
  /// [JustAudioBackground] only ever supports a single live [AudioPlayer]
  /// for the whole app; see [AudioProvider.playOneShot]'s doc comment.
  static AudioProvider? audioProvider;

  // Holds a route that arrived before [navigatorKey] had a live context —
  // either a cold-start launch (app was terminated, see [init]) or a tap
  // that raced the very first frame. [consumePendingRoute] applies it once
  // HomeShell has built.
  static String? _pendingPayload;

  // Exact alarms (SCHEDULE_EXACT_ALARM) are not granted by default on
  // Android 13+. Attempting an exact schedule then throws
  // PlatformException(exact_alarms_not_permitted), which previously went
  // unhandled at startup and left the prayer-athan and reminder
  // notifications never scheduled at all. Resolved once in [init]: use exact
  // alarms when the OS allows them, otherwise fall back to inexact (still
  // fires, just not to the exact minute) so scheduling always succeeds.
  static AndroidScheduleMode _scheduleMode =
      AndroidScheduleMode.exactAllowWhileIdle;

  static const List<Map<String, String>> _zikrPhrases = [
    {
      'ar': 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
      'en': 'Glory be to Allah and praise be to Him.',
    },
    {
      'ar': 'لَا إِلَهَ إِلَّا اللَّهُ',
      'en': 'There is no deity except Allah.',
    },
    {'ar': 'اللَّهُ أَكْبَرُ', 'en': 'Allah is the Greatest.'},
    {'ar': 'الْحَمْدُ لِلَّهِ', 'en': 'Praise be to Allah.'},
    {'ar': 'أَسْتَغْفِرُ اللَّهَ', 'en': 'I seek the forgiveness of Allah.'},
    {
      'ar': 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
      'en': 'There is no power and no strength except with Allah.',
    },
    {
      'ar': 'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ',
      'en': 'Allah is sufficient for me; there is no deity except Him.',
    },
  ];

  static Future<void> init() async {
    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // FlutterTimezone can fail to resolve a named IANA zone (seen on some
      // emulators/web). Silently falling back to UTC would schedule every
      // prayer/athkar notification at the wrong wall-clock time for anyone
      // not in UTC, so fall back to a fixed-offset zone built from the
      // device's own UTC offset instead — still correct local wall-clock
      // time, just without DST transition data.
      final offsetMs = DateTime.now().timeZoneOffset.inMilliseconds;
      tz.setLocalLocation(
        tz.Location('Fixed', const [], const [], [
          tz.TimeZone(offsetMs, isDst: false, abbreviation: 'LOC'),
        ]),
      );
    }

    // The app's own launcher icon resource is named `launcher_icon`, not the
    // Flutter-default `ic_launcher` (see flutter_launcher_icons config in
    // pubspec.yaml) — referencing the default name here throws an unhandled
    // PlatformException(invalid_icon) at startup, before the app ever
    // renders anything, since that resource doesn't exist.
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final canExact = await android?.canScheduleExactNotifications() ?? true;
    if (canExact == false) {
      _scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
    }

    // The app may have been launched (from terminated, not just background)
    // by tapping a notification — that doesn't fire
    // onDidReceiveNotificationResponse, so it has to be checked explicitly.
    // navigatorKey isn't set yet at this point in main(), so the route is
    // stashed and applied later via [consumePendingRoute].
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _pendingPayload = launchDetails?.notificationResponse?.payload;
    }
  }

  static void _onNotificationTapped(NotificationResponse response) {
    _route(response.payload);
  }

  /// Switches tabs (and, for athkar, the right sub-tab) for the page a
  /// notification's payload identifies. Tapping the prayer/athan
  /// notification used to replay the athan instead of navigating anywhere —
  /// this replaces that with opening the prayer page, which is what the tap
  /// should actually do.
  static void _route(String? payload) {
    if (payload == null) return;
    final context = navigatorKey?.currentContext;
    if (context == null) {
      _pendingPayload = payload;
      return;
    }
    navigatorKey?.currentState?.popUntil((route) => route.isFirst);
    final nav = context.read<HomeNavigationProvider>();
    switch (payload) {
      case _NotifRoute.prayer:
        nav.setIndex(1);
      case _NotifRoute.hadith:
        nav.setIndex(3);
      case _NotifRoute.sleep:
        nav.goToAthkarTab(3);
      case _NotifRoute.jumaa:
        nav.goToAthkarTab(4);
      case _NotifRoute.morningAthkar:
        nav.goToAthkarTab(0);
      case _NotifRoute.eveningAthkar:
        nav.goToAthkarTab(1);
      case _NotifRoute.athkar:
        nav.setIndex(2);
    }
  }

  /// Call once HomeShell has built (a post-frame callback in its initState)
  /// so a route from a cold-start notification launch, or a tap that raced
  /// the first frame, still gets applied.
  static void consumePendingRoute() {
    final payload = _pendingPayload;
    if (payload == null) return;
    _pendingPayload = null;
    _route(payload);
  }

  static String _athanOneShotId(AthanOption athan) => 'athan_${athan.id}';

  /// Plays the full athan recording in-app. Used as a fallback on platforms
  /// (iOS) where the notification's own alert sound can't carry the full
  /// multi-minute recording, and as a manual replay action everywhere. Plays
  /// through the shared [audioProvider] rather than a player of its own —
  /// see [AudioProvider.playOneShot]'s doc comment for why.
  static Future<void> playAthan(AthanOption athan) async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    await audioProvider?.playOneShot(
      assetPath: athan.assetPath,
      id: _athanOneShotId(athan),
      title: athan.nameEn,
    );
  }

  static bool get isAthanPlaying =>
      audioProvider != null &&
      kAthanOptions.any(
        (a) => audioProvider!.isOneShotPlaying(_athanOneShotId(a)),
      );

  /// Stops the in-app athan playback. Called whenever the user interacts
  /// with any button while the real prayer-time athan is sounding, so it
  /// doubles as a "dismiss" action without needing a dedicated stop button.
  static Future<void> stopAthan() async => audioProvider?.stop();

  static Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final androidGranted = await android?.requestNotificationsPermission();
    final iosGranted = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Notification permission alone doesn't guarantee the athan/athkar
    // notifications fire exactly on time: without the exact-alarm permission
    // (Android 13+) the OS only delivers an "inexact" schedule, which can
    // run several minutes late; this prompts the system settings screen so
    // the user can grant it, then re-checks so this session's scheduling
    // actually uses the precise mode it just got. Network connectivity
    // plays no part in any of this — prayer times and the athan are
    // entirely local (see PrayerRepository/this file), so once an exact
    // alarm is scheduled it fires on time with or without internet.
    if (android != null) {
      final canExact = await android.canScheduleExactNotifications() ?? true;
      if (!canExact) {
        await android.requestExactAlarmsPermission();
        final canExactNow =
            await android.canScheduleExactNotifications() ?? true;
        _scheduleMode = canExactNow
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle;
      } else {
        _scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
      }

      // Doze/App Standby can defer even an "exact" alarm by several
      // minutes while the device is idle and the app isn't whitelisted —
      // the other half of "azan notification arrives late". Requests the
      // OS dialog to exempt this app; a no-op if already granted or denied
      // before (won't re-prompt endlessly).
      if (!kIsWeb) {
        final batteryStatus = await ph.Permission.ignoreBatteryOptimizations
            .status;
        if (!batteryStatus.isGranted) {
          await ph.Permission.ignoreBatteryOptimizations.request();
        }
      }
    }

    return (androidGranted ?? true) && (iosGranted ?? true);
  }

  static Future<void> scheduleDailyHadith({
    int hour = 16,
    int minute = 0,
    bool arabic = false,
  }) async {
    final repo = HadithRepository();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final hadith = await repo.getHadithForDay(tomorrow);

    final title = arabic ? 'حديث اليوم' : 'Hadith of the Day';
    final body =
        '${arabic ? hadith.ar : hadith.en}\n\n'
        '${arabic ? hadith.sourceAr : hadith.source}';

    await _plugin.zonedSchedule(
      _dailyHadithId,
      title,
      body,
      _nextInstanceOf(hour, minute),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_hadith',
          'Daily Hadith',
          channelDescription: 'A new hadith every day',
          importance: Importance.high,
          priority: Priority.high,
          // Without this, Android collapses the notification to a single
          // truncated line — the full hadith only became visible on manual
          // expand. BigTextStyle shows the whole text right away.
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
          ),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      matchDateTimeComponents: DateTimeComponents.time,
      androidScheduleMode: _scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: _NotifRoute.hadith,
    );
  }

  static Future<void> cancelDailyHadith() => _plugin.cancel(_dailyHadithId);

  // 24 ids (one per hour of the day) so each hour can carry its own zikr,
  // cycling through [_zikrPhrases]. periodicallyShow can't do this — it
  // repeats one fixed message — so a different remembrance every hour means
  // scheduling a separate daily-repeating notification at each hour.
  static const int _hourlyZikrIdBase = 1100;

  static Future<void> scheduleHourlyZikr({bool arabic = true}) async {
    await cancelHourlyZikr();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'hourly_zikr',
        'Hourly Zikr',
        channelDescription: 'A short remembrance of Allah every hour',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    for (var hour = 0; hour < 24; hour++) {
      final phrase = _zikrPhrases[hour % _zikrPhrases.length];
      await _plugin.zonedSchedule(
        _hourlyZikrIdBase + hour,
        arabic ? 'تذكير بالذكر' : 'Zikr Reminder',
        arabic ? phrase['ar'] : phrase['en'],
        _nextInstanceOf(hour, 0),
        details,
        matchDateTimeComponents: DateTimeComponents.time,
        androidScheduleMode: _scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: _NotifRoute.athkar,
      );
    }
  }

  static Future<void> cancelHourlyZikr() async {
    // Cancel the old single periodic id too, for users upgrading from the
    // previous one-message-an-hour implementation.
    await _plugin.cancel(_hourlyZikrId);
    for (var hour = 0; hour < 24; hour++) {
      await _plugin.cancel(_hourlyZikrIdBase + hour);
    }
  }

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
        arabic ? 'حان الآن موعد أذان $label' : 'It is now time for $label prayer',
        null,
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
            sound: RawResourceAndroidNotificationSound(
              athan.androidRawResource,
            ),
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
          iOS: DarwinNotificationDetails(
            // Without this the athan never sounded on iOS: the notification
            // fired with the system's default alert tone instead. iOS can't
            // use the Flutter-asset MP3 the in-app player uses — it needs a
            // CAF/AIFF/WAV in the app bundle, under 30s — so each athan
            // ships a trimmed bundle copy alongside it (see
            // [AthanOption.iosNotificationSound]).
            sound: athan.iosNotificationSound,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        matchDateTimeComponents: DateTimeComponents.time,
        androidScheduleMode: _scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: _NotifRoute.prayer,
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
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Next occurrence of [weekday] (1=Monday .. 7=Sunday, per [DateTime])
  /// at the given time.
  static tz.TZDateTime _nextInstanceOfWeekday(
    int weekday,
    int hour,
    int minute,
  ) {
    var scheduled = _nextInstanceOf(hour, minute);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Daily reminder (default 10 PM) to recite the sleep athkar before bed.
  static Future<void> scheduleSleepReminder({
    int hour = 22,
    int minute = 0,
    bool arabic = false,
  }) async {
    await _plugin.zonedSchedule(
      _sleepReminderId,
      arabic ? 'أذكار النوم' : 'Sleep Athkar',
      arabic
          ? 'لا تنس أذكار النوم قبل أن تأوي إلى فراشك'
          : "Don't forget your sleep athkar before going to bed",
      _nextInstanceOf(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'sleep_reminder',
          'Sleep Athkar Reminder',
          channelDescription: 'A nightly reminder to recite the sleep athkar',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      matchDateTimeComponents: DateTimeComponents.time,
      androidScheduleMode: _scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: _NotifRoute.sleep,
    );
  }

  static Future<void> cancelSleepReminder() => _plugin.cancel(_sleepReminderId);

  /// Weekly reminder (Friday, default 10 AM) to read the Jumu'ah sunan
  /// (including Surah Al-Kahf and abundant salawat upon the Prophet ﷺ).
  static Future<void> scheduleJumaaReminder({
    int hour = 10,
    int minute = 0,
    bool arabic = false,
  }) async {
    await _plugin.zonedSchedule(
      _jumaaReminderId,
      arabic ? 'التذكير بسنن الجمعة' : "Jumu'ah Sunan Reminder",
      arabic
          ? 'يوم الجمعة المبارك: لا تنس قراءة سورة الكهف والإكثار من الصلاة على النبي ﷺ'
          : "It's Jumu'ah: don't forget to recite Surah Al-Kahf and send abundant blessings upon the Prophet ﷺ",
      _nextInstanceOfWeekday(DateTime.friday, hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'jumaa_reminder',
          "Jumu'ah Sunan Reminder",
          channelDescription: "A weekly Friday reminder for Jumu'ah sunan",
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      androidScheduleMode: _scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: _NotifRoute.jumaa,
    );
  }

  static Future<void> cancelJumaaReminder() => _plugin.cancel(_jumaaReminderId);

  /// Adds [offsetMinutes] to a "HH:mm" time string and returns the
  /// resulting hour/minute, wrapping past midnight if needed.
  static ({int hour, int minute})? _addMinutes(
    String? timeStr,
    int offsetMinutes,
  ) {
    if (timeStr == null) return null;
    final parts = timeStr.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    final total = (hour * 60 + minute + offsetMinutes) % (24 * 60);
    return (hour: total ~/ 60, minute: total % 60);
  }

  /// Schedules a reminder shortly after Fajr to recite the morning athkar,
  /// and another shortly after Asr for the evening athkar — the traditional
  /// timing for each, rather than a fixed clock time. [times] should be the
  /// same map of "HH:mm" prayer times used for [schedulePrayerAthans]; call
  /// this again whenever those times are refreshed.
  static Future<void> scheduleAthkarPrayerReminders({
    required Map<String, String> times,
    required bool arabic,
  }) async {
    final morning = _addMinutes(times['fajr'], 15);
    if (morning != null) {
      await _plugin.zonedSchedule(
        _morningAthkarReminderId,
        arabic ? 'أذكار الصباح' : 'Morning Athkar',
        arabic
            ? 'حان وقت أذكار الصباح بعد صلاة الفجر'
            : "It's time for the morning athkar, after Fajr prayer",
        _nextInstanceOf(morning.hour, morning.minute),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'morning_athkar_reminder',
            'Morning Athkar Reminder',
            channelDescription:
                'A reminder after Fajr to recite the morning athkar',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        matchDateTimeComponents: DateTimeComponents.time,
        androidScheduleMode: _scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: _NotifRoute.morningAthkar,
      );
    }

    final evening = _addMinutes(times['asr'], 15);
    if (evening != null) {
      await _plugin.zonedSchedule(
        _eveningAthkarReminderId,
        arabic ? 'أذكار المساء' : 'Evening Athkar',
        arabic
            ? 'حان وقت أذكار المساء بعد صلاة العصر'
            : "It's time for the evening athkar, after Asr prayer",
        _nextInstanceOf(evening.hour, evening.minute),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'evening_athkar_reminder',
            'Evening Athkar Reminder',
            channelDescription:
                'A reminder after Asr to recite the evening athkar',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        matchDateTimeComponents: DateTimeComponents.time,
        androidScheduleMode: _scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: _NotifRoute.eveningAthkar,
      );
    }
  }

  static Future<void> cancelAthkarPrayerReminders() async {
    await _plugin.cancel(_morningAthkarReminderId);
    await _plugin.cancel(_eveningAthkarReminderId);
  }

}

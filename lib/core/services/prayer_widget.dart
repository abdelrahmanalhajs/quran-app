import 'package:home_widget/home_widget.dart';

/// Pushes the day's prayer times to the home-screen widget on both platforms
/// (Android's [PrayerWidgetProvider] and iOS's WidgetKit `PrayerWidget`
/// extension), which then shows the next prayer and a live countdown to it.
/// The native side picks "next" relative to the current time, so it advances
/// through the day on its own — this just needs to be called whenever the
/// times are (re)computed.
class PrayerWidget {
  static const _androidProvider = 'PrayerWidgetProvider';
  // Must match the widget `kind` in ios/PrayerWidget/PrayerWidget.swift.
  static const _iosWidgetKind = 'PrayerWidget';
  // Must match the App Group in both Runner.entitlements and
  // PrayerWidget.entitlements — it's the shared UserDefaults suite the
  // widget reads these keys from on iOS.
  static const _appGroupId = 'group.com.abdelrahmanalhajs.quranapp';

  static bool _appGroupConfigured = false;

  static const _order = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
  static const _labelsAr = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
  static const _labelsEn = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

  /// [times] maps prayer keys (fajr..isha) to "HH:mm" strings in local time.
  static Future<void> update({
    required Map<String, String> times,
    required bool arabic,
  }) async {
    final values = [for (final k in _order) times[k]];
    if (values.any((v) => v == null)) return;

    final names = arabic ? _labelsAr : _labelsEn;
    try {
      if (!_appGroupConfigured) {
        // On iOS this routes the key/value writes below into the shared App
        // Group UserDefaults the widget extension reads; a no-op on Android.
        await HomeWidget.setAppGroupId(_appGroupId);
        _appGroupConfigured = true;
      }
      await HomeWidget.saveWidgetData('prayer_times', values.join(','));
      await HomeWidget.saveWidgetData('prayer_names', names.join(','));
      await HomeWidget.saveWidgetData(
        'prayer_label',
        arabic ? 'الصلاة القادمة' : 'Next prayer',
      );
      await HomeWidget.saveWidgetData(
        'prayer_placeholder',
        arabic ? 'افتح التطبيق لتحديد موقعك' : 'Open the app to set your location',
      );
      await HomeWidget.updateWidget(
        androidName: _androidProvider,
        iOSName: _iosWidgetKind,
      );
    } catch (_) {
      // No widget added / platform without home widgets — ignore.
    }
  }
}

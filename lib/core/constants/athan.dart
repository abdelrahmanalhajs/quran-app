class AthanOption {
  final String id;
  final String nameAr;
  final String nameEn;
  final String assetPath;

  /// Matches the Android raw resource filename (without extension) in
  /// android/app/src/main/res/raw/, used as the notification channel sound.
  final String androidRawResource;

  /// Filename of the athan bundled in the iOS app bundle (ios/Runner/) for
  /// use as the notification sound. iOS will not play the [assetPath] MP3
  /// for a notification: notification sounds must be a CAF/AIFF/WAV sitting
  /// in the app bundle, and anything past 30 seconds is silently replaced by
  /// the default alert tone — hence a separate, trimmed CAF copy.
  final String iosNotificationSound;

  const AthanOption({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.assetPath,
    required this.androidRawResource,
    required this.iosNotificationSound,
  });
}

const AthanOption kAthanMakkah = AthanOption(
  id: 'makkah',
  nameAr: 'أذان الحرم المكي (مكة)',
  nameEn: 'Masjid al-Haram Athan (Mecca)',
  assetPath: 'assets/audio/adhan_makkah.mp3',
  androidRawResource: 'adhan_makkah',
  iosNotificationSound: 'adhan_makkah.caf',
);

const AthanOption kAthanMadina = AthanOption(
  id: 'madina',
  nameAr: 'أذان المسجد النبوي (المدينة)',
  nameEn: 'Masjid an-Nabawi Athan (Madina)',
  assetPath: 'assets/audio/adhan_madina.mp3',
  androidRawResource: 'adhan_madina',
  iosNotificationSound: 'adhan_madina.caf',
);

const List<AthanOption> kAthanOptions = [kAthanMakkah, kAthanMadina];

const List<String> kPrayerNotificationNames = [
  'fajr',
  'dhuhr',
  'asr',
  'maghrib',
  'isha',
];

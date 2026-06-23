class AthanOption {
  final String id;
  final String nameAr;
  final String nameEn;
  final String assetPath;

  /// Matches the Android raw resource filename (without extension) in
  /// android/app/src/main/res/raw/, used as the notification channel sound.
  final String androidRawResource;

  const AthanOption({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.assetPath,
    required this.androidRawResource,
  });
}

const AthanOption kAthanMakkah = AthanOption(
  id: 'makkah',
  nameAr: 'أذان الحرم المكي (مكة)',
  nameEn: 'Masjid al-Haram Athan (Mecca)',
  assetPath: 'assets/audio/adhan_makkah.mp3',
  androidRawResource: 'adhan_makkah',
);

const AthanOption kAthanMadina = AthanOption(
  id: 'madina',
  nameAr: 'أذان المسجد النبوي (المدينة)',
  nameEn: 'Masjid an-Nabawi Athan (Madina)',
  assetPath: 'assets/audio/adhan_madina.mp3',
  androidRawResource: 'adhan_madina',
);

const List<AthanOption> kAthanOptions = [kAthanMakkah, kAthanMadina];

const List<String> kPrayerNotificationNames = [
  'fajr',
  'dhuhr',
  'asr',
  'maghrib',
  'isha',
];

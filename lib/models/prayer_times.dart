class PrayerTimes {
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;

  PrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  factory PrayerTimes.fromJson(Map<String, dynamic> timings) {
    String clean(String key) => (timings[key] as String).split(' ').first;
    return PrayerTimes(
      fajr: clean('Fajr'),
      sunrise: clean('Sunrise'),
      dhuhr: clean('Dhuhr'),
      asr: clean('Asr'),
      maghrib: clean('Maghrib'),
      isha: clean('Isha'),
    );
  }

  /// The five obligatory prayers (excludes sunrise, which has no athan),
  /// keyed to match [kPrayerNotificationNames].
  Map<String, String> get obligatoryPrayers => {
        'fajr': fajr,
        'dhuhr': dhuhr,
        'asr': asr,
        'maghrib': maghrib,
        'isha': isha,
      };
}

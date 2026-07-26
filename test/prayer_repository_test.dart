import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/data/prayer_repository.dart';

void main() {
  final repo = PrayerRepository();
  final reTime = RegExp(r'^\d{2}:\d{2}$');

  test('computes 5 valid prayer times offline (Mecca)', () {
    final t = repo.getPrayerTimes(21.4225, 39.8262);
    for (final s in [t.fajr, t.sunrise, t.dhuhr, t.asr, t.maghrib, t.isha]) {
      expect(reTime.hasMatch(s), isTrue, reason: 'bad time: $s');
    }
    // times must be strictly increasing through the day
    int m(String s) => int.parse(s.split(':')[0]) * 60 + int.parse(s.split(':')[1]);
    expect(m(t.fajr) < m(t.sunrise), isTrue);
    expect(m(t.sunrise) < m(t.dhuhr), isTrue);
    expect(m(t.dhuhr) < m(t.asr), isTrue);
    expect(m(t.asr) < m(t.maghrib), isTrue);
    expect(m(t.maghrib) < m(t.isha), isTrue);
  });

  test('computes qibla direction offline', () {
    // Cairo -> Kaaba bearing is ~136 degrees
    final dir = repo.getQiblaDirection(30.0444, 31.2357);
    expect(dir, inInclusiveRange(0, 360));
    expect((dir - 136).abs() < 5, isTrue, reason: 'cairo qibla was $dir');
    // Istanbul -> ~151.6
    final ist = repo.getQiblaDirection(41.0082, 28.9784);
    expect((ist - 151.6).abs() < 5, isTrue, reason: 'istanbul qibla was $ist');
  });
}

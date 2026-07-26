import 'package:flutter_test/flutter_test.dart';

import 'package:quran_app/core/constants/reciters.dart';

void main() {
  test('every reciter is configured with a usable surah audio URL', () {
    expect(kReciters, isNotEmpty);
    for (final reciter in kReciters) {
      expect(reciter.audioUrlForSurah(1), startsWith('https://'));
      expect(reciter.audioUrlForSurah(1), endsWith('001.mp3'));
      expect(reciter.surahCount, greaterThan(0));
      expect(reciter.surahCount, lessThanOrEqualTo(114));
    }
  });

  // Reciter ids are persisted in SharedPreferences and used to name offline
  // download folders, so a duplicate would silently cross two reciters' data.
  test('reciter ids are unique', () {
    final ids = kReciters.map((r) => r.id).toList();
    expect(ids.toSet().length, ids.length);
  });
}

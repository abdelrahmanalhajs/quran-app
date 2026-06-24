import 'package:flutter_test/flutter_test.dart';

import 'package:quran_app/core/constants/reciters.dart';

void main() {
  test('all reciters are configured with valid audio URLs', () {
    expect(kReciters.length, 8);
    for (final reciter in kReciters) {
      expect(reciter.audioUrlForSurah(1), startsWith('https://'));
      expect(reciter.audioUrlForSurah(1), endsWith('001.mp3'));
    }
  });
}

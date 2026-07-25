import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/reciters.dart';

void main() {
  group('per-ayah playback support', () {
    test('every reciter that claims ayah support builds a padded URL', () {
      for (final r in kReciters.where((r) => r.supportsAyahPlayback)) {
        // Al-Baqara (2), ayah 3 -> SSSAAA = 002003
        expect(
          r.audioUrlForAyah(2, 3),
          endsWith('002003.mp3'),
          reason: '${r.id} builds a malformed per-ayah URL',
        );
        expect(r.audioUrlForAyah(2, 3), startsWith('https://'));
      }
    });

    test('reciters without a per-ayah source return null and report it', () {
      for (final r in kReciters.where((r) => !r.supportsAyahPlayback)) {
        expect(r.audioUrlForAyah(2, 3), isNull);
      }
    });

    // Regression guard: Naser Al-Qatami shipped without a per-ayah source, so
    // "play from this ayah" silently played the whole surah from its start.
    test('Naser Al-Qatami supports per-ayah playback', () {
      final qatami = kReciters.firstWhere((r) => r.id == 'naser_alqatami');
      expect(qatami.supportsAyahPlayback, isTrue);
    });

    test('only Islam Sobhy still lacks per-ayah audio', () {
      final without =
          kReciters.where((r) => !r.supportsAyahPlayback).map((r) => r.id);
      expect(without, ['islam_sobhy']);
    });
  });
}

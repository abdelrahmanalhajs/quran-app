import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/arabic_numbers.dart';

void main() {
  group('copied ayah text', () {
    test('carries the end-of-ayah rosette, not a bare digit', () {
      final copied = ayahWithEndMarker('ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَـٰلَمِينَ', 2);
      // Arabic-Indic number in plain parentheses, sitting tight to the
      // digits and rendering identically in every font.
      expect(copied.endsWith('(٢)'), isTrue);
      expect(copied.contains('\u06DD'), isFalse);
      expect(copied.contains('\uFD3E'), isFalse);
    });

    test('uses Arabic-Indic digits for multi-digit ayah numbers', () {
      expect(ayahWithEndMarker('نص', 255), endsWith('(٢٥٥)'));
    });

    test('leaves the ayah text itself untouched', () {
      const text = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ';
      expect(ayahWithEndMarker(text, 1), startsWith(text));
    });
  });
}

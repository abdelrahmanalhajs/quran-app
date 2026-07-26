import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/arabic_numbers.dart';

void main() {
  group('copied ayah text', () {
    test('carries the end-of-ayah rosette, not a bare digit', () {
      final copied = ayahWithEndMarker('ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَـٰلَمِينَ', 2);
      // U+06DD is the character that means "ayah sign enclosing this
      // number"; a bare "٢" with no sign at all is the bug.
      expect(copied.endsWith('\u06DD٢'), isTrue);
      expect(copied.contains('\u06DD'), isTrue);
    });

    test('uses Arabic-Indic digits for multi-digit ayah numbers', () {
      expect(ayahWithEndMarker('نص', 255), endsWith('\u06DD٢٥٥'));
    });

    test('leaves the ayah text itself untouched', () {
      const text = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ';
      expect(ayahWithEndMarker(text, 1), startsWith(text));
    });
  });
}

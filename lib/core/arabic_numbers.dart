import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/widgets.dart';

const _arabicIndicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

/// Renders [number] using Arabic-Indic digits (١٢٣...) when the active
/// locale is Arabic, otherwise plain Western digits.
String localizedNumber(BuildContext context, int number) {
  if (context.locale.languageCode != 'ar') return '$number';
  return arabicIndicNumber(number);
}

/// Renders [number] using Arabic-Indic digits (١٢٣...) unconditionally.
String arabicIndicNumber(int number) {
  return number
      .toString()
      .split('')
      .map((d) => _arabicIndicDigits[int.parse(d)])
      .join();
}

/// Converts any Arabic-Indic digits (١٢٣...) in [input] to plain Western
/// digits, leaving every other character untouched — lets user-typed search
/// queries be parsed with `int.tryParse`/[RegExp], which only understand
/// Western digits, regardless of which numeral style the user's keyboard
/// actually produced.
String westernDigits(String input) {
  return input
      .split('')
      .map((c) {
        final i = _arabicIndicDigits.indexOf(c);
        return i == -1 ? c : i.toString();
      })
      .join();
}

/// Diacritics (tashkeel: fatha/damma/kasra/shadda/sukun/tanwin/maddah,
/// U+064B-U+0653), the superscript alef (U+0670), Quranic annotation marks
/// (U+06D6-U+06ED) and tatweel (U+0640) — all stripped before matching
/// search text against the API's surah names, which come back fully
/// diacritized, while real users type plain undiacritized Arabic, so a
/// literal [String.contains] almost never matches otherwise. The
/// Arabic-Indic digit block (U+0660-U+0669) sits right in the middle of
/// this codepoint range and must never be swept up by it — digits are
/// handled separately by [westernDigits].
final RegExp _arabicDiacritics = RegExp(
  '[ً-ٰٓۖ-ۭـ]',
);

/// Alef-with-hamza/wasl forms (U+0623/U+0625/U+0622/U+0671), folded down to
/// the plain alef (U+0627) most people actually type.
final RegExp _arabicAlefVariants = RegExp('[أإآٱ]');

/// Normalizes Arabic text for search matching: strips diacritics/tatweel
/// (see [_arabicDiacritics]) and folds alef variants (see
/// [_arabicAlefVariants]).
String normalizeArabicSearch(String input) {
  return input
      .replaceAll(_arabicDiacritics, '')
      .replaceAll(_arabicAlefVariants, 'ا')
      .trim();
}

/// [text] followed by its ayah number in Arabic-Indic digits in plain
/// parentheses, e.g. "\u0628\u0633\u0645 ... (\u0661)", for copying out of the app.
///
/// Deliberately plain "()" rather than the ornate pair U+FD3E/U+FD3F: those
/// carry wide decorative padding, which leaves the digit looking adrift
/// inside them. Nor U+06DD, the dedicated end-of-ayah sign, which only fonts
/// built for Quranic text shape as an enclosure — in ordinary fonts it draws
/// an empty rosette with the number stranded beside it. Plain parentheses sit
/// tight to the number and render the same way in every font.
///
/// The parentheses mirror automatically in right-to-left text, so "(" is
/// drawn on the right-hand side as Arabic typography expects.
String ayahWithEndMarker(String text, int numberInSurah) =>
    '$text (${arabicIndicNumber(numberInSurah)})';

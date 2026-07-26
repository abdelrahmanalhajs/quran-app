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

/// U+06DD ARABIC END OF AYAH — the rosette an ayah's number sits inside.
///
/// This is the character the Mushaf page's own look is expressing: Unicode
/// defines U+06DD as enclosing the digits that follow it, which is precisely
/// "the ayah sign with its number inside". The page doesn't need it because
/// the KFGQPC font already draws that ornament around bare digits, but
/// copied text is plain — without this character a paste is left with a
/// stray "\u0662" and no sign at all.
///
/// How it *looks* after pasting is up to the receiving app's font: Amiri,
/// Scheherazade and other Quranic fonts shape the number inside the rosette;
/// fonts that don't implement U+06DD shaping draw the rosette and set the
/// number beside it. No choice of characters can force the latter to enclose
/// it — that is a property of the destination's font, not of the text.
const String kEndOfAyahSign = '\u06DD';

/// [text] followed by its end-of-ayah sign and number, exactly in the order
/// the page reads them and with no separator, for copying out of the app.
String ayahWithEndMarker(String text, int numberInSurah) =>
    '$text$kEndOfAyahSign${arabicIndicNumber(numberInSurah)}';

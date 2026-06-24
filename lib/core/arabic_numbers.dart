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

/// Western fraction glyphs for a Hizb-quarter position (1 = start, no
/// fraction; 2 = ¼; 3 = ½; 4 = ¾).
const _westernQuarterMarks = ['', '¼', '½', '¾'];

/// Renders the Hizb-quarter fraction for [quarterInHizb] (1-4) using
/// Arabic-Indic digits (e.g. ١/٤) when the active locale is Arabic — the
/// Unicode ¼ ½ ¾ glyphs always render with Western digit shapes regardless
/// of locale, which looks out of place next to an Arabic-Indic Hizb number.
String localizedQuarterMark(BuildContext context, int quarterInHizb) {
  if (context.locale.languageCode != 'ar') {
    return _westernQuarterMarks[quarterInHizb - 1];
  }
  const numerators = ['', '1', '1', '3'];
  const denominators = ['', '4', '2', '4'];
  final numerator = numerators[quarterInHizb - 1];
  if (numerator.isEmpty) return '';
  return '${arabicIndicNumber(int.parse(numerator))}/${arabicIndicNumber(int.parse(denominators[quarterInHizb - 1]))}';
}

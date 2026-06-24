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

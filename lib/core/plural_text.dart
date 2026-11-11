import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

import 'arabic_numbers.dart';

/// "5 pages" / "٥ صفحات", "صفحتان", "٢١ صفحة" — with Arabic plural forms.
String pagesText(BuildContext context, int n) =>
    'common.pages'.plural(n, args: [localizedNumber(context, n)]);

/// "7 days" / "٧ أيام", "يومان", "٣٠ يومًا" — with Arabic plural forms.
String daysText(BuildContext context, int n) =>
    'common.days'.plural(n, args: [localizedNumber(context, n)]);

import 'package:flutter/widgets.dart';

/// Shortest-side breakpoint (logical pixels) above which a device is
/// treated as a tablet/iPad rather than a phone — matches Material's own
/// medium-breakpoint convention (600dp), so it lines up with the point
/// where a phone-sized bottom nav bar starts looking stretched and reading
/// text starts looking sparse.
const double kTabletBreakpoint = 600;

bool isTablet(BuildContext context) {
  return MediaQuery.sizeOf(context).shortestSide >= kTabletBreakpoint;
}

/// Scales [fontSize] up modestly on tablet-sized screens so Quran text,
/// surah names and athkar text don't look proportionally tiny on a much
/// larger screen — without requiring the user to manually adjust the font
/// size slider every time they open the app on a different device.
double responsiveFontSize(BuildContext context, double fontSize) {
  return isTablet(context) ? fontSize * 1.15 : fontSize;
}

/// Horizontal padding for list/card content: phones keep the original
/// edge-to-edge-ish spacing, tablets get more breathing room instead of
/// content cards sitting flush against [ResponsiveCenter]'s width cap.
double responsiveHorizontalPadding(BuildContext context) {
  return isTablet(context) ? 28 : 16;
}

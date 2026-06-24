import 'package:flutter/widgets.dart';

/// Shortest-side breakpoint (logical pixels) below which a phone is treated
/// as "compact" — small/budget Android phones and an iPhone SE-class
/// screen, where the regular phone padding starts eating a noticeably
/// bigger share of the available reading width than on a typical phone.
const double kCompactPhoneBreakpoint = 360;

/// Shortest-side breakpoint (logical pixels) above which a device is
/// treated as a tablet/iPad rather than a phone — matches Material's own
/// medium-breakpoint convention (600dp), so it lines up with the point
/// where a phone-sized bottom nav bar starts looking stretched and reading
/// text starts looking sparse.
const double kTabletBreakpoint = 600;

bool isCompactPhone(BuildContext context) {
  return MediaQuery.sizeOf(context).shortestSide < kCompactPhoneBreakpoint;
}

bool isTablet(BuildContext context) {
  return MediaQuery.sizeOf(context).shortestSide >= kTabletBreakpoint;
}

/// Scales [fontSize] up modestly on tablet-sized screens so Quran text,
/// surah names and athkar text don't look proportionally tiny on a much
/// larger screen — without requiring the user to manually adjust the font
/// size slider every time they open the app on a different device. Left
/// untouched on compact phones: the Mushaf page's own FittedBox safety net
/// already keeps small/large fonts fitting at any phone size, so scaling
/// it here too would make the font-size picker's 5 sizes mean different
/// actual sizes depending on which phone is used.
double responsiveFontSize(BuildContext context, double fontSize) {
  return isTablet(context) ? fontSize * 1.15 : fontSize;
}

/// Horizontal padding for list/card content: compact phones get tighter
/// padding so reading text isn't squeezed by margins sized for a normal
/// phone, regular phones keep the original spacing, and tablets get more
/// breathing room instead of content cards sitting flush against
/// [ResponsiveCenter]'s width cap.
double responsiveHorizontalPadding(BuildContext context) {
  if (isTablet(context)) return 28;
  if (isCompactPhone(context)) return 12;
  return 16;
}

/// Outer margin around the Mushaf page view itself: tighter on compact
/// phones so the page doesn't lose extra width to margins sized for a
/// normal phone, and a touch more generous on tablets where there's room
/// to spare. The bottom inset stays large enough to clear the floating
/// play button on every tier.
EdgeInsets responsiveMushafPagePadding(BuildContext context) {
  if (isTablet(context)) {
    return const EdgeInsets.fromLTRB(10, 8, 10, 68);
  }
  if (isCompactPhone(context)) {
    return const EdgeInsets.fromLTRB(4, 4, 4, 60);
  }
  return const EdgeInsets.fromLTRB(6, 6, 6, 64);
}

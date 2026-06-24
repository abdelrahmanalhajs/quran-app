import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import '../../core/responsive.dart';
import '../athkar/athkar_screen.dart';
import '../hadith/hadith_screen.dart';
import '../prayer/prayer_screen.dart';
import '../quran/surah_list_screen.dart';
import '../settings/settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    // Reading context.locale here (rather than relying on the bare,
    // context-less `.tr()` calls used throughout the app) is what makes this
    // widget depend on the active locale, so it actually rebuilds when the
    // user switches language in Settings. Without it, easy_localization's
    // locale-change notification never reaches this element, and these
    // screens — built once and kept alive in the IndexedStack below — would
    // go on rendering whichever locale was active the first time each was
    // built, no matter how many times the user switches language afterward.
    // Keying the IndexedStack by locale forces a full, fresh remount of
    // every tab (including AppBar titles and TabBar labels) on switch,
    // instead of relying on each individual screen happening to depend on
    // locale itself.
    final localeKey = ValueKey(context.locale.languageCode);
    final screens = [
      const SurahListScreen(),
      const PrayerScreen(),
      const AthkarScreen(),
      const HadithScreen(),
      const SettingsScreen(),
    ];
    final destinations = [
      (Icons.menu_book, 'nav.quran'.tr()),
      (Icons.explore_outlined, 'nav.prayer'.tr()),
      (Icons.favorite_outline, 'nav.athkar'.tr()),
      (Icons.format_quote, 'nav.hadith'.tr()),
      (Icons.settings_outlined, 'nav.settings'.tr()),
    ];
    final body = IndexedStack(key: localeKey, index: _index, children: screens);

    // A bottom NavigationBar designed for a ~360-430dp-wide phone stretches
    // into oddly wide, sparsely-spaced destinations on a ~1024dp iPad. A
    // side NavigationRail is the standard Material pattern for wide screens
    // and reads naturally at that width instead.
    if (isTablet(context)) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final (icon, label) in destinations)
                  NavigationRailDestination(
                    icon: Icon(icon),
                    label: Text(label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final (icon, label) in destinations)
            NavigationDestination(icon: Icon(icon), label: label),
        ],
      ),
    );
  }
}

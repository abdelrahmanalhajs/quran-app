import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
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

  static const _screens = [
    SurahListScreen(),
    PrayerScreen(),
    AthkarScreen(),
    HadithScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.menu_book), label: 'nav.quran'.tr()),
          NavigationDestination(icon: const Icon(Icons.explore_outlined), label: 'nav.prayer'.tr()),
          NavigationDestination(icon: const Icon(Icons.favorite_outline), label: 'nav.athkar'.tr()),
          NavigationDestination(icon: const Icon(Icons.format_quote), label: 'nav.hadith'.tr()),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), label: 'nav.settings'.tr()),
        ],
      ),
    );
  }
}

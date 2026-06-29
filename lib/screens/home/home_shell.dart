import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../core/services/notification_prefs.dart';
import '../../core/services/notification_service.dart';
import '../../models/surah.dart';
import '../../state/navigation_provider.dart';
import '../../state/quran_provider.dart';
import '../../state/settings_provider.dart';
import '../athkar/athkar_screen.dart';
import '../hadith/hadith_screen.dart';
import '../prayer/prayer_screen.dart';
import '../quran/surah_detail_screen.dart';
import '../quran/surah_list_screen.dart';
import '../settings/settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late HomeNavigationProvider _nav;
  int _lastIndex = 0;

  @override
  void initState() {
    super.initState();
    _nav = context.read<HomeNavigationProvider>();
    _lastIndex = _nav.index;
    // The Quran reading screen's own embedded tab bar (see
    // _MushafPageViewState) switches tabs by calling
    // [HomeNavigationProvider.setIndex] and popping back to this screen,
    // rather than through [_onDestinationSelected] below — this listener
    // is what notices that kind of external switch so resuming into the
    // Quran tab (see [_resumeLastRead]) keeps working from there too.
    _nav.addListener(_handleNavChange);
    if (!kIsWeb) {
      // Each of these notifications is otherwise only (re-)scheduled from
      // inside its Settings toggle's onChanged — so a setting that's
      // enabled by default (daily hadith) or was enabled in a previous
      // session never actually gets scheduled with the OS until the user
      // happens to flip that switch again. Doing it once per app launch
      // here, mirroring how PrayerProvider.load() already self-heals the
      // athan/athkar-prayer reminders, makes "enabled" actually mean
      // scheduled rather than depending on a manual re-toggle.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _rescheduleEnabledNotifications(),
      );
    }
    // Resumes straight into the last-read Mushaf page on a cold start —
    // see [_resumeLastRead] — rather than always opening to the surah
    // list, mirroring what switching back to the Quran tab does within a
    // session (see [_onDestinationSelected]).
    WidgetsBinding.instance.addPostFrameCallback((_) => _resumeLastRead());
    // Applies a route from a notification that launched the app from
    // terminated (didn't fire onDidReceiveNotificationResponse) or raced
    // this very first frame. Runs after [_resumeLastRead] so a notification
    // tap always wins over the last-read-page resume.
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => NotificationService.consumePendingRoute(),
      );
    }
  }

  /// Pushes the last-read surah/page (persisted by
  /// [SettingsProvider.setLastRead] as the user reads) on top of whichever
  /// tab is currently showing, if one was ever recorded. No-ops silently
  /// if the surah no longer resolves (e.g. stale data).
  Future<void> _resumeLastRead() async {
    final settings = context.read<SettingsProvider>();
    final surahNumber = settings.lastReadSurah;
    final page = settings.lastReadPage;
    if (surahNumber == null || page == null) return;

    final list = await context.read<QuranProvider>().repository.getSurahList();
    if (!mounted) return;
    SurahSummary? surah;
    for (final s in list) {
      if (s.number == surahNumber) {
        surah = s;
        break;
      }
    }
    if (surah == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SurahDetailScreen(surah: surah!, startPage: page),
      ),
    );
  }

  void _onDestinationSelected(int i) => _nav.setIndex(i);

  /// Switching back into the Quran tab from a different one should resume
  /// reading rather than always landing on the surah list — the cold-start
  /// case in [initState] only covers app launch, not an in-session tab
  /// switch. Fires for both [_onDestinationSelected] (this screen's own
  /// nav bar/rail) and the reading screen's embedded tab bar, since both
  /// go through [HomeNavigationProvider].
  void _handleNavChange() {
    final newIndex = _nav.index;
    final wasQuranTab = _lastIndex == 0;
    _lastIndex = newIndex;
    if (!wasQuranTab && newIndex == 0) {
      _resumeLastRead();
    }
  }

  @override
  void dispose() {
    _nav.removeListener(_handleNavChange);
    super.dispose();
  }

  Future<void> _rescheduleEnabledNotifications() async {
    final results = await Future.wait([
      hadithNotificationSetting.isEnabled(),
      hourlyZikrNotificationSetting.isEnabled(),
      sleepAthkarNotificationSetting.isEnabled(),
      jumaaAthkarNotificationSetting.isEnabled(),
    ]);
    final [hadithOn, zikrOn, sleepOn, jumaaOn] = results;
    if (!(hadithOn || zikrOn || sleepOn || jumaaOn)) return;

    // A toggle's own onChanged requests permission before scheduling; a
    // setting enabled by default (daily hadith) or from a previous session
    // needs the same request here, on a fresh install, for it to actually
    // have a chance of showing rather than silently scheduling with no
    // permission granted.
    final granted = await NotificationService.requestPermission();
    if (!granted || !mounted) return;

    final arabic = context.locale.languageCode == 'ar';
    if (hadithOn) {
      await NotificationService.scheduleDailyHadith(arabic: arabic);
    }
    if (zikrOn) {
      await NotificationService.scheduleHourlyZikr(arabic: arabic);
    }
    if (sleepOn) {
      await NotificationService.scheduleSleepReminder(arabic: arabic);
    }
    if (jumaaOn) {
      await NotificationService.scheduleJumaaReminder(arabic: arabic);
    }
  }

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
    final index = context.watch<HomeNavigationProvider>().index;
    // Watching SettingsProvider makes HomeShell itself rebuild on a theme
    // change; building the tab screens as non-const instances below then
    // rebuilds each kept-alive tab *in place* under the new theme. Together
    // they make a light<->dark switch repaint hadith/athkar/the Quran list
    // instantly with the new colors, while preserving each tab's state (no
    // remount, no reload, no flash) — the IndexedStack otherwise leaves an
    // offstage tab painted in whichever brightness it was first built under.
    context.watch<SettingsProvider>();
    final localeKey = ValueKey(context.locale.languageCode);
    // Deliberately not const: see the SettingsProvider watch above — these
    // must be fresh instances on each HomeShell rebuild so the kept-alive
    // tabs rebuild in place (and pick up theme changes) instead of being
    // skipped as identical const widgets.
    final screens = [
      SurahListScreen(),
      PrayerScreen(),
      AthkarScreen(),
      HadithScreen(),
      SettingsScreen(),
    ];
    final destinations = [
      (const Icon(Icons.menu_book), 'nav.quran'.tr()),
      (const Icon(Icons.explore_outlined), 'nav.prayer'.tr()),
      // No built-in Material icon for the praying-hands posture, and emoji
      // glyphs render as fixed full-color art rather than picking up
      // [IconTheme]'s color — a plain Text with the emoji, sized to match
      // the other icons, rather than the custom-drawn vector used before.
      (const Text('🙏', style: TextStyle(fontSize: 24)), 'nav.athkar'.tr()),
      (const Icon(Icons.format_quote), 'nav.hadith'.tr()),
      (const Icon(Icons.settings_outlined), 'nav.settings'.tr()),
    ];
    final body = IndexedStack(key: localeKey, index: index, children: screens);

    // A bottom NavigationBar designed for a ~360-430dp-wide phone stretches
    // into oddly wide, sparsely-spaced destinations on a ~1024dp iPad. A
    // side NavigationRail is the standard Material pattern for wide screens
    // and reads naturally at that width instead.
    if (isTablet(context)) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: _onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final (icon, label) in destinations)
                  NavigationRailDestination(icon: icon, label: Text(label)),
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
        selectedIndex: index,
        onDestinationSelected: _onDestinationSelected,
        destinations: [
          for (final (icon, label) in destinations)
            NavigationDestination(icon: icon, label: label),
        ],
      ),
    );
  }
}


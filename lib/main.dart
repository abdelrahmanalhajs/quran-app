import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'screens/home/home_shell.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'state/audio_provider.dart';
import 'state/navigation_provider.dart';
import 'state/prayer_provider.dart';
import 'state/quran_provider.dart';
import 'state/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  if (!kIsWeb) {
    await NotificationService.init();
    // Lets the OS show lock-screen / notification-center play-pause-seek
    // controls for the Quran audio player; has no effect on web.
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.abdelrahmanalhajs.quranapp.audio',
      androidNotificationChannelName: 'Quran audio playback',
      androidNotificationOngoing: true,
      // just_audio_background defaults this to 'mipmap/ic_launcher', which
      // doesn't exist here — the app's launcher resource is `launcher_icon`
      // (see flutter_launcher_icons in pubspec / AndroidManifest). With the
      // default, the media notification posted as soon as any audio plays
      // throws "Invalid notification (no valid small icon)" and crashes the
      // app — which is what happened the moment the athan/Quran audio
      // actually reached playback.
      androidNotificationIcon: 'mipmap/launcher_icon',
    );
  }

  final settings = SettingsProvider();
  await settings.load();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      useOnlyLangCode: true,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider(create: (_) => QuranProvider()),
          ChangeNotifierProvider(create: (_) => AudioProvider()),
          ChangeNotifierProvider(create: (_) => PrayerProvider()),
          ChangeNotifierProvider(create: (_) => HomeNavigationProvider()),
        ],
        child: const QuranApp(),
      ),
    ),
  );
}

/// Android's default [MaterialScrollBehavior] wraps every scrollable in a
/// stretch-on-overscroll indicator that visually expands the page when you
/// scroll past its top/bottom edge — disabled app-wide here since it reads
/// as a glitch on a Mushaf page rather than a deliberate effect.
class _NoOverscrollBehavior extends MaterialScrollBehavior {
  const _NoOverscrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MaterialApp(
      title: 'Quran',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      scrollBehavior: const _NoOverscrollBehavior(),
      home: settings.onboardingDone
          ? const HomeShell()
          : const OnboardingScreen(),
      builder: (context, child) {
        return Listener(
          onPointerDown: (_) {
            if (!kIsWeb && NotificationService.isAthanPlaying) {
              NotificationService.stopAthan();
            }
          },
          child: child!,
        );
      },
    );
  }
}

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'screens/home/home_shell.dart';
import 'state/audio_provider.dart';
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
        ],
        child: const QuranApp(),
      ),
    ),
  );
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
      home: const HomeShell(),
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

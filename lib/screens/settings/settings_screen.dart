import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/athan.dart';
import '../../core/services/athan_settings.dart';
import '../../core/services/notification_service.dart';
import '../../state/prayer_provider.dart';
import '../../state/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _kHadithNotif = 'hadith_notifications_enabled';
  static const _kZikrNotif = 'hourly_zikr_notifications_enabled';
  bool _notifEnabled = true;
  bool _zikrEnabled = false;
  bool _athanEnabled = false;
  AthanOption _athanReciter = kAthanMakkah;

  @override
  void initState() {
    super.initState();
    _loadNotifPref();
  }

  Future<void> _loadNotifPref() async {
    final prefs = await SharedPreferences.getInstance();
    final athanEnabled = await AthanSettings.isEnabled();
    final athanReciter = await AthanSettings.getReciter();
    setState(() {
      _notifEnabled = prefs.getBool(_kHadithNotif) ?? true;
      _zikrEnabled = prefs.getBool(_kZikrNotif) ?? false;
      _athanEnabled = athanEnabled;
      _athanReciter = athanReciter;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isArabic = context.locale.languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(title: Text('settings.title'.tr())),
      body: ListView(
        children: [
          ListTile(
            title: Text('settings.language'.tr()),
            trailing: LanguageToggle(
              isArabic: isArabic,
              onChangedArabic: (isArabic) async {
                await context.setLocale(isArabic ? const Locale('ar') : const Locale('en'));
              },
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('settings.theme'.tr(), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('settings.theme_system'.tr()),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('settings.theme_light'.tr()),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('settings.theme_dark'.tr()),
                    ),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (selection) => settings.setThemeMode(selection.first),
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            title: Text('settings.quran_font_size'.tr()),
            subtitle: Slider(
              min: 18,
              max: 38,
              value: settings.quranFontSize,
              onChanged: (v) => settings.setQuranFontSize(v),
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: Text('settings.notifications'.tr()),
            value: _notifEnabled,
            onChanged: (value) async {
              setState(() => _notifEnabled = value);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(_kHadithNotif, value);
              if (kIsWeb) return;
              if (value) {
                final granted = await NotificationService.requestPermission();
                if (granted) {
                  await NotificationService.scheduleDailyHadith(arabic: isArabic);
                }
              } else {
                await NotificationService.cancelDailyHadith();
              }
            },
          ),
          SwitchListTile(
            title: Text('settings.hourly_zikr'.tr()),
            value: _zikrEnabled,
            onChanged: (value) async {
              setState(() => _zikrEnabled = value);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(_kZikrNotif, value);
              if (kIsWeb) return;
              if (value) {
                final granted = await NotificationService.requestPermission();
                if (granted) {
                  await NotificationService.scheduleHourlyZikr(arabic: isArabic);
                }
              } else {
                await NotificationService.cancelHourlyZikr();
              }
            },
          ),
          const Divider(),
          SwitchListTile(
            title: Text('settings.athan_notifications'.tr()),
            subtitle: Text('settings.athan_notifications_hint'.tr()),
            value: _athanEnabled,
            onChanged: (value) async {
              final prayerProvider = context.read<PrayerProvider>();
              setState(() => _athanEnabled = value);
              await AthanSettings.setEnabled(value);
              if (kIsWeb) return;
              if (value) {
                final granted = await NotificationService.requestPermission();
                if (granted) {
                  await prayerProvider.load(arabicAthanLabels: isArabic);
                }
              } else {
                await NotificationService.cancelPrayerAthans();
              }
            },
          ),
          if (_athanEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: kAthanOptions.map((athan) {
                  final selected = athan.id == _athanReciter.id;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      selected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: selected ? Theme.of(context).colorScheme.primary : null,
                    ),
                    title: Text(isArabic ? athan.nameAr : athan.nameEn),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_circle_outline),
                      tooltip: 'settings.preview_athan'.tr(),
                      onPressed: () => NotificationService.playAthan(athan),
                    ),
                    onTap: () async {
                      final prayerProvider = context.read<PrayerProvider>();
                      setState(() => _athanReciter = athan);
                      await AthanSettings.setReciter(athan);
                      if (kIsWeb) return;
                      await prayerProvider.load(arabicAthanLabels: isArabic);
                    },
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class LanguageToggle extends StatelessWidget {
  final bool isArabic;
  final ValueChanged<bool> onChangedArabic;

  const LanguageToggle({super.key, required this.isArabic, required this.onChangedArabic});

  @override
  Widget build(BuildContext context) {
    return ToggleButtons(
      isSelected: [!isArabic, isArabic],
      onPressed: (index) => onChangedArabic(index == 1),
      borderRadius: BorderRadius.circular(8),
      children: const [
        Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('EN')),
        Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('AR')),
      ],
    );
  }
}

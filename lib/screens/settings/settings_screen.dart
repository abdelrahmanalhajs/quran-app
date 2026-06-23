import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/notification_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadNotifPref();
  }

  Future<void> _loadNotifPref() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifEnabled = prefs.getBool(_kHadithNotif) ?? true;
      _zikrEnabled = prefs.getBool(_kZikrNotif) ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: Text('settings.title'.tr())),
      body: ListView(
        children: [
          ListTile(
            title: Text('settings.language'.tr()),
            trailing: LanguageToggle(
              isArabic: context.locale.languageCode == 'ar',
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
                  await NotificationService.scheduleDailyHadith();
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
              final isArabic = context.locale.languageCode == 'ar';
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

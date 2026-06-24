import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../../core/constants/athan.dart';
import '../../core/responsive.dart';
import '../../core/services/athan_settings.dart';
import '../../core/services/athkar_prayer_reminder_settings.dart';
import '../../core/services/notification_prefs.dart';
import '../../core/services/notification_service.dart';
import '../../state/prayer_provider.dart';
import '../../state/settings_provider.dart';
import '../../widgets/responsive_center.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifEnabled = true;
  bool _zikrEnabled = false;
  bool _sleepEnabled = false;
  bool _jumaaEnabled = false;
  bool _athkarPrayerRemindersEnabled = false;
  bool _athanEnabled = false;
  AthanOption _athanReciter = kAthanMakkah;

  // Separate player for the in-settings athan preview, independent of the
  // real prayer-time athan player, so previewing here never triggers the
  // "stop athan on any tap" behavior used for actual prayer notifications.
  final AudioPlayer _previewPlayer = AudioPlayer();
  String? _previewingAthanId;

  @override
  void initState() {
    super.initState();
    _loadNotifPref();
    _previewPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        setState(() => _previewingAthanId = null);
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePreview(AthanOption athan) async {
    if (_previewingAthanId == athan.id) {
      if (_previewPlayer.playing) {
        await _previewPlayer.pause();
      } else {
        await _previewPlayer.play();
      }
      return;
    }
    setState(() => _previewingAthanId = athan.id);
    await _previewPlayer.setAsset(athan.assetPath);
    await _previewPlayer.play();
  }

  Future<void> _loadNotifPref() async {
    final athanEnabled = await AthanSettings.isEnabled();
    final athanReciter = await AthanSettings.getReciter();
    final athkarPrayerRemindersEnabled =
        await AthkarPrayerReminderSettings.isEnabled();
    final notifEnabled = await hadithNotificationSetting.isEnabled();
    final zikrEnabled = await hourlyZikrNotificationSetting.isEnabled();
    final sleepEnabled = await sleepAthkarNotificationSetting.isEnabled();
    final jumaaEnabled = await jumaaAthkarNotificationSetting.isEnabled();
    setState(() {
      _notifEnabled = notifEnabled;
      _zikrEnabled = zikrEnabled;
      _sleepEnabled = sleepEnabled;
      _jumaaEnabled = jumaaEnabled;
      _athanEnabled = athanEnabled;
      _athanReciter = athanReciter;
      _athkarPrayerRemindersEnabled = athkarPrayerRemindersEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isArabic = context.locale.languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(title: Text('settings.title'.tr())),
      body: ResponsiveCenter(
        child: ListView(
          children: [
            ListTile(
              title: Text('settings.language'.tr()),
              trailing: LanguageToggle(
                isArabic: isArabic,
                onChangedArabic: (isArabic) async {
                  await context.setLocale(
                    isArabic ? const Locale('ar') : const Locale('en'),
                  );
                },
              ),
            ),
            const Divider(),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: responsiveHorizontalPadding(context),
                vertical: 8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'settings.theme'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
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
                    onSelectionChanged: (selection) =>
                        settings.setThemeMode(selection.first),
                  ),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: responsiveHorizontalPadding(context),
                vertical: 8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'settings.quran_font_size'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'settings.quran_font_size_hint'.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _QuranFontSizeDots(
                    value: settings.quranFontSize,
                    onChanged: (v) => settings.setQuranFontSize(v),
                  ),
                ],
              ),
            ),
            const Divider(),
            SwitchListTile(
              title: Text('settings.notifications'.tr()),
              value: _notifEnabled,
              onChanged: (value) async {
                setState(() => _notifEnabled = value);
                await hadithNotificationSetting.setEnabled(value);
                if (kIsWeb) return;
                if (value) {
                  final granted = await NotificationService.requestPermission();
                  if (granted) {
                    await NotificationService.scheduleDailyHadith(
                      arabic: isArabic,
                    );
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
                await hourlyZikrNotificationSetting.setEnabled(value);
                if (kIsWeb) return;
                if (value) {
                  final granted = await NotificationService.requestPermission();
                  if (granted) {
                    await NotificationService.scheduleHourlyZikr(
                      arabic: isArabic,
                    );
                  }
                } else {
                  await NotificationService.cancelHourlyZikr();
                }
              },
            ),
            SwitchListTile(
              title: Text('settings.sleep_athkar_notif'.tr()),
              value: _sleepEnabled,
              onChanged: (value) async {
                setState(() => _sleepEnabled = value);
                await sleepAthkarNotificationSetting.setEnabled(value);
                if (kIsWeb) return;
                if (value) {
                  final granted = await NotificationService.requestPermission();
                  if (granted) {
                    await NotificationService.scheduleSleepReminder(
                      arabic: isArabic,
                    );
                  }
                } else {
                  await NotificationService.cancelSleepReminder();
                }
              },
            ),
            SwitchListTile(
              title: Text('settings.jumaa_athkar_notif'.tr()),
              value: _jumaaEnabled,
              onChanged: (value) async {
                setState(() => _jumaaEnabled = value);
                await jumaaAthkarNotificationSetting.setEnabled(value);
                if (kIsWeb) return;
                if (value) {
                  final granted = await NotificationService.requestPermission();
                  if (granted) {
                    await NotificationService.scheduleJumaaReminder(
                      arabic: isArabic,
                    );
                  }
                } else {
                  await NotificationService.cancelJumaaReminder();
                }
              },
            ),
            SwitchListTile(
              title: Text('settings.athkar_prayer_reminders'.tr()),
              subtitle: Text('settings.athkar_prayer_reminders_hint'.tr()),
              value: _athkarPrayerRemindersEnabled,
              onChanged: (value) async {
                final prayerProvider = context.read<PrayerProvider>();
                setState(() => _athkarPrayerRemindersEnabled = value);
                await AthkarPrayerReminderSettings.setEnabled(value);
                if (kIsWeb) return;
                if (value) {
                  final granted = await NotificationService.requestPermission();
                  if (granted) {
                    await prayerProvider.load(arabicAthanLabels: isArabic);
                  }
                } else {
                  await NotificationService.cancelAthkarPrayerReminders();
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
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text(isArabic ? athan.nameAr : athan.nameEn),
                      trailing: IconButton(
                        icon: Icon(
                          _previewingAthanId == athan.id &&
                                  _previewPlayer.playing
                              ? Icons.pause_circle_outline
                              : Icons.play_circle_outline,
                        ),
                        tooltip: 'settings.preview_athan'.tr(),
                        onPressed: () => _togglePreview(athan),
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
      ),
    );
  }
}

/// 5 tappable dots, growing in size left-to-right, for picking one of
/// [kQuranFontSizeSteps] — a discrete "Aa" size picker instead of a
/// continuous slider, since only these 5 sizes are meaningful here (the
/// first 3 fit the Mushaf page without scrolling, the last 2 don't).
class _QuranFontSizeDots extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _QuranFontSizeDots({required this.value, required this.onChanged});

  static const double _minDotSize = 12;
  static const double _maxDotSize = 28;

  int get _selectedIndex {
    var nearest = 0;
    var nearestDiff = double.infinity;
    for (var i = 0; i < kQuranFontSizeSteps.length; i++) {
      final diff = (kQuranFontSizeSteps[i] - value).abs();
      if (diff < nearestDiff) {
        nearestDiff = diff;
        nearest = i;
      }
    }
    return nearest;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedIndex;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < kQuranFontSizeSteps.length; i++)
          _buildDot(
            context,
            i,
            isSelected: i == selected,
            color: colorScheme.primary,
            unselectedColor: colorScheme.outlineVariant,
          ),
      ],
    );
  }

  Widget _buildDot(
    BuildContext context,
    int index, {
    required bool isSelected,
    required Color color,
    required Color unselectedColor,
  }) {
    final steps = kQuranFontSizeSteps.length;
    final size =
        _minDotSize + (_maxDotSize - _minDotSize) * index / (steps - 1);
    return InkResponse(
      onTap: () => onChanged(kQuranFontSizeSteps[index]),
      radius: 28,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _maxDotSize,
              height: _maxDotSize,
              alignment: Alignment.center,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? color : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? color : unselectedColor,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${index + 1}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isSelected ? color : unselectedColor,
                fontWeight: isSelected ? FontWeight.bold : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LanguageToggle extends StatelessWidget {
  final bool isArabic;
  final ValueChanged<bool> onChangedArabic;

  const LanguageToggle({
    super.key,
    required this.isArabic,
    required this.onChangedArabic,
  });

  @override
  Widget build(BuildContext context) {
    return ToggleButtons(
      isSelected: [!isArabic, isArabic],
      onPressed: (index) => onChangedArabic(index == 1),
      borderRadius: BorderRadius.circular(8),
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('EN'),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('عربي'),
        ),
      ],
    );
  }
}

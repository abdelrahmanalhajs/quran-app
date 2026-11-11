import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/athan.dart';
import '../../core/arabic_numbers.dart';
import '../../core/constants/reciters.dart';
import '../../core/responsive.dart';
import '../../core/services/athan_settings.dart';
import '../../core/services/athkar_prayer_reminder_settings.dart';
import '../../core/services/notification_prefs.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/offline_recitations.dart';
import '../../state/audio_provider.dart';
import '../../state/prayer_provider.dart';
import '../../state/settings_provider.dart';
import '../../widgets/reciter_picker_sheet.dart';
import '../../widgets/responsive_center.dart';
import 'user_guide_screen.dart';

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
  bool _fastingEnabled = false;
  bool _ayahOfDayEnabled = false;
  bool _athkarPrayerRemindersEnabled = false;
  bool _athanEnabled = false;
  AthanOption _athanReciter = kAthanMakkah;
  int _zikrInterval = 60;
  ReminderTime _zikrStart = const ReminderTime(7 * 60);
  ReminderTime _zikrEnd = const ReminderTime(22 * 60);
  ReminderTime _sleepTime = const ReminderTime(22 * 60);
  ReminderTime _jumaaTime = const ReminderTime(10 * 60);

  static String _previewId(AthanOption athan) => 'athan_preview_${athan.id}';

  @override
  void initState() {
    super.initState();
    _loadNotifPref();
  }

  Future<void> _togglePreview(AthanOption athan) async {
    // Plays through the app's one shared [AudioProvider] player rather than
    // a dedicated preview player — [JustAudioBackground] only ever supports
    // a single live [AudioPlayer] for the whole app, so a second instance's
    // first setAudioSource used to throw "supports only a single player
    // instance" and silently never play again for the rest of the session;
    // see [AudioProvider.playOneShot]'s doc comment.
    final audio = context.read<AudioProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await audio.playOneShot(
        assetPath: athan.assetPath,
        id: _previewId(athan),
        title: athan.nameEn,
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text('settings.preview_athan_failed'.tr())),
      );
    }
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
    final fastingEnabled = await fastingReminderSetting.isEnabled();
    final ayahOfDayEnabled = await ayahOfDayNotificationSetting.isEnabled();
    final zikrInterval = await ReminderSchedulePrefs.zikrIntervalMinutes();
    final zikrStart = await ReminderSchedulePrefs.zikrStart();
    final zikrEnd = await ReminderSchedulePrefs.zikrEnd();
    final sleepTime = await ReminderSchedulePrefs.sleepTime();
    final jumaaTime = await ReminderSchedulePrefs.jumaaTime();
    if (!mounted) return;
    setState(() {
      _zikrInterval = zikrInterval;
      _zikrStart = zikrStart;
      _zikrEnd = zikrEnd;
      _sleepTime = sleepTime;
      _jumaaTime = jumaaTime;
      _notifEnabled = notifEnabled;
      _zikrEnabled = zikrEnabled;
      _sleepEnabled = sleepEnabled;
      _jumaaEnabled = jumaaEnabled;
      _fastingEnabled = fastingEnabled;
      _ayahOfDayEnabled = ayahOfDayEnabled;
      _athanEnabled = athanEnabled;
      _athanReciter = athanReciter;
      _athkarPrayerRemindersEnabled = athkarPrayerRemindersEnabled;
    });
  }

  /// "07:30" with Arabic-Indic digits when the app is in Arabic.
  String _timeLabel(ReminderTime t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final s = '$hh:$mm';
    return context.locale.languageCode == 'ar'
        ? s.replaceAllMapped(
            RegExp(r'\d'),
            (m) => arabicIndicNumber(int.parse(m[0]!)),
          )
        : s;
  }

  Future<ReminderTime?> _pickTime(ReminderTime current) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null) return null;
    return ReminderTime(picked.hour * 60 + picked.minute);
  }

  String _intervalLabel(int minutes) => switch (minutes) {
    15 => 'settings.every_15_min'.tr(),
    30 => 'settings.every_30_min'.tr(),
    60 => 'settings.every_1_hour'.tr(),
    120 => 'settings.every_2_hours'.tr(),
    _ => 'settings.every_3_hours'.tr(),
  };

  /// Re-queues the zikr reminders after a timing change, if they're on.
  Future<void> _rescheduleZikr() async {
    if (kIsWeb || !_zikrEnabled || !mounted) return;
    await NotificationService.scheduleHourlyZikr(
      arabic: context.locale.languageCode == 'ar',
    );
  }

  Widget _optionTile({
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsetsDirectional.only(
        start: responsiveHorizontalPadding(context) + 24,
        end: responsiveHorizontalPadding(context),
      ),
      dense: true,
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final audio = context.watch<AudioProvider>();
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
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      // Drop the selected-state check mark: in Material 3 it's
                      // inserted *before* the label on the chosen segment,
                      // stealing width and truncating longer words (e.g.
                      // "System") so the selected option couldn't show its
                      // full word while the others could. Without it every
                      // segment keeps the same width and shows its full label,
                      // selected or not, in both English and Arabic.
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 12,
                        ),
                      ),
                      segments: [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text(
                            'settings.theme_system'.tr(),
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                            softWrap: false,
                          ),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text(
                            'settings.theme_light'.tr(),
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                            softWrap: false,
                          ),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text(
                            'settings.theme_dark'.tr(),
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                            softWrap: false,
                          ),
                        ),
                      ],
                      selected: {settings.themeMode},
                      onSelectionChanged: (selection) =>
                          settings.setThemeMode(selection.first),
                    ),
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
            if (!kIsWeb) ...[
              const Divider(),
              const _OfflineRecitationsSection(),
            ],
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
            if (_zikrEnabled) ...[
              _optionTile(
                title: 'settings.zikr_every'.tr(),
                value: _intervalLabel(_zikrInterval),
                onTap: () async {
                  final choice = await showModalBottomSheet<int>(
                    context: context,
                    showDragHandle: true,
                    builder: (sheetContext) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final m
                              in ReminderSchedulePrefs.zikrIntervalChoices)
                            ListTile(
                              title: Text(_intervalLabel(m)),
                              trailing: m == _zikrInterval
                                  ? const Icon(Icons.check)
                                  : null,
                              onTap: () => Navigator.of(sheetContext).pop(m),
                            ),
                        ],
                      ),
                    ),
                  );
                  if (choice == null || choice == _zikrInterval) return;
                  setState(() => _zikrInterval = choice);
                  await ReminderSchedulePrefs.setZikrIntervalMinutes(choice);
                  await _rescheduleZikr();
                },
              ),
              _optionTile(
                title: 'settings.zikr_from'.tr(),
                value: _timeLabel(_zikrStart),
                onTap: () async {
                  final t = await _pickTime(_zikrStart);
                  if (t == null) return;
                  setState(() => _zikrStart = t);
                  await ReminderSchedulePrefs.setZikrStart(t);
                  await _rescheduleZikr();
                },
              ),
              _optionTile(
                title: 'settings.zikr_to'.tr(),
                value: _timeLabel(_zikrEnd),
                onTap: () async {
                  final t = await _pickTime(_zikrEnd);
                  if (t == null) return;
                  setState(() => _zikrEnd = t);
                  await ReminderSchedulePrefs.setZikrEnd(t);
                  await _rescheduleZikr();
                },
              ),
            ],
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
            if (_sleepEnabled)
              _optionTile(
                title: 'settings.reminder_time'.tr(),
                value: _timeLabel(_sleepTime),
                onTap: () async {
                  final t = await _pickTime(_sleepTime);
                  if (t == null) return;
                  setState(() => _sleepTime = t);
                  await ReminderSchedulePrefs.setSleepTime(t);
                  if (kIsWeb) return;
                  await NotificationService.scheduleSleepReminder(
                    arabic: isArabic,
                  );
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
            if (_jumaaEnabled)
              _optionTile(
                title: 'settings.reminder_time'.tr(),
                value: _timeLabel(_jumaaTime),
                onTap: () async {
                  final t = await _pickTime(_jumaaTime);
                  if (t == null) return;
                  setState(() => _jumaaTime = t);
                  await ReminderSchedulePrefs.setJumaaTime(t);
                  if (kIsWeb) return;
                  await NotificationService.scheduleJumaaReminder(
                    arabic: isArabic,
                  );
                },
              ),
            SwitchListTile(
              title: Text('settings.ayah_of_day_notif'.tr()),
              subtitle: Text('settings.ayah_of_day_notif_hint'.tr()),
              value: _ayahOfDayEnabled,
              onChanged: (value) async {
                setState(() => _ayahOfDayEnabled = value);
                await ayahOfDayNotificationSetting.setEnabled(value);
                if (kIsWeb) return;
                if (value) {
                  final granted = await NotificationService.requestPermission();
                  if (granted) {
                    await NotificationService.scheduleAyahOfDay(
                      arabic: isArabic,
                    );
                  }
                } else {
                  await NotificationService.cancelAyahOfDay();
                }
              },
            ),
            SwitchListTile(
              title: Text('settings.fasting_reminders'.tr()),
              subtitle: Text('settings.fasting_reminders_hint'.tr()),
              value: _fastingEnabled,
              onChanged: (value) async {
                setState(() => _fastingEnabled = value);
                await fastingReminderSetting.setEnabled(value);
                if (kIsWeb) return;
                if (value) {
                  final granted = await NotificationService.requestPermission();
                  if (granted) {
                    await NotificationService.scheduleFastingReminders(
                      arabic: isArabic,
                    );
                  }
                } else {
                  await NotificationService.cancelFastingReminders();
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
                          audio.isOneShotPlaying(_previewId(athan))
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
            const Divider(),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: Text('settings.user_guide'.tr()),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UserGuideScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text('settings.share_app'.tr()),
              subtitle: Text('settings.share_app_subtitle'.tr()),
              onTap: () => _showShareAppSheet(context),
            ),
          ],
        ),
      ),
    );
  }
}

const _kAppStoreUrl = 'https://apps.apple.com/sa/app/quran-awaab-%D9%85%D8%B5%D8%AD%D9%81-%D8%A3%D9%88-%D8%A7%D8%A8/id6802260993';
const _kPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.abdelrahmanalhajs.quranapp&hl=en_GB';

/// Lets the user pick which store link to share: the App Store (iPhone),
/// Google Play (Android), or both.
void _showShareAppSheet(BuildContext context) {
  // iPad presents the share sheet as a popover, which needs an anchor.
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  final intro = 'settings.share_app_intro'.tr();

  Future<void> share(String text) => SharePlus.instance.share(
    ShareParams(text: text, sharePositionOrigin: origin),
  );

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      Widget option(
        IconData icon,
        String title,
        String subtitle,
        String text,
      ) => ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: () {
          Navigator.of(sheetContext).pop();
          share(text);
        },
      );
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'settings.share_app'.tr(),
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            option(
              Icons.apple,
              'settings.share_app_store'.tr(),
              'settings.share_app_store_hint'.tr(),
              '$intro\n\n$_kAppStoreUrl',
            ),
            option(
              Icons.android,
              'settings.share_play_store'.tr(),
              'settings.share_play_store_hint'.tr(),
              '$intro\n\n$_kPlayStoreUrl',
            ),
            option(
              Icons.share_outlined,
              'settings.share_both_stores'.tr(),
              'settings.share_both_stores_hint'.tr(),
              'settings.share_app_text'.tr(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// 3 tappable dots (Small/Medium/Large), growing in size left-to-right, for
/// picking one of [kQuranFontSizeSteps] — a discrete "Aa" size picker
/// instead of a continuous slider, since only these 3 sizes are meaningful
/// here (Small/Medium fill the page without scrolling, Large scrolls).
class _QuranFontSizeDots extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _QuranFontSizeDots({required this.value, required this.onChanged});

  static const double _minDotSize = 12;
  static const double _maxDotSize = 28;

  static const _labelKeys = [
    'settings.quran_font_small',
    'settings.quran_font_medium',
    'settings.quran_font_large',
  ];

  int get _selectedIndex => quranFontSizeStepIndex(value);

  @override
  Widget build(BuildContext context) {
    final selected = _selectedIndex;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
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
              _labelKeys[index].tr(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
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

/// Settings section to download the selected reciter's whole-Quran audio for
/// fully offline playback (see [OfflineRecitations]). Self-contained state so
/// the long-running download and its progress don't live in the big settings
/// State above.
class _OfflineRecitationsSection extends StatefulWidget {
  const _OfflineRecitationsSection();

  @override
  State<_OfflineRecitationsSection> createState() =>
      _OfflineRecitationsSectionState();
}

class _OfflineRecitationsSectionState
    extends State<_OfflineRecitationsSection> {
  String? _reciterId;
  int _downloaded = 0;
  int _total = 114;
  bool _busy = false;
  bool _cancel = false;
  int _progress = 0;

  Future<void> _refresh(Reciter reciter) async {
    final n = await OfflineRecitations.instance.downloadedCount(reciter);
    if (mounted) {
      setState(() {
        _downloaded = n;
        _total = reciter.surahCount;
      });
    }
  }

  Future<void> _download(Reciter reciter) async {
    setState(() {
      _busy = true;
      _cancel = false;
      _progress = _downloaded;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await OfflineRecitations.instance.downloadAll(
        reciter,
        isCancelled: () => _cancel,
        onProgress: (done, total) {
          if (mounted) setState(() => _progress = done);
        },
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text('settings.offline_failed'.tr())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refresh(reciter);
    }
  }

  void _stopDownload() {
    setState(() => _cancel = true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('settings.offline_stopped'.tr())));
  }

  Future<void> _delete(Reciter reciter) async {
    await OfflineRecitations.instance.deleteAll(reciter);
    await _refresh(reciter);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('settings.offline_deleted'.tr())));
  }

  @override
  Widget build(BuildContext context) {
    final reciter = context.watch<SettingsProvider>().reciter;
    if (reciter.id != _reciterId && !_busy) {
      _reciterId = reciter.id;
      _total = reciter.surahCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refresh(reciter);
      });
    }
    final complete = _downloaded >= _total && _total > 0;

    final String subtitle;
    if (_busy) {
      subtitle = 'settings.offline_downloading'.tr(
        args: ['$_progress', '$_total'],
      );
    } else if (complete) {
      subtitle = 'settings.offline_available'.tr(args: ['$_total', '$_total']);
    } else if (_downloaded > 0) {
      subtitle = 'settings.offline_partial'.tr(
        args: ['$_downloaded', '$_total'],
      );
    } else {
      subtitle = 'settings.offline_recitations_hint'.tr();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.download_for_offline_outlined),
          title: Text('settings.offline_recitations'.tr()),
          subtitle: Text(subtitle),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'settings.offline_reciter'.tr(
                    args: [
                      context.locale.languageCode == 'ar'
                          ? reciter.nameAr
                          : reciter.nameEn,
                    ],
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              if (!_busy)
                TextButton(
                  onPressed: () async {
                    final settingsProvider = context.read<SettingsProvider>();
                    final picked = await showReciterPicker(context, reciter);
                    if (picked != null) {
                      await settingsProvider.setReciter(picked);
                    }
                  },
                  child: Text('settings.offline_choose_reciter'.tr()),
                ),
            ],
          ),
        ),
        if (_busy)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LinearProgressIndicator(
              value: _total > 0 ? _progress / _total : null,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              if (_busy)
                OutlinedButton(
                  onPressed: _stopDownload,
                  child: Text('settings.offline_cancel'.tr()),
                )
              else ...[
                FilledButton.icon(
                  onPressed: complete ? null : () => _download(reciter),
                  icon: const Icon(Icons.download, size: 18),
                  label: Text('settings.offline_download'.tr()),
                ),
                if (_downloaded > 0) ...[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => _delete(reciter),
                    child: Text('settings.offline_delete'.tr()),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:provider/provider.dart';
import '../../core/constants/athan.dart';
import '../../core/constants/reciters.dart';
import '../../core/responsive.dart';
import '../../core/services/athan_settings.dart';
import '../../core/services/athkar_prayer_reminder_settings.dart';
import '../../core/services/notification_prefs.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/offline_recitations.dart';
import '../../state/prayer_provider.dart';
import '../../state/settings_provider.dart';
import '../../widgets/reciter_picker_sheet.dart';
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
    // Once JustAudioBackground.init() has run (see main.dart), every
    // AudioSource loaded by any just_audio player must carry a MediaItem
    // tag — a bare setAsset() throws (assert in debug, a null cast in
    // release), which is why the preview produced no sound at all.
    await _previewPlayer.setAudioSource(
      AudioSource.asset(
        athan.assetPath,
        tag: MediaItem(
          id: 'athan_preview_${athan.id}',
          title: athan.nameEn,
        ),
      ),
    );
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
            if (!kIsWeb) ...[
              const Divider(),
              // Collapsed by default so the six test rows don't clutter the
              // settings list — the user expands this only when they actually
              // want to preview a notification.
              ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                tilePadding: EdgeInsets.symmetric(
                  horizontal: responsiveHorizontalPadding(context),
                ),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                leading: const Icon(Icons.notifications_none),
                title: Text(
                  'settings.test_notifications'.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Text('settings.test_notifications_hint'.tr()),
                children: [
                  _TestNotificationTile(
                    label: 'settings.notifications'.tr(),
                    onSend: () => NotificationService.simulateDailyHadith(
                      arabic: isArabic,
                    ),
                  ),
                  _TestNotificationTile(
                    label: 'settings.hourly_zikr'.tr(),
                    onSend: () => NotificationService.simulateHourlyZikr(
                      arabic: isArabic,
                    ),
                  ),
                  _TestNotificationTile(
                    label: 'settings.sleep_athkar_notif'.tr(),
                    onSend: () => NotificationService.simulateSleepReminder(
                      arabic: isArabic,
                    ),
                  ),
                  _TestNotificationTile(
                    label: 'settings.jumaa_athkar_notif'.tr(),
                    onSend: () => NotificationService.simulateJumaaReminder(
                      arabic: isArabic,
                    ),
                  ),
                  _TestNotificationTile(
                    label: 'settings.athkar_prayer_reminders'.tr(),
                    onSend: () =>
                        NotificationService.simulateAthkarPrayerReminder(
                          arabic: isArabic,
                        ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One row in the "Test Notifications" section: a label plus a Send button
/// that requests notification permission (if not yet granted) and then fires
/// that notification immediately so the user can preview it. Confirms with a
/// SnackBar so a silent/heads-up-suppressed notification still gives feedback
/// that the tap did something.
class _TestNotificationTile extends StatelessWidget {
  final String label;
  final Future<void> Function() onSend;

  const _TestNotificationTile({required this.label, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: FilledButton.tonalIcon(
        icon: const Icon(Icons.notifications_active_outlined, size: 18),
        label: Text('settings.test_send'.tr()),
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          final granted = await NotificationService.requestPermission();
          // Without this feedback the button looked broken when notifications
          // were turned off (the common case right after a fresh install,
          // where the OS denies them by default): it would silently do
          // nothing. Tell the user why and offer a one-tap jump to the system
          // settings where they can enable them.
          if (!granted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('settings.test_needs_permission'.tr()),
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'settings.open_settings'.tr(),
                  onPressed: ph.openAppSettings,
                ),
              ),
            );
            return;
          }
          await onSend();
          messenger.showSnackBar(
            SnackBar(
              content: Text('settings.test_sent'.tr()),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }
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

  Future<void> _delete(Reciter reciter) async {
    await OfflineRecitations.instance.deleteAll(reciter);
    await _refresh(reciter);
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
      subtitle = 'settings.offline_partial'.tr(args: ['$_downloaded', '$_total']);
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
          onTap: _busy
              ? null
              : () async {
                  final settingsProvider = context.read<SettingsProvider>();
                  final picked = await showReciterPicker(context, reciter);
                  if (picked != null) {
                    await settingsProvider.setReciter(picked);
                  }
                },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'settings.offline_reciter'.tr(args: [
              context.locale.languageCode == 'ar'
                  ? reciter.nameAr
                  : reciter.nameEn,
            ]),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
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
                  onPressed: () => setState(() => _cancel = true),
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

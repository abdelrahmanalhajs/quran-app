import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/arabic_numbers.dart';
import '../../core/services/notification_prefs.dart';
import '../../core/services/notification_service.dart';
import '../../data/quran_repository.dart';
import '../../state/reading_plan_provider.dart';
import '../../widgets/responsive_center.dart';
import 'surah_detail_screen.dart';
import '../../core/plural_text.dart';

/// Opens the Mushaf at absolute page [page] (1–604).
Future<void> openMushafPage(BuildContext context, int page) async {
  final repo = QuranRepository();
  final ayahs = await repo.getPageAyahs(page);
  if (ayahs.isEmpty || !context.mounted) return;
  final surahs = await repo.getSurahList();
  final surah = surahs.firstWhere((s) => s.number == ayahs.first.surahNumber);
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SurahDetailScreen(surah: surah, startPage: page),
    ),
  );
}

/// "07:30" in the app's digits.
String formatReminderTime(BuildContext context, ReminderTime t) {
  final s = t.format();
  return context.locale.languageCode == 'ar'
      ? s.replaceAllMapped(
          RegExp(r'\d'),
          (m) => arabicIndicNumber(int.parse(m[0]!)),
        )
      : s;
}

const _kGoalChoices = [0, 1, 2, 4, 5, 10, 20];

class ReadingPlanScreen extends StatefulWidget {
  const ReadingPlanScreen({super.key});

  @override
  State<ReadingPlanScreen> createState() => _ReadingPlanScreenState();
}

class _ReadingPlanScreenState extends State<ReadingPlanScreen> {
  bool _reminderOn = false;
  ReminderTime _reminderTime = const ReminderTime(20 * 60);

  @override
  void initState() {
    super.initState();
    () async {
      final on = await readingReminderSetting.isEnabled();
      final t = await PlanReminderPrefs.readingTime();
      if (mounted) {
        setState(() {
          _reminderOn = on;
          _reminderTime = t;
        });
      }
    }();
  }

  String _n(int v) => localizedNumber(context, v);

  String _goalLabel(int g) => switch (g) {
    0 => 'plan.no_goal'.tr(),
    20 => 'plan.one_juz'.tr(),
    _ => pagesText(context, g),
  };

  Future<void> _startKhatma(int days) async {
    final plan = context.read<ReadingPlanProvider>();
    final now = DateTime.now();
    await plan.startKhatma(now.add(Duration(days: days - 1)));
  }

  Future<void> _pickKhatmaDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 3 * 365)),
      initialDate: now.add(const Duration(days: 29)),
    );
    if (picked == null || !mounted) return;
    await context.read<ReadingPlanProvider>().startKhatma(picked);
  }

  Future<void> _setReminder(bool on) async {
    final arabic = context.locale.languageCode == 'ar';
    setState(() => _reminderOn = on);
    await readingReminderSetting.setEnabled(on);
    if (kIsWeb) return;
    if (on) {
      if (await NotificationService.requestPermission()) {
        await NotificationService.scheduleReadingReminder(arabic: arabic);
      }
    } else {
      await NotificationService.cancelReadingReminder();
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<ReadingPlanProvider>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final week = plan.recentDays(7);
    final maxDay = week.fold<int>(1, (a, b) => b > a ? b : a);

    return Scaffold(
      appBar: AppBar(title: Text('plan.title'.tr())),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Today + streak
            Card(
              color: scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'plan.today'.tr(),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                          Text(
                            plan.dailyGoal > 0
                                ? '${_n(plan.pagesToday)} / ${_n(plan.dailyGoal)}'
                                : _n(plan.pagesToday),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'plan.pages_read'.tr(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Icon(
                          Icons.local_fire_department,
                          color: plan.streak > 0
                              ? Colors.deepOrange
                              : scheme.outline,
                          size: 32,
                        ),
                        Text(
                          'plan.streak_days'.tr(
                            args: [daysText(context, plan.streak)],
                          ),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Last 7 days
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'plan.last_7_days'.tr(),
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 80,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final v in week)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      _n(v),
                                      style: theme.textTheme.labelSmall,
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      height: 4 + 50 * v / maxDay,
                                      decoration: BoxDecoration(
                                        color:
                                            plan.dailyGoal > 0 &&
                                                v >= plan.dailyGoal
                                            ? scheme.primary
                                            : scheme.primary.withValues(
                                                alpha: 0.4,
                                              ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Daily goal
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'plan.daily_goal'.tr(),
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final g in _kGoalChoices)
                          ChoiceChip(
                            label: Text(_goalLabel(g)),
                            selected: plan.dailyGoal == g,
                            onSelected: (_) => plan.setDailyGoal(g),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Khatma
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: plan.hasKhatma
                    ? _KhatmaProgress(plan: plan)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'plan.khatma'.tr(),
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'plan.khatma_hint'.tr(),
                            style: theme.textTheme.bodySmall,
                          ),
                          if (plan.khatmasCompleted > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'plan.khatmas_done'.tr(
                                  args: [_n(plan.khatmasCompleted)],
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonal(
                                onPressed: () => _startKhatma(30),
                                child: Text('plan.preset_ramadan'.tr()),
                              ),
                              OutlinedButton(
                                onPressed: () => _startKhatma(7),
                                child: Text(
                                  'plan.in_days'.tr(
                                    args: [daysText(context, 7)],
                                  ),
                                ),
                              ),
                              OutlinedButton(
                                onPressed: () => _startKhatma(60),
                                child: Text(
                                  'plan.in_days'.tr(
                                    args: [daysText(context, 60)],
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.event, size: 18),
                                onPressed: _pickKhatmaDate,
                                label: Text('plan.pick_date'.tr()),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text('plan.reminder'.tr()),
                    value: _reminderOn,
                    onChanged: _setReminder,
                  ),
                  if (_reminderOn)
                    ListTile(
                      title: Text('settings.reminder_time'.tr()),
                      trailing: Text(
                        formatReminderTime(context, _reminderTime),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                      onTap: () async {
                        final arabic = context.locale.languageCode == 'ar';
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: _reminderTime.hour,
                            minute: _reminderTime.minute,
                          ),
                        );
                        if (picked == null) return;
                        final t = ReminderTime(
                          picked.hour * 60 + picked.minute,
                        );
                        setState(() => _reminderTime = t);
                        await PlanReminderPrefs.setReadingTime(t);
                        if (!kIsWeb) {
                          await NotificationService.scheduleReadingReminder(
                            arabic: arabic,
                          );
                        }
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KhatmaProgress extends StatelessWidget {
  final ReadingPlanProvider plan;
  const _KhatmaProgress({required this.plan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String n(int v) => localizedNumber(context, v);
    final next = plan.khatmaNextPage;
    final pct = (plan.khatmaProgress * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'plan.khatma'.tr(),
                style: theme.textTheme.titleSmall,
              ),
            ),
            Text(
              context.locale.languageCode == 'ar' ? '${n(pct)}٪' : '$pct%',
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: plan.khatmaProgress,
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 8),
        if (plan.khatmaComplete)
          Text(
            'plan.khatma_complete'.tr(),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          )
        else ...[
          Text(
            'plan.khatma_status'.tr(
              args: [
                n(plan.khatmaPagesRead),
                n(ReadingPlanProvider.totalPages),
                daysText(context, plan.khatmaDaysLeft),
              ],
            ),
          ),
          Text(
            'plan.khatma_portion'.tr(
              args: [pagesText(context, plan.khatmaDailyPortion)],
            ),
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (next != null)
              FilledButton.icon(
                icon: const Icon(Icons.menu_book, size: 18),
                label: Text('plan.continue_page'.tr(args: [n(next)])),
                onPressed: () => openMushafPage(context, next),
              ),
            OutlinedButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    content: Text(
                      plan.khatmaComplete
                          ? 'plan.finish_confirm'.tr()
                          : 'plan.reset_confirm'.tr(),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text('prayer.cancel'.tr()),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text('plan.yes'.tr()),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await plan.endKhatma(completed: plan.khatmaComplete);
                }
              },
              child: Text(
                plan.khatmaComplete
                    ? 'plan.start_new'.tr()
                    : 'plan.reset_khatma'.tr(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

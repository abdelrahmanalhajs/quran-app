import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/arabic_numbers.dart';
import '../../core/ayah_of_day.dart';
import '../../core/theme/app_theme.dart';
import '../../state/hifz_provider.dart';
import '../../state/reading_plan_provider.dart';
import '../hifz/hifz_screens.dart';
import 'ayah_image_card.dart';
import 'reading_plan_screen.dart';
import 'surah_detail_screen.dart';
import '../../core/plural_text.dart';

/// "Ayah of the day" card shown at the top of the surah list: the day's
/// passage with its reference, a translation in English mode, and actions
/// to open it in the Mushaf or share it as text or as an image card.
class DailyAyahCard extends StatefulWidget {
  const DailyAyahCard({super.key});

  @override
  State<DailyAyahCard> createState() => _DailyAyahCardState();
}

class _DailyAyahCardState extends State<DailyAyahCard> {
  static DateTime? _cachedDay;
  static Future<DailyAyah>? _cached;

  Future<DailyAyah> _today() {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    if (_cachedDay != day || _cached == null) {
      _cachedDay = day;
      _cached = dailyAyahFor(day);
    }
    return _cached!;
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<DailyAyah>(
      future: _today(),
      builder: (context, snap) {
        final d = snap.data;
        if (d == null) return const SizedBox.shrink();
        return Card(
          color: scheme.secondaryContainer.withValues(alpha: 0.45),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SurahDetailScreen(
                  surah: d.surah,
                  startPage: d.ayahs.first.page,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 18, color: scheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'quran.ayah_of_day'.tr(),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: scheme.primary),
                        ),
                      ),
                      IconButton(
                        tooltip: 'quran.share_image'.tr(),
                        icon: const Icon(Icons.image_outlined),
                        onPressed: () => showAyahImageShare(
                          context,
                          textAr: d.textAr,
                          refAr: d.refAr,
                          translation: isArabic ? null : d.textEn,
                          refEn: d.refEn,
                        ),
                      ),
                      IconButton(
                        tooltip: 'quran.share_text'.tr(),
                        icon: const Icon(Icons.share_outlined),
                        onPressed: () => SharePlus.instance.share(
                          ShareParams(
                            text:
                                '${d.textAr}\n\n(${d.refAr})'
                                '${isArabic ? '' : '\n\n${d.textEn}\n(${d.refEn})'}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      d.textAr,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: AppTheme.quranTextStyle(
                        context,
                        fontSize: 20,
                      ).copyWith(height: 2.0),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      isArabic ? d.refAr : d.refEn,
                      textAlign: isArabic ? TextAlign.right : TextAlign.left,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: scheme.outline),
                    ),
                  ),
                  if (!isArabic) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        d.textEn,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Cards shown above the surah list.
class QuranHomeHeader extends StatelessWidget {
  const QuranHomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [DailyAyahCard(), ReadingPlanCard(), HifzDueCard()],
      ),
    );
  }
}

/// Today's reading progress, streak and khatma progress; opens the plan.
class ReadingPlanCard extends StatelessWidget {
  const ReadingPlanCard({super.key});

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<ReadingPlanProvider>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    String n(int v) => localizedNumber(context, v);
    final configured = plan.dailyGoal > 0 || plan.hasKhatma;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ReadingPlanScreen())),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: !configured
              ? Row(
                  children: [
                    Icon(Icons.flag_outlined, color: scheme.primary),
                    const SizedBox(width: 12),
                    Expanded(child: Text('plan.set_up_prompt'.tr())),
                    const Icon(Icons.chevron_right),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.flag, size: 18, color: scheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            plan.dailyGoal > 0
                                ? 'plan.today_of_goal'.tr(
                                    args: [
                                      n(plan.pagesToday),
                                      pagesText(context, plan.dailyGoal),
                                    ],
                                  )
                                : 'plan.today_pages'.tr(
                                    args: [pagesText(context, plan.pagesToday)],
                                  ),
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        if (plan.streak > 0) ...[
                          const Icon(
                            Icons.local_fire_department,
                            size: 18,
                            color: Colors.deepOrange,
                          ),
                          Text(n(plan.streak)),
                        ],
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    if (plan.hasKhatma) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: plan.khatmaProgress,
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.khatmaComplete
                            ? 'plan.khatma_complete'.tr()
                            : 'plan.khatma_portion'.tr(
                                args: [
                                  pagesText(context, plan.khatmaDailyPortion),
                                ],
                              ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// Shown only when memorized surahs are due for review today.
class HifzDueCard extends StatelessWidget {
  const HifzDueCard({super.key});

  @override
  Widget build(BuildContext context) {
    final due = context.watch<HifzProvider>().dueForReview;
    if (due.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      child: ListTile(
        leading: Icon(Icons.school, color: scheme.onTertiaryContainer),
        title: Text(
          'hifz.due_count'.tr(args: [localizedNumber(context, due.length)]),
          style: TextStyle(color: scheme.onTertiaryContainer),
        ),
        trailing: Icon(Icons.chevron_right, color: scheme.onTertiaryContainer),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const HifzHubScreen())),
      ),
    );
  }
}

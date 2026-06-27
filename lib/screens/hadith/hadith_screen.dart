import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import '../../core/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../data/hadith_repository.dart';
import '../../models/hadith.dart';
import '../../widgets/responsive_center.dart';

class HadithScreen extends StatefulWidget {
  const HadithScreen({super.key});

  @override
  State<HadithScreen> createState() => _HadithScreenState();
}

class _HadithScreenState extends State<HadithScreen> {
  final HadithRepository _repo = HadithRepository();
  late Future<List<({DateTime day, Hadith hadith})>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.getRecentHadiths();
  }

  /// "Today"/"Yesterday" for the 2 most recent days, otherwise a plain
  /// numeric date — avoids pulling in intl's locale-aware DateFormat (and
  /// its separate locale-data initialization) just for this.
  String _dayLabel(BuildContext context, DateTime day, int index) {
    if (index == 0) return 'hadith.today'.tr();
    if (index == 1) return 'hadith.yesterday'.tr();
    return '${day.day}/${day.month}/${day.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('hadith.title'.tr())),
      body: FutureBuilder<List<({DateTime day, Hadith hadith})>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data!;
          final isArabic = context.locale.languageCode == 'ar';
          return ResponsiveCenter(
            child: ListView.separated(
              padding: EdgeInsets.all(responsiveHorizontalPadding(context) + 4),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final h = entry.hadith;
                // Pure white on dark / pure black on light for the hadith text,
                // so it reads as crisply as the athkar text instead of the
                // muted tone the theme's onSurface produced for it here.
                final hadithTextColor =
                    Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dayLabel(context, entry.day, index),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              h.ar,
                              textAlign: TextAlign.right,
                              textDirection: TextDirection.rtl,
                              // Use the same Amiri style as the athkar text so
                              // the hadith reads as the same crisp white-on-dark
                              // / black-on-light: at the same onSurface color,
                              // Amiri's heavier strokes read as white while the
                              // thinner default UI font (Tajawal) looked muted
                              // grey against a dark background.
                              style: AppTheme.athkarTextStyle(
                                context,
                                fontSize: 22,
                                height: 1.8,
                              ).copyWith(color: hadithTextColor),
                            ),
                            if (!isArabic) ...[
                              const Divider(height: 28),
                              Text(
                                h.en,
                                textAlign: TextAlign.left,
                                textDirection: TextDirection.ltr,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(color: hadithTextColor),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Icon(Icons.menu_book_outlined, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  '${'hadith.source'.tr()}: ${isArabic ? h.sourceAr : h.source}',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

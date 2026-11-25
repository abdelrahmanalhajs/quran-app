import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/arabic_numbers.dart';
import '../../models/surah.dart';
import '../../state/quran_provider.dart';
import '../../state/settings_provider.dart';

/// Shown each time the app is opened again: lets the user pick which part
/// of the app to go to (Quran, prayer, athkar, hadith, settings). Pops with
/// the chosen [HomeShell] tab index; HomeShell then opens that section where
/// the user last left it (e.g. the last-read Mushaf page).
class StartMenuScreen extends StatelessWidget {
  const StartMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = [
      (Icons.menu_book, 'nav.quran'.tr()),
      (Icons.explore_outlined, 'nav.prayer'.tr()),
      (Icons.favorite_outline, 'nav.athkar'.tr()),
      (Icons.format_quote, 'nav.hadith'.tr()),
      (Icons.settings_outlined, 'nav.settings'.tr()),
    ];
    return PopScope(
      // This is the app's root screen at launch: back leaves the app, as it
      // would from any home screen, rather than revealing the tabs behind.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) SystemNavigator.pop();
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(24),
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        width: 96,
                        height: 96,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'app_name'.tr(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 28),
                  _ResumeCard(onTap: () => Navigator.of(context).pop(0)),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.25,
                    children: [
                      for (var i = 0; i < items.length; i++)
                        _MenuTile(
                          icon: items[i].$1,
                          label: items[i].$2,
                          onTap: () => Navigator.of(context).pop(i),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: scheme.onPrimaryContainer),
            const SizedBox(height: 10),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Continue reading" shortcut: shows the last-read surah and Mushaf page and
/// opens the Quran tab (which resumes at that page). Hidden until the user has
/// read something, or if the surah can't be resolved.
class _ResumeCard extends StatefulWidget {
  const _ResumeCard({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ResumeCard> createState() => _ResumeCardState();
}

class _ResumeCardState extends State<_ResumeCard> {
  Future<List<SurahSummary>>? _surahs;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    if (settings.lastReadSurah != null && settings.lastReadPage != null) {
      _surahs = context.read<QuranProvider>().repository
          .getSurahList()
          .catchError((_) => <SurahSummary>[]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final future = _surahs;
    if (future == null) return const SizedBox.shrink();
    final settings = context.watch<SettingsProvider>();
    final number = settings.lastReadSurah;
    final page = settings.lastReadPage;
    if (number == null || page == null) return const SizedBox.shrink();
    return FutureBuilder<List<SurahSummary>>(
      future: future,
      builder: (context, snap) {
        SurahSummary? surah;
        for (final s in snap.data ?? const <SurahSummary>[]) {
          if (s.number == number) surah = s;
        }
        if (surah == null) return const SizedBox.shrink();
        final isArabic = context.locale.languageCode == 'ar';
        final scheme = Theme.of(context).colorScheme;
        final name = isArabic ? surah.nameAr : surah.englishName;
        final pageText = 'start.resume_page'.tr(
          args: [localizedNumber(context, page)],
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Semantics(
            button: true,
            label: '${'start.resume_title'.tr()}: $name, $pageText',
            excludeSemantics: true,
            child: Material(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: widget.onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.bookmark_outline,
                          size: 30,
                          color: scheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'start.resume_title'.tr(),
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: scheme.onSecondaryContainer,
                                    ),
                              ),
                              Text(
                                '$name · $pageText',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: scheme.onSecondaryContainer,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: scheme.onSecondaryContainer,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

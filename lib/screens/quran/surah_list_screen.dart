import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/arabic_numbers.dart';
import '../../core/constants/juz_boundaries.dart';
import '../../core/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../models/surah.dart';
import '../../state/quran_provider.dart';
import '../../state/settings_provider.dart';
import '../../widgets/responsive_center.dart';
import 'surah_detail_screen.dart';

enum _ListMode { surahs, juz }

class SurahListScreen extends StatefulWidget {
  const SurahListScreen({super.key});

  @override
  State<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends State<SurahListScreen> {
  _ListMode _mode = _ListMode.surahs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuranProvider>().loadSurahs();
    });
  }

  Future<void> _goToBookmark(BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    final surahNumber = settings.bookmarkSurah;
    final page = settings.bookmarkPage;
    if (surahNumber == null || page == null) return;
    final list = await context.read<QuranProvider>().repository.getSurahList();
    SurahSummary? surah;
    for (final s in list) {
      if (s.number == surahNumber) {
        surah = s;
        break;
      }
    }
    if (surah == null || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SurahDetailScreen(surah: surah!, startPage: page),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuranProvider>();
    final hPad = responsiveHorizontalPadding(context);
    final hasBookmark = context.watch<SettingsProvider>().hasBookmark;

    return Scaffold(
      appBar: AppBar(
        title: Text('app_name'.tr()),
        actions: [
          if (hasBookmark)
            IconButton(
              icon: const Icon(Icons.bookmark),
              tooltip: context.watch<SettingsProvider>().bookmarkAyah != null
                  ? 'quran.go_to_ayah_bookmark'.tr()
                  : 'quran.go_to_bookmark'.tr(),
              onPressed: () => _goToBookmark(context),
            ),
        ],
      ),
      body: ResponsiveCenter(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 8),
              child: TextField(
                onChanged: provider.setQuery,
                decoration: InputDecoration(
                  hintText: 'quran.search_hint'.tr(),
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 8),
              child: SegmentedButton<_ListMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: _ListMode.surahs,
                    label: Text('quran.surahs_tab'.tr()),
                  ),
                  ButtonSegment(
                    value: _ListMode.juz,
                    label: Text('quran.juz_tab'.tr()),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) =>
                    setState(() => _mode = selection.first),
              ),
            ),
            Expanded(
              child: _mode == _ListMode.surahs
                  ? _buildSurahBody(context, provider)
                  : _buildJuzBody(context, provider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurahBody(BuildContext context, QuranProvider provider) {
    switch (provider.status) {
      case LoadStatus.idle:
      case LoadStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case LoadStatus.error:
        return _buildError(provider);
      case LoadStatus.loaded:
        final list = provider.filteredSurahs;
        if (list.isEmpty) {
          return Center(child: Text('quran.no_results'.tr()));
        }
        return RefreshIndicator(
          onRefresh: provider.loadSurahs,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: responsiveHorizontalPadding(context) - 4,
              vertical: 4,
            ),
            itemCount: list.length,
            separatorBuilder: (context, index) => const SizedBox(height: 6),
            itemBuilder: (context, index) => _SurahTile(surah: list[index]),
          ),
        );
    }
  }

  Widget _buildJuzBody(BuildContext context, QuranProvider provider) {
    switch (provider.status) {
      case LoadStatus.idle:
      case LoadStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case LoadStatus.error:
        return _buildError(provider);
      case LoadStatus.loaded:
        final query = provider.query.trim();
        final matchedNumbers = provider.filteredSurahs
            .map((s) => s.number)
            .toSet();
        final juzList = kJuzBoundaries.where((juz) {
          if (query.isEmpty) return true;
          if (query == juz.number.toString()) return true;
          return juz.surahNumbers.any(matchedNumbers.contains);
        }).toList();
        if (juzList.isEmpty) {
          return Center(child: Text('quran.no_results'.tr()));
        }
        final surahsByNumber = {
          for (final s in provider.surahs) s.number: s,
        };
        return ListView.separated(
          padding: EdgeInsets.symmetric(
            horizontal: responsiveHorizontalPadding(context) - 4,
            vertical: 4,
          ),
          itemCount: juzList.length,
          separatorBuilder: (context, index) => const SizedBox(height: 6),
          itemBuilder: (context, index) => _JuzTile(
            juz: juzList[index],
            surahsByNumber: surahsByNumber,
            forceExpanded: query.isNotEmpty,
          ),
        );
    }
  }

  Widget _buildError(QuranProvider provider) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('quran.error'.tr()),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => provider.loadSurahs(),
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

class _SurahTile extends StatelessWidget {
  final SurahSummary surah;

  const _SurahTile({required this.surah});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(localizedNumber(context, surah.number)),
        ),
        title: Text(
          surah.nameAr,
          style: AppTheme.quranNameStyle(context, fontSize: 18),
        ),
        subtitle: Text(
          '${surah.englishName} · ${localizedNumber(context, surah.numberOfAyahs)} ${'quran.ayahs'.tr()}',
        ),
        trailing: Text(
          surah.revelationType == 'Meccan'
              ? 'quran.meccan'.tr()
              : 'quran.medinan'.tr(),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => SurahDetailScreen(surah: surah)),
          );
        },
      ),
    );
  }
}

/// One Juz' row in the Juz' tab, expandable to list every surah it spans
/// (looked up from [surahsByNumber], built once from the full unfiltered
/// surah list so a partially-matching search still shows every surah inside
/// a matched Juz', not just the one that matched). [forceExpanded] opens it
/// automatically while the user is actively searching, so a match is
/// immediately visible without an extra tap.
class _JuzTile extends StatelessWidget {
  final JuzBoundary juz;
  final Map<int, SurahSummary> surahsByNumber;
  final bool forceExpanded;

  const _JuzTile({
    required this.juz,
    required this.surahsByNumber,
    required this.forceExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final surahs = juz.surahNumbers
        .map((n) => surahsByNumber[n])
        .whereType<SurahSummary>()
        .toList();
    final isArabic = context.locale.languageCode == 'ar';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: ValueKey('${juz.number}-$forceExpanded'),
        initiallyExpanded: forceExpanded,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: Text(localizedNumber(context, juz.number)),
        ),
        title: Text(
          'quran.juz_label'.tr(
            args: [localizedNumber(context, juz.number)],
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          surahs.map((s) => isArabic ? s.nameAr : s.englishName).join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          for (final surah in surahs)
            ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primaryContainer,
                child: Text(
                  localizedNumber(context, surah.number),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              title: Text(
                surah.nameAr,
                style: AppTheme.quranNameStyle(context, fontSize: 18),
              ),
              subtitle: Text(surah.englishName),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SurahDetailScreen(surah: surah),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/surah.dart';
import '../../state/quran_provider.dart';
import '../../widgets/responsive_center.dart';
import 'surah_detail_screen.dart';

class SurahListScreen extends StatefulWidget {
  const SurahListScreen({super.key});

  @override
  State<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends State<SurahListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuranProvider>().loadSurahs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuranProvider>();

    return Scaffold(
      appBar: AppBar(title: Text('app_name'.tr())),
      body: ResponsiveCenter(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
            Expanded(child: _buildBody(provider)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(QuranProvider provider) {
    switch (provider.status) {
      case LoadStatus.idle:
      case LoadStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case LoadStatus.error:
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
      case LoadStatus.loaded:
        final list = provider.filteredSurahs;
        if (list.isEmpty) {
          return Center(child: Text('quran.no_results'.tr()));
        }
        return RefreshIndicator(
          onRefresh: provider.loadSurahs,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: list.length,
            separatorBuilder: (context, index) => const SizedBox(height: 6),
            itemBuilder: (context, index) => _SurahTile(surah: list[index]),
          ),
        );
    }
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
          child: Text('${surah.number}'),
        ),
        title: Text(
          surah.nameAr,
          style: AppTheme.quranNameStyle(context, fontSize: 18),
        ),
        subtitle: Text(
          '${surah.englishName} · ${surah.numberOfAyahs} ${'quran.ayahs'.tr()}',
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

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/tafsir_repository.dart';
import '../../models/ayah.dart';
import '../../models/surah.dart';
import '../../state/audio_provider.dart';
import '../../state/quran_provider.dart';
import '../../state/settings_provider.dart';
import '../../widgets/reciter_picker_sheet.dart';

class SurahDetailScreen extends StatefulWidget {
  final SurahSummary surah;

  const SurahDetailScreen({super.key, required this.surah});

  @override
  State<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends State<SurahDetailScreen> {
  late Future<List<Ayah>> _ayahsFuture;

  @override
  void initState() {
    super.initState();
    _ayahsFuture = context.read<QuranProvider>().repository.getSurahAyahs(widget.surah.number);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final audio = context.watch<AudioProvider>();
    final reciter = settings.reciter;
    final playingThis = audio.currentSurah == widget.surah.number &&
        audio.currentReciter?.id == reciter.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.surah.nameAr),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'quran.reciter'.tr(),
            onPressed: () async {
              final settingsProvider = context.read<SettingsProvider>();
              final picked = await showReciterPicker(context, reciter);
              if (picked != null) {
                await settingsProvider.setReciter(picked);
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Ayah>>(
        future: _ayahsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('quran.error'.tr()));
          }
          final ayahs = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: ayahs.length,
            itemBuilder: (context, index) => _AyahCard(ayah: ayahs[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (!reciter.hasSurah(widget.surah.number)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This reciter has no recording for this surah')),
            );
            return;
          }
          await context.read<AudioProvider>().playSurah(widget.surah.number, reciter);
        },
        icon: Icon(playingThis && audio.isPlaying ? Icons.pause : Icons.play_arrow),
        label: Text('quran.play_surah'.tr()),
      ),
    );
  }
}

class _AyahCard extends StatelessWidget {
  final Ayah ayah;

  const _AyahCard({required this.ayah});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showAyahSheet(context, ayah),
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                child: Text('${ayah.numberInSurah}', style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  ayah.textAr,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: AppTheme.quranTextStyle(context, fontSize: settings.quranFontSize),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showAyahSheet(BuildContext context, Ayah ayah) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _AyahDetailSheet(ayah: ayah),
  );
}

class _AyahDetailSheet extends StatefulWidget {
  final Ayah ayah;

  const _AyahDetailSheet({required this.ayah});

  @override
  State<_AyahDetailSheet> createState() => _AyahDetailSheetState();
}

class _AyahDetailSheetState extends State<_AyahDetailSheet> {
  final TafsirRepository _tafsirRepo = TafsirRepository();
  String? _tafsir;
  bool _loadingTafsir = false;
  String? _tafsirError;

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.ayah.textAr,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: AppTheme.quranTextStyle(ctx, fontSize: 24),
              ),
              const Divider(height: 28),
              Text('quran.translation'.tr(), style: Theme.of(ctx).textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(
                widget.ayah.textEn ?? '-',
                textAlign: TextAlign.left,
                textDirection: TextDirection.ltr,
                style: Theme.of(ctx).textTheme.bodyLarge,
              ),
              const Divider(height: 28),
              Text('quran.tafsir'.tr(), style: Theme.of(ctx).textTheme.titleSmall),
              const SizedBox(height: 6),
              _buildTafsirBody(isArabic),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTafsirBody(bool isArabic) {
    if (_tafsir != null) {
      return Text(
        _tafsir!,
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        textAlign: isArabic ? TextAlign.right : TextAlign.left,
      );
    }
    if (_tafsirError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('quran.error'.tr()),
          TextButton(onPressed: _loadTafsir, child: Text('quran.tafsir'.tr())),
        ],
      );
    }
    if (!_loadingTafsir) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadTafsir());
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Future<void> _loadTafsir() async {
    if (_loadingTafsir) return;
    setState(() {
      _loadingTafsir = true;
      _tafsirError = null;
    });
    try {
      final isArabic = context.locale.languageCode == 'ar';
      final text = await _tafsirRepo.getTafsir(
        surahNumber: widget.ayah.surahNumber,
        ayahNumberInSurah: widget.ayah.numberInSurah,
        arabic: isArabic,
      );
      setState(() {
        _tafsir = text.isEmpty ? '-' : text;
        _loadingTafsir = false;
      });
    } catch (_) {
      setState(() {
        _tafsirError = 'error';
        _loadingTafsir = false;
      });
    }
  }
}

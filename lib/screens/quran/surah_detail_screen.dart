import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/gestures.dart';
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
import '../../widgets/responsive_center.dart';

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
    _ayahsFuture = context.read<QuranProvider>().repository.getSurahAyahs(
      widget.surah.number,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final audio = context.watch<AudioProvider>();
    final reciter = settings.reciter;
    final playingThis =
        audio.currentSurah == widget.surah.number &&
        audio.currentReciter?.id == reciter.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.surah.nameAr),
        actions: [
          IconButton(
            icon: Icon(
              settings.quranViewMode == QuranViewMode.page
                  ? Icons.view_agenda_outlined
                  : Icons.menu_book_outlined,
            ),
            tooltip: settings.quranViewMode == QuranViewMode.page
                ? 'quran.view_list'.tr()
                : 'quran.view_page'.tr(),
            onPressed: () => settings.setQuranViewMode(
              settings.quranViewMode == QuranViewMode.page
                  ? QuranViewMode.list
                  : QuranViewMode.page,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TextButton.icon(
              icon: const Icon(Icons.headphones_outlined, size: 18),
              label: Text('quran.reciter'.tr()),
              onPressed: () async {
                final settingsProvider = context.read<SettingsProvider>();
                final picked = await showReciterPicker(context, reciter);
                if (picked != null) {
                  await settingsProvider.setReciter(picked);
                }
              },
            ),
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
          final activeAyah = playingThis ? audio.currentAbsoluteAyah : null;
          if (settings.quranViewMode == QuranViewMode.page) {
            return ResponsiveCenter(
              child: _MushafPageView(
                ayahs: ayahs,
                surahNameAr: widget.surah.nameAr,
                activeAyahNumber: activeAyah,
                fontSize: settings.quranFontSize,
              ),
            );
          }
          return ResponsiveCenter(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: ayahs.length,
              itemBuilder: (context, index) => _AyahCard(
                ayah: ayahs[index],
                totalAyahs: widget.surah.numberOfAyahs,
                isActive: activeAyah == ayahs[index].numberInSurah,
                surahNameAr: widget.surah.nameAr,
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (!reciter.hasSurah(widget.surah.number)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This reciter has no recording for this surah'),
              ),
            );
            return;
          }
          await context.read<AudioProvider>().playSurah(
            widget.surah.number,
            reciter,
            resume: true,
            surahTitle: widget.surah.nameAr,
          );
        },
        icon: Icon(
          playingThis && audio.isPlaying ? Icons.pause : Icons.play_arrow,
        ),
        label: Text('quran.play_surah'.tr()),
      ),
    );
  }
}

class _AyahCard extends StatelessWidget {
  final Ayah ayah;
  final int totalAyahs;
  final bool isActive;
  final String surahNameAr;

  const _AyahCard({
    required this.ayah,
    required this.totalAyahs,
    required this.isActive,
    required this.surahNameAr,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final audio = context.watch<AudioProvider>();
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showAyahSheet(context, ayah),
      child: Card(
        color: isActive
            ? Theme.of(
                context,
              ).colorScheme.secondaryContainer.withValues(alpha: 0.35)
            : null,
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
                child: Text(
                  '${ayah.numberInSurah}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  ayah.textAr,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: AppTheme.quranTextStyle(
                    context,
                    fontSize: settings.quranFontSize,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  isActive && audio.isPlaying
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  size: 22,
                ),
                tooltip: 'quran.play_from_here'.tr(),
                onPressed: () async {
                  final settingsState = context.read<SettingsProvider>();
                  final reciter = settingsState.reciter;
                  if (isActive) {
                    await audio.playSurah(
                      ayah.surahNumber,
                      reciter,
                      surahTitle: surahNameAr,
                    );
                    return;
                  }
                  await context.read<AudioProvider>().playFromAyah(
                    surahNumber: ayah.surahNumber,
                    ayahNumberInSurah: ayah.numberInSurah,
                    totalAyahsInSurah: totalAyahs,
                    reciter: reciter,
                    surahTitle: surahNameAr,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showAyahSheet(BuildContext context, Ayah ayah) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: _AyahDetailSheet(ayah: ayah),
      ),
    ),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 4, right: 4),
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.ayah.textAr,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: AppTheme.quranTextStyle(context, fontSize: 24),
                ),
                const Divider(height: 28),
                Text(
                  'quran.translation'.tr(),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  widget.ayah.textEn ?? '-',
                  textAlign: TextAlign.left,
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const Divider(height: 28),
                Text(
                  'quran.tafsir'.tr(),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                _buildTafsirBody(isArabic),
              ],
            ),
          ),
        ),
      ],
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

/// A continuous, justified Arabic text flow with inline ayah-number markers,
/// matching the look of a real printed Quran page rather than a list of
/// separate ayah cards.
class _MushafPageView extends StatefulWidget {
  final List<Ayah> ayahs;
  final String surahNameAr;
  final int? activeAyahNumber;
  final double fontSize;

  const _MushafPageView({
    required this.ayahs,
    required this.surahNameAr,
    required this.activeAyahNumber,
    required this.fontSize,
  });

  @override
  State<_MushafPageView> createState() => _MushafPageViewState();
}

class _MushafPageViewState extends State<_MushafPageView> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _clearRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clearRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();
    final theme = Theme.of(context);
    final baseStyle = AppTheme.quranTextStyle(
      context,
      fontSize: widget.fontSize,
    ).copyWith(height: 2.1);

    final spans = <InlineSpan>[
      TextSpan(
        text: '${widget.surahNameAr}\n\n',
        style: baseStyle.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: widget.fontSize + 4,
        ),
      ),
    ];

    for (final ayah in widget.ayahs) {
      final recognizer = TapGestureRecognizer()
        ..onTap = () => _showAyahSheet(context, ayah);
      _recognizers.add(recognizer);
      final isActive = widget.activeAyahNumber == ayah.numberInSurah;

      spans.add(
        TextSpan(
          text: '${ayah.textAr} ',
          style: baseStyle.copyWith(
            background: isActive
                ? (Paint()
                  ..color = theme.colorScheme.secondaryContainer.withValues(
                    alpha: 0.5,
                  ))
                : null,
          ),
          recognizer: recognizer,
        ),
      );
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.primary, width: 1.2),
              ),
              child: Text(
                '${ayah.numberInSurah}',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );
      spans.add(const TextSpan(text: ' '));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
      child: Text.rich(
        TextSpan(children: spans),
        textAlign: TextAlign.justify,
        textDirection: TextDirection.rtl,
      ),
    );
  }
}

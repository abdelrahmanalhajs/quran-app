import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/quran_repository.dart';
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

  Future<void> _goToAdjacentSurah(BuildContext context, int delta) async {
    final targetNumber = widget.surah.number + delta;
    if (targetNumber < 1 || targetNumber > 114) return;
    final list = await context.read<QuranProvider>().repository.getSurahList();
    SurahSummary? target;
    for (final s in list) {
      if (s.number == targetNumber) {
        target = s;
        break;
      }
    }
    if (target == null || !context.mounted) return;
    final resolvedTarget = target;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SurahDetailScreen(surah: resolvedTarget),
      ),
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
        title: Text(
          widget.surah.nameAr,
          style: AppTheme.quranNameStyle(
            context,
            fontSize: 20,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
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
            return _MushafPageView(
              ayahs: ayahs,
              surahNameAr: widget.surah.nameAr,
              activeAyahNumber: activeAyah,
              fontSize: settings.quranFontSize,
              onAdjacentSurah: (delta) => _goToAdjacentSurah(context, delta),
            );
          }
          final showBismillah = QuranRepository.hasSeparateBismillah(
            widget.surah.number,
          );
          return ResponsiveCenter(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: ayahs.length + (showBismillah ? 1 : 0),
              itemBuilder: (context, index) {
                if (showBismillah && index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: AppTheme.quranTextStyle(
                        context,
                        fontSize: settings.quranFontSize,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                  );
                }
                final ayah = ayahs[showBismillah ? index - 1 : index];
                return _AyahCard(
                  ayah: ayah,
                  totalAyahs: widget.surah.numberOfAyahs,
                  isActive: activeAyah == ayah.numberInSurah,
                  surahNameAr: widget.surah.nameAr,
                );
              },
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
      onTap: () => _showAyahSheet(context, ayah, totalAyahs, surahNameAr),
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

const _arabicIndicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

/// Renders [number] using Arabic-Indic digits (١٢٣...) when the active
/// locale is Arabic, otherwise plain Western digits.
String _localizedNumber(BuildContext context, int number) {
  if (context.locale.languageCode != 'ar') return '$number';
  return number
      .toString()
      .split('')
      .map((d) => _arabicIndicDigits[int.parse(d)])
      .join();
}

void _showAyahSheet(
  BuildContext context,
  Ayah ayah,
  int totalAyahs,
  String surahNameAr,
) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: _AyahDetailSheet(
          ayah: ayah,
          totalAyahs: totalAyahs,
          surahNameAr: surahNameAr,
        ),
      ),
    ),
  );
}

class _AyahDetailSheet extends StatefulWidget {
  final Ayah ayah;
  final int totalAyahs;
  final String surahNameAr;

  const _AyahDetailSheet({
    required this.ayah,
    required this.totalAyahs,
    required this.surahNameAr,
  });

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
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: Text('quran.play_from_here'.tr()),
                    onPressed: () async {
                      final audio = context.read<AudioProvider>();
                      final reciter = context.read<SettingsProvider>().reciter;
                      await audio.playFromAyah(
                        surahNumber: widget.ayah.surahNumber,
                        ayahNumberInSurah: widget.ayah.numberInSurah,
                        totalAyahsInSurah: widget.totalAyahs,
                        reciter: reciter,
                        surahTitle: widget.surahNameAr,
                      );
                    },
                  ),
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

/// Splits a surah's ayahs into chunks matching real Mushaf page breaks
/// (using each ayah's [Ayah.page]), so they render as separate swipeable
/// pages instead of one continuous flow. Since this only has one surah's
/// ayahs to work with, a Mushaf page that's shared between this surah and an
/// adjacent one will only show this surah's lines for that page number —
/// swiping past the edge moves to the adjacent surah instead.
List<List<Ayah>> _groupByMushafPage(List<Ayah> ayahs) {
  final pages = <List<Ayah>>[];
  for (final ayah in ayahs) {
    if (pages.isEmpty || pages.last.first.page != ayah.page) {
      pages.add([ayah]);
    } else {
      pages.last.add(ayah);
    }
  }
  return pages;
}

/// A continuous, justified Arabic text flow with an ornate border, surah
/// banner and inline ayah-number roundels, matching the look of a real
/// printed Quran page rather than a list of separate ayah cards. Content is
/// split into real Mushaf page breaks and presented as horizontally
/// swipeable pages, like flipping through a physical Mushaf, with a
/// Juz/Hizb/page footer at the end of each page. Colors are fixed
/// (cream/green/black) regardless of app theme, since that's the
/// recognizable look of a physical Mushaf page.
class _MushafPageView extends StatefulWidget {
  final List<Ayah> ayahs;
  final String surahNameAr;
  final int? activeAyahNumber;
  final double fontSize;
  final void Function(int delta) onAdjacentSurah;

  const _MushafPageView({
    required this.ayahs,
    required this.surahNameAr,
    required this.activeAyahNumber,
    required this.fontSize,
    required this.onAdjacentSurah,
  });

  @override
  State<_MushafPageView> createState() => _MushafPageViewState();
}

class _MushafPageViewState extends State<_MushafPageView> {
  static const _pageBg = Color(0xFFFBF3E0);
  static const _frameGreen = Color(0xFF1F5C4A);
  static const _ink = Color(0xFF161410);
  static const _quarterMarks = ['', '¼', '½', '¾'];

  final List<TapGestureRecognizer> _recognizers = [];
  final PageController _pageController = PageController();

  void _clearRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clearRecognizers();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();
    final totalAyahs = widget.ayahs.length;
    final mushafPages = _groupByMushafPage(widget.ayahs);

    return ResponsiveCenter(
      maxWidth: 760,
      child: PageView.builder(
        controller: _pageController,
        reverse: true, // RTL: swiping left advances to the next page.
        itemCount: mushafPages.length,
        itemBuilder: (context, index) {
          final pageAyahs = mushafPages[index];
          final isFirstPage = index == 0;
          final isLastPage = index == mushafPages.length - 1;
          return _buildMushafPage(
            context,
            pageAyahs,
            totalAyahs: totalAyahs,
            isFirstPage: isFirstPage,
            isLastPage: isLastPage,
          );
        },
      ),
    );
  }

  Widget _buildMushafPage(
    BuildContext context,
    List<Ayah> pageAyahs,
    {required int totalAyahs, required bool isFirstPage, required bool isLastPage}
  ) {
    final baseStyle = AppTheme.quranTextStyle(context, fontSize: widget.fontSize)
        .copyWith(height: 2.1, color: _ink);
    final showsSurahStart = pageAyahs.any((a) => a.numberInSurah == 1);

    final spans = <InlineSpan>[];
    for (final ayah in pageAyahs) {
      final recognizer = TapGestureRecognizer()
        ..onTap = () =>
            _showAyahSheet(context, ayah, totalAyahs, widget.surahNameAr);
      _recognizers.add(recognizer);
      final isActive = widget.activeAyahNumber == ayah.numberInSurah;

      // No space between the ayah text and its marker: a plain space there
      // is a valid line-break point, and if the line wraps exactly there,
      // the marker drifts to the start of the next line and visually sits
      // next to the following ayah's text instead — looking like the ayah
      // numbers got swapped. The marker's own padding provides the visual
      // gap, and the breakable space goes *after* it instead, where wrapping
      // is harmless.
      spans.add(
        TextSpan(
          text: ayah.textAr,
          style: baseStyle.copyWith(
            background: isActive
                ? (Paint()..color = _frameGreen.withValues(alpha: 0.18))
                : null,
          ),
          recognizer: recognizer,
        ),
      );
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _AyahFlowerMarker(
              number: ayah.numberInSurah,
              color: _frameGreen,
              background: _pageBg,
            ),
          ),
        ),
      );
      spans.add(const TextSpan(text: ' '));
    }

    final lastAyah = pageAyahs.last;
    final hizbLabel =
        '${_localizedNumber(context, lastAyah.hizb)}${_quarterMarks[lastAyah.quarterInHizb - 1]}';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pageAyahs.isNotEmpty)
            Container(
              color: _frameGreen,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  'quran.juz_label'.tr(
                    args: [_localizedNumber(context, pageAyahs.first.juz)],
                  ),
                  style: const TextStyle(
                    color: _pageBg,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          _OrnateFrame(
            color: _frameGreen,
            background: _pageBg,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showsSurahStart) ...[
                    _SurahBanner(name: widget.surahNameAr, color: _frameGreen),
                    if (QuranRepository.hasSeparateBismillah(
                      pageAyahs.first.surahNumber,
                    )) ...[
                      const SizedBox(height: 14),
                      Text(
                        'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: baseStyle.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                    const SizedBox(height: 18),
                  ],
                  Text.rich(
                    TextSpan(children: spans),
                    textAlign: TextAlign.justify,
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'quran.page_footer'.tr(
                      args: [
                        _localizedNumber(context, lastAyah.juz),
                        hizbLabel,
                        _localizedNumber(context, lastAyah.page),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _frameGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isFirstPage || isLastPage) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isFirstPage)
                  TextButton.icon(
                    onPressed: () => widget.onAdjacentSurah(-1),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: Text('quran.previous_surah'.tr()),
                  ),
                if (isLastPage)
                  TextButton.icon(
                    onPressed: () => widget.onAdjacentSurah(1),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: Text('quran.next_surah'.tr()),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SurahBanner extends StatelessWidget {
  final String name;
  final Color color;

  const _SurahBanner({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.6),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('❁', style: TextStyle(color: color, fontSize: 16)),
          const SizedBox(width: 10),
          Text(
            name,
            textDirection: TextDirection.rtl,
            style: AppTheme.quranNameStyle(
              context,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Text('❁', style: TextStyle(color: color, fontSize: 16)),
        ],
      ),
    );
  }
}

/// An 8-petal flower badge (two overlapping rotated squares) with the ayah
/// number centered, evoking the ornate "end of ayah" rosette printed in a
/// Mushaf, rather than a plain circle.
class _AyahFlowerMarker extends StatelessWidget {
  final int number;
  final Color color;
  final Color background;

  const _AyahFlowerMarker({
    required this.number,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 26,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: 0,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                border: Border.all(color: color, width: 1.1),
              ),
            ),
          ),
          Transform.rotate(
            angle: 0.785398,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                border: Border.all(color: color, width: 1.1),
              ),
            ),
          ),
          Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(shape: BoxShape.circle, color: background),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 8.5,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A double-line border with small diamond ornaments at each corner,
/// evoking the decorative frame printed around a Mushaf page.
class _OrnateFrame extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color background;

  const _OrnateFrame({
    required this.child,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: background),
      padding: const EdgeInsets.all(10),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 2.4),
            ),
            padding: const EdgeInsets.all(6),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: color, width: 1),
              ),
              child: child,
            ),
          ),
          for (final alignment in const [
            Alignment.topLeft,
            Alignment.topRight,
            Alignment.bottomLeft,
            Alignment.bottomRight,
          ])
            Align(
              alignment: alignment,
              child: Transform.rotate(
                angle: 0.785398, // 45deg
                child: Container(
                  width: 12,
                  height: 12,
                  color: color,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

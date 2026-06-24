import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
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

/// Everything [SurahDetailScreen] needs to render: the surah's own ayahs
/// (for list mode, the FAB and totals), the same ayahs but with the first
/// and/or last Mushaf-page group replaced by the *actual* page content from
/// [QuranRepository.getPageAyahs] (which may include trailing ayahs of the
/// previous surah or leading ayahs of the next one, exactly like a real
/// printed Mushaf), and a lookup of every surah referenced on those boundary
/// pages so banners/totals can be shown for a surah other than this one.
class _SurahPageBundle {
  final List<Ayah> ayahs;
  final List<Ayah> pageViewAyahs;
  final bool isFirstPageShared;
  final bool isLastPageShared;
  final Map<int, SurahSummary> surahsByNumber;

  _SurahPageBundle({
    required this.ayahs,
    required this.pageViewAyahs,
    required this.isFirstPageShared,
    required this.isLastPageShared,
    required this.surahsByNumber,
  });
}

class SurahDetailScreen extends StatefulWidget {
  final SurahSummary surah;

  /// When opened by swiping backward past the previous surah's first page,
  /// the page view should land on this surah's *last* page (continuing the
  /// backward flow), not jump back to its first page.
  final bool startAtLastPage;

  /// This surah's first Mushaf page was already fully shown combined into
  /// the previous surah's last page, so skip straight to the second page.
  final bool skipFirstPage;

  /// This surah's last Mushaf page was already fully shown combined into
  /// the next surah's first page, so land one page before the last.
  final bool skipLastPage;

  const SurahDetailScreen({
    super.key,
    required this.surah,
    this.startAtLastPage = false,
    this.skipFirstPage = false,
    this.skipLastPage = false,
  });

  @override
  State<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends State<SurahDetailScreen> {
  late Future<_SurahPageBundle> _bundleFuture;

  @override
  void initState() {
    super.initState();
    _bundleFuture = _loadBundle();
  }

  Future<_SurahPageBundle> _loadBundle() async {
    final repo = context.read<QuranProvider>().repository;
    final surahNumber = widget.surah.number;
    final results = await Future.wait([
      repo.getSurahAyahs(surahNumber),
      repo.getSurahList(),
    ]);
    final ayahs = results[0] as List<Ayah>;
    final surahList = results[1] as List<SurahSummary>;
    final surahsByNumber = {for (final s in surahList) s.number: s};

    if (ayahs.isEmpty) {
      return _SurahPageBundle(
        ayahs: ayahs,
        pageViewAyahs: ayahs,
        isFirstPageShared: false,
        isLastPageShared: false,
        surahsByNumber: surahsByNumber,
      );
    }

    final firstPage = ayahs.first.page;
    final lastPage = ayahs.last.page;
    final firstPageAyahs = await repo.getPageAyahs(firstPage);
    final lastPageAyahs = firstPage == lastPage
        ? firstPageAyahs
        : await repo.getPageAyahs(lastPage);

    final isFirstPageShared = firstPageAyahs.any(
      (a) => a.surahNumber != surahNumber,
    );
    final isLastPageShared = lastPageAyahs.any(
      (a) => a.surahNumber != surahNumber,
    );

    final pageViewAyahs = firstPage == lastPage
        ? firstPageAyahs
        : [
            ...firstPageAyahs,
            ...ayahs.where((a) => a.page != firstPage && a.page != lastPage),
            ...lastPageAyahs,
          ];

    return _SurahPageBundle(
      ayahs: ayahs,
      pageViewAyahs: pageViewAyahs,
      isFirstPageShared: isFirstPageShared,
      isLastPageShared: isLastPageShared,
      surahsByNumber: surahsByNumber,
    );
  }

  Future<void> _goToAdjacentSurah(
    BuildContext context,
    int delta, {
    required bool skip,
  }) async {
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
        builder: (_) => SurahDetailScreen(
          surah: resolvedTarget,
          startAtLastPage: delta < 0,
          skipFirstPage: delta > 0 && skip,
          skipLastPage: delta < 0 && skip,
        ),
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
      body: FutureBuilder<_SurahPageBundle>(
        future: _bundleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('quran.error'.tr()));
          }
          final bundle = snapshot.data!;
          final ayahs = bundle.ayahs;
          if (settings.quranViewMode == QuranViewMode.page) {
            return _MushafPageView(
              ayahs: bundle.pageViewAyahs,
              surahNumber: widget.surah.number,
              surahsByNumber: bundle.surahsByNumber,
              activeSurahNumber: audio.currentSurah,
              activeAyahNumber: audio.currentAbsoluteAyah,
              fontSize: settings.quranFontSize,
              startAtLastPage: widget.startAtLastPage,
              skipFirstPage: widget.skipFirstPage,
              skipLastPage: widget.skipLastPage,
              onAdjacentSurah: (delta) => _goToAdjacentSurah(
                context,
                delta,
                skip: delta > 0
                    ? bundle.isLastPageShared
                    : bundle.isFirstPageShared,
              ),
            );
          }
          final activeAyah = playingThis ? audio.currentAbsoluteAyah : null;
          final showBismillah = QuranRepository.hasSeparateBismillah(
            widget.surah.number,
          );
          return ResponsiveCenter(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(
                responsiveHorizontalPadding(context),
                12,
                responsiveHorizontalPadding(context),
                96,
              ),
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
              SnackBar(content: Text('quran.reciter_unavailable'.tr())),
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
                  _arabicIndicNumber(ayah.numberInSurah),
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
  return _arabicIndicNumber(number);
}

/// Renders [number] using Arabic-Indic digits (١٢٣...) unconditionally.
/// Ayah numbers are part of the Quranic text itself — like a printed
/// Mushaf, they're always Arabic-Indic regardless of the app's UI language,
/// unlike UI labels (Juz/Hizb/page) which follow [_localizedNumber].
String _arabicIndicNumber(int number) {
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

/// Splits a list of ayahs into chunks matching real Mushaf page breaks
/// (using each ayah's [Ayah.page]). Each chunk renders as exactly one
/// swipeable screen — a real Mushaf page is never split across several
/// screens, regardless of font size; [_buildMushafPage]'s own FittedBox
/// scales the whole page down to fit instead. When [ayahs] is the result of
/// [_SurahDetailScreenState._loadBundle]'s page-aware fetch, the first and/or
/// last chunk may already contain ayahs from an adjacent surah, in which
/// case that chunk is the literal, true content of that printed page.
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

/// Splits one Mushaf page's ayahs into runs of consecutive ayahs that
/// belong to the same surah, in page order. A page is almost always a
/// single run, but a page shared between the end of one surah and the
/// start of the next comes back as two (or, for very short surahs packed
/// together, occasionally more) runs — each rendered with its own banner
/// (where it starts a new surah) but on the same physical page.
List<List<Ayah>> _groupBySurah(List<Ayah> pageAyahs) {
  final runs = <List<Ayah>>[];
  for (final ayah in pageAyahs) {
    if (runs.isEmpty || runs.last.first.surahNumber != ayah.surahNumber) {
      runs.add([ayah]);
    } else {
      runs.last.add(ayah);
    }
  }
  return runs;
}

/// A continuous, justified Arabic text flow with an ornate border, surah
/// banner(s) and inline ayah-number roundels, matching the look of a real
/// printed Quran page rather than a list of separate ayah cards. Content is
/// split into real Mushaf page breaks and presented as horizontally
/// swipeable pages, like flipping through a physical Mushaf, with a
/// Juz/Hizb/page footer at the end of each page. A page shared between two
/// surahs shows both, banner and all, exactly where they fall on the real
/// page. Colors are fixed (cream/green/black) regardless of app theme,
/// since that's the recognizable look of a physical Mushaf page.
class _MushafPageView extends StatefulWidget {
  final List<Ayah> ayahs;
  final int surahNumber;
  final Map<int, SurahSummary> surahsByNumber;
  final int? activeSurahNumber;
  final int? activeAyahNumber;
  final double fontSize;
  final bool startAtLastPage;
  final bool skipFirstPage;
  final bool skipLastPage;
  final void Function(int delta) onAdjacentSurah;

  const _MushafPageView({
    required this.ayahs,
    required this.surahNumber,
    required this.surahsByNumber,
    required this.activeSurahNumber,
    required this.activeAyahNumber,
    required this.fontSize,
    required this.startAtLastPage,
    required this.skipFirstPage,
    required this.skipLastPage,
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
  late final PageController _pageController;
  late int _realPagesStart;
  late List<List<Ayah>> _screenPages;
  int? _prevSentinelIndex;
  int? _nextSentinelIndex;
  bool _navigating = false;
  int _currentIndex = 0;
  int _itemCount = 0;

  void _clearRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void initState() {
    super.initState();

    _screenPages = _groupByMushafPage(widget.ayahs);
    final hasPrevSurah = widget.surahNumber > 1;
    final hasNextSurah = widget.surahNumber < 114;

    _realPagesStart = hasPrevSurah ? 1 : 0;
    _prevSentinelIndex = hasPrevSurah ? 0 : null;
    _nextSentinelIndex = hasNextSurah
        ? _realPagesStart + _screenPages.length
        : null;
    _itemCount =
        _screenPages.length +
        (_prevSentinelIndex != null ? 1 : 0) +
        (_nextSentinelIndex != null ? 1 : 0);

    // A page that's shared with the adjacent surah may already have been
    // shown in full on the screen the user is coming from (the adjacent
    // surah's own boundary page) — skip past it so it isn't shown twice.
    final totalScreens = _screenPages.length;
    var fullySkip = false;
    int initialPage;
    if (widget.startAtLastPage) {
      final idx = totalScreens - 1 - (widget.skipLastPage ? 1 : 0);
      if (idx < 0) {
        fullySkip = true;
        initialPage = _realPagesStart;
      } else {
        initialPage = _realPagesStart + idx;
      }
    } else {
      final idx = widget.skipFirstPage ? 1 : 0;
      if (idx >= totalScreens) {
        fullySkip = true;
        initialPage = _realPagesStart;
      } else {
        initialPage = _realPagesStart + idx;
      }
    }
    _currentIndex = initialPage;
    _pageController = PageController(initialPage: initialPage);

    // This surah's entire content was already shown combined into the
    // adjacent surah's boundary page, so there's nothing unique to land on
    // here at all — defer straight to the next surah over in that
    // direction, same as swiping past this (empty, from this surah's point
    // of view) edge would.
    if (fullySkip) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onAdjacentSurah(widget.startAtLastPage ? -1 : 1);
      });
    }
  }

  @override
  void dispose() {
    _clearRecognizers();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    _currentIndex = index;
    if (_navigating) return;
    if (index == _prevSentinelIndex) {
      _navigating = true;
      widget.onAdjacentSurah(-1);
    } else if (index == _nextSentinelIndex) {
      _navigating = true;
      widget.onAdjacentSurah(1);
    }
  }

  /// Swipe direction is driven explicitly here (instead of relying on
  /// [PageView]'s own gesture handling, whose direction depends on a
  /// fiddly interaction between `reverse` and ambient [Directionality])
  /// so it unambiguously matches Mushaf reading order: swipe right reveals
  /// the next page, swipe left goes back to the previous one. This also
  /// sidesteps Flutter web's default [ScrollBehavior], which only enables
  /// touch/stylus drag-to-scroll and ignores mouse drags — a plain
  /// [GestureDetector] responds to every pointer kind.
  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 150) return;
    final target = velocity > 0 ? _currentIndex + 1 : _currentIndex - 1;
    if (target < 0 || target >= _itemCount) return;
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();

    return ResponsiveCenter(
      maxWidth: 760,
      child: Padding(
        padding: responsiveMushafPagePadding(context),
        child: GestureDetector(
          // Without this, a drag starting on empty space (e.g. the
          // letterboxed margins FittedBox leaves around a shrunk page)
          // wouldn't be hit-tested at all, since the default
          // `deferToChild` behavior only recognizes gestures where a
          // child actually paints.
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: _handleHorizontalDragEnd,
          child: PageView.builder(
            controller: _pageController,
            reverse: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _itemCount,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              if (index == _prevSentinelIndex) {
                return const _AdjacentSurahTransitionPage(forward: false);
              }
              if (index == _nextSentinelIndex) {
                return const _AdjacentSurahTransitionPage(forward: true);
              }
              final pageAyahs = _screenPages[index - _realPagesStart];
              return _buildMushafPage(context, pageAyahs);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMushafPage(BuildContext context, List<Ayah> pageAyahs) {
    final baseStyle = AppTheme.quranTextStyle(
      context,
      fontSize: widget.fontSize,
    ).copyWith(height: 2.1, color: _ink);

    final blocks = <Widget>[];
    final runs = _groupBySurah(pageAyahs);
    for (var r = 0; r < runs.length; r++) {
      final run = runs[r];
      final runSurahNumber = run.first.surahNumber;
      final startsNewSurah = run.first.numberInSurah == 1;
      if (startsNewSurah) {
        if (r > 0) blocks.add(const SizedBox(height: 18));
        final surahInfo = widget.surahsByNumber[runSurahNumber];
        blocks.add(
          _SurahBanner(
            name: surahInfo?.nameAr ?? '',
            color: _frameGreen,
          ),
        );
        if (QuranRepository.hasSeparateBismillah(runSurahNumber)) {
          blocks.add(const SizedBox(height: 14));
          blocks.add(
            Text(
              'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: baseStyle.copyWith(fontWeight: FontWeight.bold),
            ),
          );
        }
        blocks.add(const SizedBox(height: 18));
      }

      final spans = <InlineSpan>[];
      for (final ayah in run) {
        final surahInfo = widget.surahsByNumber[ayah.surahNumber];
        final recognizer = TapGestureRecognizer()
          ..onTap = () => _showAyahSheet(
            context,
            ayah,
            surahInfo?.numberOfAyahs ?? ayah.numberInSurah,
            surahInfo?.nameAr ?? '',
          );
        _recognizers.add(recognizer);
        final isActive =
            widget.activeSurahNumber == ayah.surahNumber &&
            widget.activeAyahNumber == ayah.numberInSurah;

        // The ayah-end marker is plain text glued directly to its own
        // ayah's span with no space in between, never a WidgetSpan. A
        // WidgetSpan placeholder carries an inherent line-break opportunity
        // on *both* sides regardless of adjacent whitespace, so even after
        // removing the leading space it could still wrap onto the next
        // line and visually sit next to the following ayah's text —
        // looking like the ayah numbers got swapped. Plain adjacent
        // TextSpans with no whitespace between them can never be split by
        // a line break, so the marker can only ever travel with its own
        // ayah. The breakable space goes after the marker, where wrapping
        // just starts the next ayah on a new line.
        final highlight = isActive
            ? (Paint()..color = _frameGreen.withValues(alpha: 0.18))
            : null;
        spans.add(
          TextSpan(
            text: ayah.textAr,
            style: baseStyle.copyWith(background: highlight),
            recognizer: recognizer,
          ),
        );
        spans.add(
          TextSpan(
            text: '۝${_arabicIndicNumber(ayah.numberInSurah)}',
            style: baseStyle.copyWith(
              color: _frameGreen,
              fontWeight: FontWeight.bold,
              background: highlight,
            ),
            recognizer: recognizer,
          ),
        );
        spans.add(const TextSpan(text: ' '));
      }
      blocks.add(
        Text.rich(
          TextSpan(children: spans),
          textAlign: TextAlign.justify,
          textDirection: TextDirection.rtl,
        ),
      );
    }

    final lastAyah = pageAyahs.last;
    final hizbLabel =
        '${_localizedNumber(context, lastAyah.hizb)}${_quarterMarks[lastAyah.quarterInHizb - 1]}';

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...blocks,
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
    );

    // Sizes 1-3 (the first 3 of kQuranFontSizeSteps) must always fit
    // without scrolling: FittedBox(scaleDown) only ever shrinks (never
    // enlarges) the text to guarantee that. Sizes 4-5 skip that shrink,
    // since they're deliberately large enough to commonly overflow and are
    // meant to be read by scrolling instead.
    //
    // The frame itself is *always* the full screen size (via the Expanded
    // below) at every size, on phone or tablet, in any orientation — never
    // shrunk or centered down to the text's own size. The text is aligned
    // to the top of the frame's interior rather than centered, so the
    // frame's top border sits right above it with no built-in gap; if a
    // page is short at this font size, any leftover room is just more of
    // the same cream background beneath the text, the way a real Mushaf
    // page's last, partly-filled page looks, rather than empty space
    // floating the text away from the border on every side.
    final allowScroll = widget.fontSize >= kQuranFontSizeSteps[3];
    final innerArea = LayoutBuilder(
      builder: (context, constraints) {
        final scaled = allowScroll
            ? SizedBox(width: constraints.maxWidth, child: content)
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(width: constraints.maxWidth, child: content),
              );
        return SingleChildScrollView(
          physics: allowScroll
              ? const ClampingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          child: Align(alignment: Alignment.topCenter, child: scaled),
        );
      },
    );

    final pageArea = _OrnateFrame(
      color: _frameGreen,
      background: _pageBg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
        child: innerArea,
      ),
    );

    // The cream background always fills the full page extent given by the
    // PageView (matching the device's screen, in any orientation, on both
    // phone and tablet) — Expanded stretches it to that size regardless of
    // how big the framed content within it ends up being.
    return Column(
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
        Expanded(child: pageArea),
      ],
    );
  }
}

/// Shown briefly while swiping past a surah's first/last page, while
/// [_SurahDetailScreenState._goToAdjacentSurah] looks up and navigates to
/// the adjacent surah. Styled to match the Mushaf page background so the
/// transition doesn't flash an unstyled blank page.
class _AdjacentSurahTransitionPage extends StatelessWidget {
  final bool forward;

  const _AdjacentSurahTransitionPage({required this.forward});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _MushafPageViewState._pageBg,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            forward ? Icons.arrow_forward : Icons.arrow_back,
            color: _MushafPageViewState._frameGreen,
          ),
          const SizedBox(height: 12),
          Text(
            forward ? 'quran.next_surah'.tr() : 'quran.previous_surah'.tr(),
            style: const TextStyle(
              color: _MushafPageViewState._frameGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
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
                child: Container(width: 12, height: 12, color: color),
              ),
            ),
        ],
      ),
    );
  }
}

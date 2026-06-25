import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../../core/arabic_numbers.dart';
import '../../core/constants/juz_boundaries.dart';
import '../../core/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../data/quran_repository.dart';
import '../../data/tafsir_repository.dart';
import '../../models/ayah.dart';
import '../../models/surah.dart';
import '../../state/audio_provider.dart';
import '../../state/navigation_provider.dart';
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

  /// Opens directly to this real Mushaf page number instead of the
  /// surah's first page — used to resume at the last-read position (see
  /// [HomeShell]) rather than always starting over from page one. Takes
  /// precedence over [startAtLastPage]/[skipFirstPage]/[skipLastPage].
  final int? startPage;

  const SurahDetailScreen({
    super.key,
    required this.surah,
    this.startAtLastPage = false,
    this.skipFirstPage = false,
    this.skipLastPage = false,
    this.startPage,
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

    final body = FutureBuilder<_SurahPageBundle>(
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
            surahNameAr: widget.surah.nameAr,
            surahsByNumber: bundle.surahsByNumber,
            activeSurahNumber: audio.currentSurah,
            activeAyahNumber: audio.currentAbsoluteAyah,
            fontSize: settings.quranFontSize,
            startAtLastPage: widget.startAtLastPage,
            skipFirstPage: widget.skipFirstPage,
            skipLastPage: widget.skipLastPage,
            startPage: widget.startPage,
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
    );

    // Page mode renders its own full-screen chrome (green bar, creamy
    // frame, tap-to-reveal back/reciter/search/tab-bar overlay — see
    // [_MushafPageViewState]) instead of a Scaffold appBar/FAB, so it gets
    // the entire screen rather than losing a slice of it to chrome that's
    // visible the whole time. List mode keeps the plain always-visible
    // AppBar/FAB since it has no "page" to go full-screen with.
    if (settings.quranViewMode == QuranViewMode.page) {
      return Scaffold(body: body);
    }

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
      body: body,
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
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 14),
        icon: Icon(
          playingThis && audio.isPlaying ? Icons.pause : Icons.play_arrow,
          size: 16,
        ),
        label: Text(
          'quran.play_surah'.tr(),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
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
                  arabicIndicNumber(ayah.numberInSurah),
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
      if (!mounted) return;
      setState(() {
        _tafsir = text.isEmpty ? '-' : text;
        _loadingTafsir = false;
      });
    } catch (_) {
      if (!mounted) return;
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
  final String surahNameAr;
  final Map<int, SurahSummary> surahsByNumber;
  final int? activeSurahNumber;
  final int? activeAyahNumber;
  final double fontSize;
  final bool startAtLastPage;
  final bool skipFirstPage;
  final bool skipLastPage;
  final int? startPage;
  final void Function(int delta) onAdjacentSurah;

  const _MushafPageView({
    required this.ayahs,
    required this.surahNumber,
    required this.surahNameAr,
    required this.surahsByNumber,
    required this.activeSurahNumber,
    required this.activeAyahNumber,
    required this.fontSize,
    required this.startAtLastPage,
    required this.skipFirstPage,
    required this.skipLastPage,
    required this.startPage,
    required this.onAdjacentSurah,
  });

  @override
  State<_MushafPageView> createState() => _MushafPageViewState();
}

class _MushafPageViewState extends State<_MushafPageView> {
  static const _pageBg = Color(0xFFFBF3E0);
  static const _frameGreen = Color(0xFF1F5C4A);
  static const _ink = Color(0xFF161410);

  final List<LongPressGestureRecognizer> _recognizers = [];
  late final PageController _pageController;
  late int _realPagesStart;
  late List<List<Ayah>> _screenPages;
  int? _prevSentinelIndex;
  int? _nextSentinelIndex;
  bool _navigating = false;
  int _currentIndex = 0;
  int _itemCount = 0;

  /// Whether the tap-to-reveal back/reciter/view-toggle/search bar (top)
  /// and embedded app-tab bar (bottom) are showing. Off by default so the
  /// reading view stays fully immersive — see [_toggleChrome].
  bool _chromeVisible = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<SurahSummary> _allSurahs = [];

  void _clearRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  void _toggleChrome() => setState(() => _chromeVisible = !_chromeVisible);

  @override
  void initState() {
    super.initState();

    // Cached locally (rather than read from [QuranProvider.surahs], which
    // may not have loaded yet if this screen was opened directly — e.g.
    // resuming straight into a surah on a cold start) so the in-overlay
    // surah/Juz' search below can filter synchronously as the user types.
    context.read<QuranProvider>().repository.getSurahList().then((list) {
      if (mounted) setState(() => _allSurahs = list);
    });

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
    final resumeIdx = widget.startPage == null
        ? -1
        : _screenPages.indexWhere((p) => p.first.page == widget.startPage);
    if (resumeIdx >= 0) {
      // Resuming at a specific, previously-read Mushaf page (see
      // [HomeShell]) rather than the surah's first/last page.
      initialPage = _realPagesStart + resumeIdx;
    } else if (widget.startAtLastPage) {
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
    if (!fullySkip) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _persistCurrentPage(initialPage);
      });
    }

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
    _searchController.dispose();
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
    } else {
      _persistCurrentPage(index);
    }
  }

  /// Remembers the real Mushaf page currently on screen so the Quran tab
  /// can resume here — see [SettingsProvider.setLastRead] and
  /// [HomeShell] — instead of always reopening to the surah list.
  void _persistCurrentPage(int index) {
    final pageAyahs = _screenPages[index - _realPagesStart];
    context.read<SettingsProvider>().setLastRead(
      widget.surahNumber,
      pageAyahs.first.page,
    );
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

    // No outer padding/SafeArea-on-every-side here — the green bar sits at
    // the literal top of the screen and the creamy frame's own bottom
    // border touches the screen's bottom edge, exactly like a real Mushaf
    // page filling the page it's printed on. SafeArea still protects the
    // top (status bar/notch); the bottom is deliberately left unprotected
    // since the frame's plain cream background can sit behind a home
    // indicator without anything important being obscured.
    final pageContent = SafeArea(
      bottom: false,
      child: ResponsiveCenter(
        maxWidth: 900,
        child: GestureDetector(
          // Without this, a drag/tap starting on empty space (e.g. the
          // letterboxed margins FittedBox leaves around a shrunk page)
          // wouldn't be hit-tested at all, since the default
          // `deferToChild` behavior only recognizes gestures where a
          // child actually paints.
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: _handleHorizontalDragEnd,
          // A quick tap anywhere on the page (including directly on an
          // ayah's own text, see [_buildMushafPage]'s recognizers) toggles
          // the chrome overlay; only a *held* tap on an ayah opens its
          // translation/tafsir sheet, since a plain LongPressGestureRecognizer
          // on the ayah text simply loses the gesture arena to this tap
          // recognizer on anything shorter than the long-press threshold.
          onTap: _toggleChrome,
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
              final screenPageIndex = index - _realPagesStart;
              final pageAyahs = _screenPages[screenPageIndex];
              return _buildMushafPage(context, pageAyahs, screenPageIndex);
            },
          ),
        ),
      ),
    );

    return Container(
      color: _pageBg,
      child: Stack(
        children: [
          Positioned.fill(child: pageContent),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _ChromeOverlay(
              visible: _chromeVisible,
              fromTop: true,
              child: _buildTopOverlay(context),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _ChromeOverlay(
              visible: _chromeVisible,
              fromTop: false,
              child: _buildBottomNavOverlay(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Back/view-toggle/reciter and a local surah/Juz' search, revealed by
  /// [_toggleChrome] — see [_chromeVisible].
  Widget _buildTopOverlay(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final matches = _searchMatches;
    final juzMatch = _searchJuzMatch;
    final hasQuery = _searchQuery.trim().isNotEmpty;
    return Material(
      color: _frameGreen,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: _pageBg),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: const TextStyle(color: _pageBg),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'quran.search_hint'.tr(),
                        hintStyle: TextStyle(
                          color: _pageBg.withValues(alpha: 0.7),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: _pageBg.withValues(alpha: 0.85),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.view_agenda_outlined,
                      color: _pageBg,
                    ),
                    tooltip: 'quran.view_list'.tr(),
                    onPressed: () =>
                        settings.setQuranViewMode(QuranViewMode.list),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.headphones_outlined,
                      color: _pageBg,
                    ),
                    tooltip: 'quran.reciter'.tr(),
                    onPressed: () async {
                      final settingsProvider = context
                          .read<SettingsProvider>();
                      final picked = await showReciterPicker(
                        context,
                        settings.reciter,
                      );
                      if (picked != null) {
                        await settingsProvider.setReciter(picked);
                      }
                    },
                  ),
                ],
              ),
            ),
            if (hasQuery)
              Container(
                color: _pageBg,
                constraints: const BoxConstraints(maxHeight: 280),
                child: (matches.isEmpty && juzMatch == null)
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('quran.no_results'.tr()),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          if (juzMatch != null)
                            ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.bookmark_outline,
                                color: _frameGreen,
                              ),
                              title: Text(
                                'quran.juz_label'.tr(
                                  args: [localizedNumber(context, juzMatch)],
                                ),
                              ),
                              onTap: () => _jumpToJuz(juzMatch),
                            ),
                          for (final s in matches)
                            ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: _frameGreen.withValues(
                                  alpha: 0.15,
                                ),
                                child: Text(
                                  localizedNumber(context, s.number),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              title: Text(
                                s.nameAr,
                                style: AppTheme.quranNameStyle(
                                  context,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Text(s.englishName),
                              onTap: () => _jumpToSurah(s),
                            ),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }

  /// The app's own main tabs, embedded so the user can switch away from
  /// reading without first backing out to the surah list — tapping a
  /// different tab here pops this screen and switches [HomeShell] to it
  /// via [HomeNavigationProvider], rather than a nested Navigator.
  Widget _buildBottomNavOverlay(BuildContext context) {
    final destinations = [
      (Icons.menu_book, 'nav.quran'.tr()),
      (Icons.explore_outlined, 'nav.prayer'.tr()),
      (Icons.favorite_outline, 'nav.athkar'.tr()),
      (Icons.format_quote, 'nav.hadith'.tr()),
      (Icons.settings_outlined, 'nav.settings'.tr()),
    ];
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: 0,
          onDestinationSelected: (i) {
            if (i == 0) return;
            context.read<HomeNavigationProvider>().setIndex(i);
            Navigator.of(context).popUntil((r) => r.isFirst);
          },
          destinations: [
            for (final (icon, label) in destinations)
              NavigationDestination(icon: Icon(icon), label: label),
          ],
        ),
      ),
    );
  }

  List<SurahSummary> get _searchMatches {
    final q = _searchQuery.trim();
    if (q.isEmpty) return const [];
    final qLower = q.toLowerCase();
    return _allSurahs
        .where(
          (s) =>
              s.nameAr.contains(q) ||
              s.englishName.toLowerCase().contains(qLower) ||
              s.number.toString() == q,
        )
        .take(6)
        .toList();
  }

  int? get _searchJuzMatch {
    final n = int.tryParse(_searchQuery.trim());
    if (n == null || n < 1 || n > 30) return null;
    return n;
  }

  void _jumpToSurah(SurahSummary target) {
    setState(() {
      _chromeVisible = false;
      _searchQuery = '';
    });
    _searchController.clear();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => SurahDetailScreen(surah: target)),
    );
  }

  void _jumpToJuz(int juzNumber) {
    final boundary = kJuzBoundaries[juzNumber - 1];
    final target = _allSurahs.firstWhere(
      (s) => s.number == boundary.startSurah,
      orElse: () => widget.surahsByNumber.values.first,
    );
    _jumpToSurah(target);
  }

  Widget _buildMushafPage(
    BuildContext context,
    List<Ayah> pageAyahs,
    int screenPageIndex,
  ) {
    final signsColored = context.watch<SettingsProvider>().quranSignsColored;
    final stepIndex = quranFontSizeStepIndex(widget.fontSize);
    final lineHeight = kQuranFontSizeLineHeight[stepIndex];
    final fontWeight = kQuranFontSizeWeight[stepIndex];
    final baseStyle = AppTheme.quranTextStyle(
      context,
      fontSize: widget.fontSize,
    ).copyWith(height: lineHeight, fontWeight: fontWeight, color: _ink);

    // The page's own starting surah's name banner is pinned above the
    // scaled/scrollable area (see [topBanner] below) instead of living
    // inline with the rest of the content, so it — like the footer — no
    // longer eats into the height budget that Small/Medium scale ayah text
    // to fill. A surah that starts *mid*-page (r > 0) still gets its banner
    // inline, since that's a genuine transition marker tied to specific
    // ayahs rather than this page's own running header.
    Widget? topBanner;
    final blocks = <Widget>[];
    final segments = <Widget>[];
    // Mirrors [blocks] but tags each child as scaled (real ayah text, which
    // should grow/shrink with the rest of the page) or fixed (a mid-page
    // surah banner, which — like [topBanner] — must stay a constant,
    // moderate size no matter how much the page's auto-fit needs to
    // stretch or shrink everything else; see [_PageScalerMulti]).
    void addBlock(Widget child, {bool scaled = true}) {
      blocks.add(child);
      segments.add(_ScaledSegment(scaled: scaled, child: child));
    }

    // Tracks the ayah immediately before whichever one is currently being
    // laid out, across the whole page (and the previous screen page's
    // last ayah for this page's very first one), so [ayah.hizbQuarter]
    // changing between them marks exactly the ayah where a new
    // quarter-Hizb (۞) begins — the same boundary [_isQuarterStart] finds
    // at page granularity, just checked per-ayah here so the mark can be
    // inserted inline at the right word instead of only summarized in the
    // footer.
    Ayah? prevAyah = screenPageIndex > 0
        ? _screenPages[screenPageIndex - 1].last
        : null;

    final runs = _groupBySurah(pageAyahs);
    for (var r = 0; r < runs.length; r++) {
      final run = runs[r];
      final runSurahNumber = run.first.surahNumber;
      final startsNewSurah = run.first.numberInSurah == 1;
      if (startsNewSurah) {
        final surahInfo = widget.surahsByNumber[runSurahNumber];
        final banner = _SurahBanner(
          name: surahInfo?.nameAr ?? '',
          color: _frameGreen,
        );
        if (r == 0) {
          topBanner = banner;
        } else {
          addBlock(const SizedBox(height: 18), scaled: false);
          addBlock(banner, scaled: false);
        }
        if (QuranRepository.hasSeparateBismillah(runSurahNumber)) {
          if (r > 0) addBlock(const SizedBox(height: 14));
          addBlock(
            Text(
              'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: baseStyle.copyWith(fontWeight: FontWeight.bold),
            ),
          );
        }
        addBlock(const SizedBox(height: 18));
      }

      final spans = <InlineSpan>[];
      for (final ayah in run) {
        final surahInfo = widget.surahsByNumber[ayah.surahNumber];
        final recognizer = LongPressGestureRecognizer()
          ..onLongPress = () => _showAyahSheet(
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
        final startsQuarter = prevAyah == null
            ? (ayah.surahNumber == 1 && ayah.numberInSurah == 1)
            : prevAyah.hizbQuarter != ayah.hizbQuarter;
        if (startsQuarter) {
          spans.add(
            TextSpan(
              text: '۞ ',
              style: baseStyle.copyWith(
                color: _frameGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }
        spans.add(
          TextSpan(
            text: ayah.textAr,
            style: baseStyle.copyWith(background: highlight),
            recognizer: recognizer,
          ),
        );
        spans.add(
          TextSpan(
            text: '۝${arabicIndicNumber(ayah.numberInSurah)}',
            style: baseStyle.copyWith(
              color: _frameGreen,
              fontWeight: FontWeight.bold,
              background: highlight,
            ),
            recognizer: recognizer,
          ),
        );
        spans.add(const TextSpan(text: ' '));
        prevAyah = ayah;
      }
      final ayahText = Text.rich(
        TextSpan(children: spans),
        textAlign: TextAlign.justify,
        textDirection: TextDirection.rtl,
      );
      // The waqf marks, sajda sign and ۞/۝ markers above get their color
      // either from the font's own glyphs (Amiri Quran ships several of
      // these in color) or from an explicit [TextStyle.color] — a
      // [ColorFilter] in `srcIn` mode replaces every opaque pixel with one
      // flat color regardless of which of those it came from, so this is
      // the one place that can turn both off at once for
      // [SettingsProvider.quranSignsColored].
      addBlock(
        signsColored
            ? ayahText
            : ColorFiltered(
                colorFilter: ColorFilter.mode(_ink, BlendMode.srcIn),
                child: ayahText,
              ),
      );
    }

    final lastAyah = pageAyahs.last;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: blocks,
    );

    // Page-number/Hizb footer — pinned right above the frame's own bottom
    // border (see [pageArea] below) rather than inside the
    // scaled/scrollable content, so it no longer eats into Small/Medium's
    // fill-the-page height budget. Juz' isn't repeated here since it's
    // already shown in the green bar above the frame for every page. Both
    // numbers share one small rectangular frame, like the printed marks on
    // a real Mushaf page, in the same Amiri Quran font as the body text
    // rather than the app's UI font. The Hizb side only appears on the
    // page where a quarter-Hizb actually begins (see [_isQuarterStart]) —
    // showing it on every page it merely continues through would just
    // repeat the same label for several pages in a row.
    String? hizbWord;
    String? hizbNumber;
    String? hizbFraction;
    if (_isQuarterStart(screenPageIndex)) {
      // The quarter that just started may have been reached partway
      // through this page rather than right at its first ayah — e.g. Al
      // Baqarah's ¼-Hizb mark falls at ayah 26, mid-page — so the Hizb/
      // quarter to announce is whichever one is active by the page's
      // *last* ayah, not its first.
      final newQuarterAyah = pageAyahs.last;
      hizbWord = 'quran.hizb_word'.tr();
      hizbNumber = localizedNumber(context, newQuarterAyah.hizb);
      hizbFraction = _hizbQuarterFraction(context, newQuarterAyah.quarterInHizb);
    }
    final footer = Center(
      child: _footerBadge(
        context,
        hizbWord: hizbWord,
        hizbNumber: hizbNumber,
        hizbFraction: hizbFraction,
        pageText: localizedNumber(context, lastAyah.page),
      ),
    );

    // Small and Medium must always fit without scrolling AND fill the full
    // frame width and height — not just shrink-to-fit, which (see
    // [_PageScaler]) leaves a narrow column with large empty margins on
    // narrow phones, since uniformly scaling text that's already pinned to
    // the full width down to fit the height also shrinks the width. Large
    // skips all of that, since it's deliberately large enough to commonly
    // overflow and is meant to be read by scrolling instead. Which tier
    // fits-the-page is looked up via [kQuranFontSizeFitsPage] rather than
    // comparing raw values, so Small/Medium's font sizes can be tuned
    // independently of Large's without flipping which ones scroll.
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
    final fitsPage = kQuranFontSizeFitsPage[stepIndex];
    final allowScroll = !fitsPage;
    final innerArea = LayoutBuilder(
      builder: (context, constraints) {
        if (!allowScroll) {
          return _PageScalerMulti(children: segments);
        }
        // Large: render at natural size, hugging the top of the
        // available height when it fits; when it doesn't, the text scrolls
        // inside the frame, which (via the Expanded below) stays fixed at
        // the full screen size the whole time.
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(width: constraints.maxWidth, child: content),
            ),
          ),
        );
      },
    );

    final pageArea = _OrnateFrame(
      color: _frameGreen,
      background: _pageBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (topBanner != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: topBanner,
            ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                topBanner != null ? 6 : 14,
                18,
                4,
              ),
              child: innerArea,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
            child: footer,
          ),
        ],
      ),
    );

    // The cream background always fills the full page extent given by the
    // PageView (matching the device's screen, in any orientation, on both
    // phone and tablet) — Expanded stretches it to that size regardless of
    // how big the framed content within it ends up being.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pageAyahs.isNotEmpty) _buildGreenBar(context, pageAyahs),
        Expanded(child: pageArea),
      ],
    );
  }

  /// The screen's permanent top chrome (the tap-to-reveal overlay in
  /// [build] sits *above* this, covering it while shown): the surah name
  /// and Juz' number sit at the bar's start/end sides — following the
  /// ambient reading direction, so in Arabic (RTL) that's surah-name-right,
  /// Juz'-left, and in English (LTR) surah-name-left, Juz'-right — with
  /// the play/pause button fixed dead-center via the [Stack] regardless of
  /// how long either label is.
  Widget _buildGreenBar(BuildContext context, List<Ayah> pageAyahs) {
    return Material(
      color: _frameGreen,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        widget.surahNameAr,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.quranNameStyle(
                          context,
                          fontSize: 16,
                          color: _pageBg,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Text(
                          'quran.juz_label'.tr(
                            args: [
                              localizedNumber(context, pageAyahs.first.juz),
                            ],
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
                  ],
                ),
              ),
              _buildPlayButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayButton(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final audio = context.watch<AudioProvider>();
    final reciter = settings.reciter;
    final isPlayingThis =
        audio.currentSurah == widget.surahNumber &&
        audio.currentReciter?.id == reciter.id &&
        audio.isPlaying;
    return Material(
      color: _pageBg,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () async {
          if (!reciter.hasSurah(widget.surahNumber)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('quran.reciter_unavailable'.tr())),
            );
            return;
          }
          await context.read<AudioProvider>().playSurah(
            widget.surahNumber,
            reciter,
            resume: true,
            surahTitle: widget.surahNameAr,
          );
        },
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            isPlayingThis ? Icons.pause : Icons.play_arrow,
            color: _frameGreen,
            size: 20,
          ),
        ),
      ),
    );
  }

  /// A page belongs to the same quarter-Hizb as several pages around it
  /// (each quarter spans roughly 2-3 Mushaf pages), so the quarter only
  /// "begins" on whichever single page first reaches it — every other
  /// page in that span is a continuation. The boundary ayah is almost
  /// never a page's first ayah — e.g. Al Baqarah's ¼-Hizb mark falls at
  /// ayah 26, mid-page — so this checks for *any* change in
  /// [Ayah.hizbQuarter] from this page's first ayah to its last, not just
  /// at the page edge; it also checks against the previous screen page's
  /// last ayah to catch a boundary that lands exactly on this page's
  /// first ayah. The very first loaded screen page has no earlier ayah to
  /// compare against for that second check, so it can only detect a
  /// mid-page change there.
  bool _isQuarterStart(int screenPageIndex) {
    final pageAyahs = _screenPages[screenPageIndex];
    final first = pageAyahs.first;
    // The Quran's very first ayah is unconditionally Hizb 1's own start —
    // the one boundary that's always knowable even with no earlier ayah
    // loaded to compare against.
    if (first.surahNumber == 1 && first.numberInSurah == 1) return true;
    if (screenPageIndex > 0) {
      final prevLast = _screenPages[screenPageIndex - 1].last;
      if (prevLast.hizbQuarter != first.hizbQuarter) return true;
    }
    return pageAyahs.last.hizbQuarter != first.hizbQuarter;
  }

  /// [Ayah.quarterInHizb] 1 is the Hizb's own start (no fraction mark
  /// needed — the bare Hizb number already says that); 2/3/4 are a
  /// quarter, half and three-quarters of the way through it.
  String? _hizbQuarterFraction(BuildContext context, int quarterInHizb) {
    switch (quarterInHizb) {
      case 2:
        return '${localizedNumber(context, 1)}/${localizedNumber(context, 4)}';
      case 3:
        return '${localizedNumber(context, 1)}/${localizedNumber(context, 2)}';
      case 4:
        return '${localizedNumber(context, 3)}/${localizedNumber(context, 4)}';
      default:
        return null;
    }
  }

  Widget _footerBadge(
    BuildContext context, {
    String? hizbWord,
    String? hizbNumber,
    String? hizbFraction,
    required String pageText,
  }) {
    final style = AppTheme.quranTextStyle(context, fontSize: 11).copyWith(
      color: _frameGreen,
      fontWeight: FontWeight.bold,
      height: 1,
    );
    const gap = SizedBox(width: 4);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _frameGreen, width: 1.2),
      ),
      // Literal child order, left as-is rather than swapped for RTL/LTR —
      // ambient [Directionality] already mirrors a [Row]'s start/end edge
      // per locale, which is exactly the "fraction beside the Hizb word on
      // one side, number on the other, swapped between Arabic and English"
      // layout asked for: in Arabic this renders fraction-word-number
      // right-to-left (fraction visually on the word's right, number on
      // its left), and the same order in English renders left-to-right
      // (fraction on the word's left, number on its right).
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hizbWord != null) ...[
            if (hizbFraction != null) ...[
              Text(hizbFraction, style: style),
              gap,
            ],
            Text(hizbWord, style: style),
            gap,
            Text(hizbNumber!, style: style),
            gap,
            Text('-', style: style),
            gap,
          ],
          Text(pageText, style: style),
        ],
      ),
    );
  }
}

/// Slides + fades a chrome overlay bar in/out of view, and stops it from
/// intercepting taps (which would otherwise still land on, say, an
/// invisible back button) while hidden.
class _ChromeOverlay extends StatelessWidget {
  final bool visible;
  final bool fromTop;
  final Widget child;

  const _ChromeOverlay({
    required this.visible,
    required this.fromTop,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        offset: visible ? Offset.zero : Offset(0, fromTop ? -1 : 1),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: visible ? 1 : 0,
          child: child,
        ),
      ),
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

  /// Always a fixed, moderate size regardless of the page's selected Quran
  /// font tier — Small/Medium/Large's raw values exist to drive the
  /// auto-fit body text (see [kQuranFontSizeSteps]), not to size chrome
  /// like this banner, so using them directly here made the banner swing
  /// too large for Medium and too small for Small/Large.
  static const double _fontSize = 22;

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
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                name,
                textDirection: TextDirection.rtl,
                style: AppTheme.quranNameStyle(
                  context,
                  fontSize: _fontSize,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('❁', style: TextStyle(color: color, fontSize: 16)),
        ],
      ),
    );
  }
}

/// Marks a child of [_PageScalerMulti] as either part of the scaled ayah
/// flow ([scaled] true — grows/shrinks with the rest of the page, like
/// regular Mushaf body text) or pinned to a fixed, natural size ([scaled]
/// false — a mid-page surah banner, which must look the same size no
/// matter how much the page's auto-fit needs to stretch or shrink
/// everything else, exactly like [SurahDetailScreen]'s pinned top banner).
class _ScaledSegment extends ParentDataWidget<_PageScalerParentData> {
  final bool scaled;

  const _ScaledSegment({required this.scaled, required super.child});

  @override
  void applyParentData(RenderObject renderObject) {
    final parentData = renderObject.parentData! as _PageScalerParentData;
    if (parentData.scaled != scaled) {
      parentData.scaled = scaled;
      final targetParent = renderObject.parent;
      if (targetParent is RenderObject) targetParent.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _PageScalerMulti;
}

class _PageScalerParentData extends ContainerBoxParentData<RenderBox> {
  bool scaled = true;
}

/// Fills the available box exactly, both width and height, like the
/// single-child version this generalizes: children tagged [_ScaledSegment]
/// `scaled: true` are laid out together at whichever width makes their
/// combined natural (unscaled) height match the box once uniformly scaled
/// back to the available width — the same wider-or-narrower virtual-width
/// search described below — while `scaled: false` children (mid-page surah
/// banners) are laid out at their natural size and never touched by that
/// scale, so they stay a constant, moderate size no matter how dense or
/// sparse the rest of the page is.
///
/// A plain `FittedBox(fit: BoxFit.scaleDown)` can't do the scaled portion
/// alone: it has to be told a width to wrap the text at, and the only width
/// it can be handed ahead of time is the box's own available width. If the
/// text is then naturally too *tall* for the available height at that width
/// (common on narrow phones, where more line-wrapping makes the block
/// taller), the uniform scale that shrinks it down to fit the height also
/// shrinks its *width* by the same factor — leaving a narrow column of small
/// text stranded in the middle of a mostly-empty page instead of filling
/// it. This searches for a wider "virtual" wrap width that makes the
/// scaled content's natural aspect ratio already match the available box,
/// so the one uniform scale it does apply fills both dimensions at once.
class _PageScalerMulti extends MultiChildRenderObjectWidget {
  const _PageScalerMulti({required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPageScalerMulti();
}

class _RenderPageScalerMulti extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _PageScalerParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _PageScalerParentData> {
  final Map<RenderBox, Matrix4> _transforms = {};
  bool _hasVisualOverflow = false;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PageScalerParentData) {
      child.parentData = _PageScalerParentData();
    }
  }

  List<RenderBox> _scaledChildren() {
    final result = <RenderBox>[];
    RenderBox? child = firstChild;
    while (child != null) {
      if ((child.parentData! as _PageScalerParentData).scaled) {
        result.add(child);
      }
      child = childAfter(child);
    }
    return result;
  }

  double _scaledNaturalHeightAt(List<RenderBox> scaledChildren, double width) {
    var total = 0.0;
    for (final child in scaledChildren) {
      total += child.getDryLayout(BoxConstraints.tightFor(width: width)).height;
    }
    return total;
  }

  @override
  void performLayout() {
    final BoxConstraints c = constraints;
    final double availW = c.maxWidth;
    final double availH = c.maxHeight;

    var fixedHeight = 0.0;
    RenderBox? child = firstChild;
    while (child != null) {
      final pd = child.parentData! as _PageScalerParentData;
      if (!pd.scaled) {
        child.layout(BoxConstraints.tightFor(width: availW), parentUsesSize: true);
        fixedHeight += child.size.height;
      }
      child = childAfter(child);
    }

    final double remainingH = availH - fixedHeight;
    final scaledChildren = _scaledChildren();
    final double naturalAtAvailW = _scaledNaturalHeightAt(scaledChildren, availW);
    double chosenWidth = availW;

    // Same binary search as the single-child version, just measuring the
    // combined height of every scaled child at each candidate width instead
    // of one child's height.
    if (remainingH.isFinite &&
        naturalAtAvailW > 0 &&
        naturalAtAvailW != remainingH) {
      final bool tooTall = naturalAtAvailW > remainingH;
      double lo = tooTall ? availW : availW / 64;
      double hi = tooTall ? availW : availW;
      double boundary = tooTall ? availW * 4 : availW;
      double boundaryNat = _scaledNaturalHeightAt(scaledChildren, boundary);
      var guard = 0;
      bool stillNeedsSearch(double natH, double w) => tooTall
          ? natH * availW / w > remainingH
          : natH * availW / w < remainingH;
      while (stillNeedsSearch(boundaryNat, boundary) && guard < 6) {
        boundary = tooTall ? boundary * 2 : boundary / 2;
        boundaryNat = _scaledNaturalHeightAt(scaledChildren, boundary);
        guard++;
      }
      if (tooTall) {
        hi = boundary;
      } else {
        lo = boundary;
      }
      for (var i = 0; i < 14; i++) {
        final double mid = (lo + hi) / 2;
        final double midNat = _scaledNaturalHeightAt(scaledChildren, mid);
        final double scaledHeight = midNat * availW / mid;
        final bool stillTooShortOrTall = tooTall
            ? scaledHeight > remainingH
            : scaledHeight < remainingH;
        if (stillTooShortOrTall) {
          if (tooTall) {
            lo = mid;
          } else {
            hi = mid;
          }
        } else {
          if (tooTall) {
            hi = mid;
          } else {
            lo = mid;
          }
        }
      }
      chosenWidth = tooTall ? hi : lo;
    }

    final double scaleFactor = remainingH.isFinite && naturalAtAvailW > 0
        ? availW / chosenWidth
        : 1.0;

    _transforms.clear();
    _hasVisualOverflow = false;
    var offsetY = 0.0;
    child = firstChild;
    while (child != null) {
      final pd = child.parentData! as _PageScalerParentData;
      if (!pd.scaled) {
        pd.offset = Offset(0, offsetY);
        offsetY += child.size.height;
      } else {
        child.layout(BoxConstraints.tightFor(width: chosenWidth), parentUsesSize: true);
        final double scaledHeight = child.size.height * scaleFactor;
        _transforms[child] = Matrix4.translationValues(0, offsetY, 0)
          ..scaleByDouble(scaleFactor, scaleFactor, 1.0, 1);
        pd.offset = Offset(0, offsetY);
        offsetY += scaledHeight;
      }
      child = childAfter(child);
    }
    // Binary-search convergence can leave a sub-pixel mismatch between the
    // final content height and availH; only clip if that ever grows large
    // enough to be visible, so this rarely costs an extra layer.
    _hasVisualOverflow = offsetY > availH + 0.5;

    size = c.constrain(Size(availW, availH));
  }

  void _paintChildren(PaintingContext context, Offset offset) {
    RenderBox? child = firstChild;
    while (child != null) {
      final pd = child.parentData! as _PageScalerParentData;
      final transform = _transforms[child];
      if (transform == null) {
        context.paintChild(child, offset + pd.offset);
      } else {
        context.pushTransform(needsCompositing, offset, transform, (
          context,
          offset,
        ) {
          context.paintChild(child!, offset);
        });
      }
      child = childAfter(child);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_hasVisualOverflow) {
      _paintChildren(context, offset);
      return;
    }
    layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      _paintChildren,
      oldLayer: layer is ClipRectLayer ? layer! as ClipRectLayer : null,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    RenderBox? child = lastChild;
    while (child != null) {
      final pd = child.parentData! as _PageScalerParentData;
      final transform = _transforms[child];
      final bool isHit;
      if (transform == null) {
        isHit = result.addWithPaintOffset(
          offset: pd.offset,
          position: position,
          hitTest: (result, transformed) =>
              child!.hitTest(result, position: transformed),
        );
      } else {
        isHit = result.addWithPaintTransform(
          transform: transform,
          position: position,
          hitTest: (result, transformed) =>
              child!.hitTest(result, position: transformed),
        );
      }
      if (isHit) return true;
      child = (child.parentData! as _PageScalerParentData).previousSibling;
    }
    return false;
  }

  // RenderBox's default applyPaintTransform only translates by the child's
  // parentData.offset, which is correct for fixed children but wrong for
  // scaled ones — those also need the scale factor folded in, or every
  // ancestor-to-descendant coordinate mapping that relies on this (hit
  // testing via the test framework's tester.tap, accessibility,
  // Scrollable.ensureVisible, etc.) ends up off by that factor.
  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    final pd = child.parentData! as _PageScalerParentData;
    final childTransform = _transforms[child];
    if (childTransform != null) {
      transform.multiply(childTransform);
    } else {
      transform.translateByDouble(pd.offset.dx, pd.offset.dy, 0, 1);
    }
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

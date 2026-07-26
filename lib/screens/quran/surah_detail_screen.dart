import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:pasteboard/pasteboard.dart';
import 'package:provider/provider.dart';
import '../../core/arabic_numbers.dart';
import '../../core/constants/juz_boundaries.dart';
import '../../core/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../data/athkar_repository.dart';
import '../../data/quran_repository.dart';
import '../../data/tafsir_repository.dart';
import '../../models/ayah.dart';
import '../../models/surah.dart';
import '../../models/thikr.dart';
import '../../state/audio_provider.dart';
import '../../state/navigation_provider.dart';
import '../../state/quran_provider.dart';
import '../../state/settings_provider.dart';
import '../../widgets/reciter_picker_sheet.dart';
import '../../widgets/responsive_center.dart';

/// Whether [text] contains any word built on the س-ج-د (prostration) root —
/// used both to find the actual word to overline within an obligatory-sajda
/// ayah, and to detect the one case in the Quran (41:38) where the sajda
/// *sign* sits on an ayah whose own text has no such word at all, because
/// the real trigger ("وَٱسْجُدُوا۟") falls in the ayah just before it.
bool ayahHasSajdaTriggerWord(String text) {
  return text.split(' ').any((w) => normalizeArabicSearch(w).contains('سجد'));
}

/// Splits an ayah's text into spans, drawing an overline over the one word
/// that actually commands prostration when [overlineSajdaWord] is set —
/// matching how a printed Mushaf marks an *obligatory* sajda: the place-of-
/// sajda sign at the ayah's end never changes, but the specific trigger
/// word gets a line above it. The word itself keeps its normal ink color;
/// only the line is green, matching the sajda sign's color rather than the
/// surrounding text. Shared by the Mushaf page view and the separate list
/// view so both mark the trigger word identically.
List<InlineSpan> _ayahTextSpans({
  required String text,
  required TextStyle style,
  required GestureRecognizer? recognizer,
  required bool overlineSajdaWord,
}) {
  if (!overlineSajdaWord) {
    return [TextSpan(text: text, style: style, recognizer: recognizer)];
  }
  final words = text.split(' ');
  // The *last* matching word, not the first: 41:37 — the one ayah where the
  // overline lands on a different ayah than the sajda sign itself (see
  // [ayahHasSajdaTriggerWord]) — says "do not prostrate to the sun or
  // moon, but prostrate to Allah" (لَا تَسْجُدُوا۟ ... وَٱسْجُدُوا۟
  // لِلَّهِ), so the first سجد-rooted word is the *negated* one; the actual
  // command is always the last.
  final sajdaWordIndex = words.lastIndexWhere(
    (w) => normalizeArabicSearch(w).contains('سجد'),
  );
  if (sajdaWordIndex == -1) {
    return [TextSpan(text: text, style: style, recognizer: recognizer)];
  }
  final spans = <InlineSpan>[];
  for (var i = 0; i < words.length; i++) {
    if (i > 0) {
      spans.add(TextSpan(text: ' ', style: style, recognizer: recognizer));
    }
    // The KFGQPC Mushaf text already marks most sajda trigger words with the
    // authentic Madinah overline as a font glyph — U+06E4 (SMALL HIGH MADDA),
    // the long bar above the word. Drawing our own TextDecoration.overline on
    // top of those produced a doubled line (see 96:19 وَٱسۡجُدۡۤ). So only draw
    // our overline for the few sajda words the text doesn't already mark, and
    // otherwise leave the single font bar to stand on its own.
    final fontAlreadyOverlines = words[i].contains('ۤ');
    final isSajdaWord = i == sajdaWordIndex && !fontAlreadyOverlines;
    spans.add(
      TextSpan(
        text: words[i],
        style: isSajdaWord
            ? style.copyWith(
                decoration: TextDecoration.overline,
                decorationColor: _MushafPageViewState._frameGreen,
                decorationThickness: 2,
                // Extra leading just for this one word, so the overline
                // gets clearance from the line above instead of crowding
                // into its diacritics — [TextDecoration.overline] draws
                // right at the top of the run's own line box, which at
                // the surrounding paragraph's normal line height sits
                // almost flush against the line above.
                height: (style.height ?? 1.0) + 0.4,
              )
            : style,
        recognizer: recognizer,
      ),
    );
  }
  return spans;
}

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

  /// Crosses a surah boundary by *Mushaf page*, not by surah. [boundaryPage]
  /// is the real page the swipe left from (the current surah's first page when
  /// going back, its last page when going forward); the target is simply the
  /// adjacent page. Whichever surah owns that page is opened *at* it.
  ///
  /// This replaces the old surah-by-surah hop, whose "skip an already-shown
  /// shared page" rule cascaded across every single-page surah that shares a
  /// page — so one back-swipe from An-Nas (p.604) leapt 14 surahs to p.599,
  /// skipping pages 600-603 entirely. Paging by page can't skip a page: each
  /// one is shown exactly once on its way past.
  Future<void> _goToAdjacentSurah(
    BuildContext context,
    int delta,
    int boundaryPage,
  ) async {
    final targetPage = boundaryPage + delta;
    if (targetPage < 1 || targetPage > 604) return;
    final repo = context.read<QuranProvider>().repository;
    final pageAyahs = await repo.getPageAyahs(targetPage);
    if (pageAyahs.isEmpty || !context.mounted) return;
    // The surah the page "belongs to" — the lowest-numbered one with an ayah
    // on it. Opening that surah at [targetPage] still renders the whole page
    // (boundary sharing pulls in every surah that appears on it), so the page
    // looks identical no matter which of its surahs technically hosts it.
    final targetNumber = pageAyahs
        .map((a) => a.surahNumber)
        .reduce((a, b) => a < b ? a : b);
    final list = await repo.getSurahList();
    if (!context.mounted) return;
    SurahSummary? target;
    for (final s in list) {
      if (s.number == targetNumber) {
        target = s;
        break;
      }
    }
    if (target == null) return;
    final resolvedTarget = target;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SurahDetailScreen(
          surah: resolvedTarget,
          startPage: targetPage,
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
            bookmarkedSurahNumber: settings.bookmarkSurah,
            bookmarkedAyahNumber: settings.bookmarkAyah,
            fontSize: settings.quranFontSize,
            startAtLastPage: widget.startAtLastPage,
            skipFirstPage: widget.skipFirstPage,
            skipLastPage: widget.skipLastPage,
            startPage: widget.startPage,
            onAdjacentSurah: (delta, boundaryPage) =>
                _goToAdjacentSurah(context, delta, boundaryPage),
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
                final listStepIndex = quranFontSizeStepIndex(
                  settings.quranFontSize,
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: AppTheme.quranTextStyle(
                      context,
                      fontSize: kQuranListViewFontSizes[listStepIndex],
                    ).copyWith(
                      height: kQuranFontSizeLineHeight[listStepIndex],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }
              final ayahIndex = showBismillah ? index - 1 : index;
              final ayah = ayahs[ayahIndex];
              final prevAyah = ayahIndex > 0 ? ayahs[ayahIndex - 1] : null;
              final isQuarterStart = prevAyah != null
                  ? prevAyah.hizbQuarter != ayah.hizbQuarter
                  : (ayah.numberInSurah == 1 &&
                        (ayah.surahNumber == 1 ||
                            kSurahsStartingNewQuarterAtAyah1.contains(
                              ayah.surahNumber,
                            )));
              // See the matching comment in [_MushafPageViewState]: 41:38
              // is the one ayah in the Quran where the sajda sign sits on
              // an ayah whose own text has no سجد-rooted word, because the
              // real trigger word is in the ayah just before it.
              final nextAyah = ayahIndex + 1 < ayahs.length
                  ? ayahs[ayahIndex + 1]
                  : null;
              final overlineSajdaWord = ayah.sajdaObligatory
                  ? ayahHasSajdaTriggerWord(ayah.textAr)
                  : (nextAyah != null &&
                        nextAyah.sajdaObligatory &&
                        ayahHasSajdaTriggerWord(ayah.textAr) &&
                        !ayahHasSajdaTriggerWord(nextAyah.textAr));
              return _AyahCard(
                ayah: ayah,
                totalAyahs: widget.surah.numberOfAyahs,
                isActive: activeAyah == ayah.numberInSurah,
                surahNameAr: widget.surah.nameAr,
                isQuarterStart: isQuarterStart,
                overlineSajdaWord: overlineSajdaWord,
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

    // Forced ltr (rather than mirroring with the ambient locale direction)
    // so the play button always sits physically to the right of the surah
    // name on screen, in both Arabic and English UI — same reasoning as the
    // Mushaf footer badge's [Alignment.centerLeft] further down.
    final titleRow = Row(
      textDirection: TextDirection.ltr,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.surah.nameAr,
          style: AppTheme.quranNameStyle(
            context,
            fontSize: 20,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 14),
        IconButton(
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
          tooltip: 'quran.play_surah'.tr(),
          icon: Icon(
            playingThis && audio.isPlaying
                ? Icons.pause_circle_filled
                : Icons.play_circle_fill,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: titleRow,
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
    );
  }
}

class _AyahCard extends StatelessWidget {
  final Ayah ayah;
  final int totalAyahs;
  final bool isActive;
  final String surahNameAr;
  final bool isQuarterStart;
  final bool overlineSajdaWord;

  const _AyahCard({
    required this.ayah,
    required this.totalAyahs,
    required this.isActive,
    required this.surahNameAr,
    required this.isQuarterStart,
    required this.overlineSajdaWord,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final audio = context.watch<AudioProvider>();
    final signsColored = settings.quranSignsColored;
    final listStepIndex = quranFontSizeStepIndex(settings.quranFontSize);
    // Matches [_MushafPageViewState._buildMushafPage]'s line-height override
    // — the KFGQPC face's tall diacritic stacks need that much room in list
    // view too, not just the page view; without it, this fell back to
    // [AppTheme.quranTextStyle]'s generic 1.9, which was too tight for them.
    final baseStyle = AppTheme.quranTextStyle(
      context,
      fontSize: kQuranListViewFontSizes[listStepIndex],
    ).copyWith(height: kQuranFontSizeLineHeight[listStepIndex]);
    final spans = <InlineSpan>[
      if (isQuarterStart)
        TextSpan(
          text: '۞ ',
          style: baseStyle.copyWith(
            color: _MushafPageViewState._frameGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ..._ayahTextSpans(
        text: ayah.textAr,
        style: baseStyle,
        recognizer: null,
        overlineSajdaWord: overlineSajdaWord,
      ),
      if (ayah.sajda)
        TextSpan(
          text: ' ۩',
          style: TextStyle(
            fontSize: baseStyle.fontSize,
            height: baseStyle.height,
            color: _MushafPageViewState._frameGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
    ];
    // Unlike the Mushaf page (always printed on a fixed cream background),
    // the list view sits on the themed surface, so its text must follow the
    // theme — white on dark, black on light. When signs are set to render
    // uncolored, flatten the quarter-Hizb / sajda / overline colors down to
    // that same themed body color (not the fixed Mushaf ink, which left the
    // text near-black and invisible on a dark background).
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final ayahText = Text.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.right,
      textDirection: TextDirection.rtl,
    );
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
                child: signsColored
                    ? ayahText
                    : ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          onSurface,
                          BlendMode.srcIn,
                        ),
                        child: ayahText,
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
                  final messenger = ScaffoldMessenger.of(context);
                  final startedAtAyah = await context
                      .read<AudioProvider>()
                      .playFromAyah(
                        surahNumber: ayah.surahNumber,
                        ayahNumberInSurah: ayah.numberInSurah,
                        totalAyahsInSurah: totalAyahs,
                        reciter: reciter,
                        surahTitle: surahNameAr,
                      );
                  if (!startedAtAyah) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'quran.ayah_playback_unavailable'.tr(
                            args: [reciter.nameAr],
                          ),
                        ),
                      ),
                    );
                  }
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

  /// The whole ayah exactly as the Mushaf page renders it — its text plus
  /// its ayah-end number, nothing else — never a fragment, and matching what
  /// selecting the same ayah on the page copies.
  String _copyText() =>
      ayahWithEndMarker(widget.ayah.textAr, widget.ayah.numberInSurah);

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    final settings = context.watch<SettingsProvider>();
    final isBookmarked =
        settings.bookmarkSurah == widget.ayah.surahNumber &&
        settings.bookmarkAyah == widget.ayah.numberInSurah;
    // Everything the sheet shows, in reading order, so pasting elsewhere
    // reproduces what the reader sees rather than a bare fragment.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              ),
              tooltip: 'quran.toggle_ayah_bookmark'.tr(),
              onPressed: () {
                final messenger = ScaffoldMessenger.of(context);
                if (isBookmarked) {
                  settings.clearBookmark();
                  messenger.showSnackBar(
                    SnackBar(content: Text('quran.ayah_bookmark_removed'.tr())),
                  );
                } else {
                  settings.setBookmark(
                    widget.ayah.surahNumber,
                    widget.ayah.page,
                    ayah: widget.ayah.numberInSurah,
                  );
                  messenger.showSnackBar(
                    SnackBar(content: Text('quran.ayah_bookmark_added'.tr())),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: 'quran.copy_ayah'.tr(),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(
                  ClipboardData(text: _copyText()),
                );
                messenger.showSnackBar(
                  SnackBar(content: Text('quran.ayah_copied'.tr())),
                );
              },
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 4),
          ],
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
                  // Same line-height override as the page/list views (see
                  // [kQuranFontSizeLineHeight]) — the default 1.9 from
                  // [AppTheme.quranTextStyle] is too tight for this font's
                  // tall diacritic stacks.
                  style: AppTheme.quranTextStyle(
                    context,
                    fontSize: 24,
                  ).copyWith(height: kQuranFontSizeLineHeight.first),
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
                      final messenger = ScaffoldMessenger.of(context);
                      final startedAtAyah = await audio.playFromAyah(
                        surahNumber: widget.ayah.surahNumber,
                        ayahNumberInSurah: widget.ayah.numberInSurah,
                        totalAyahsInSurah: widget.totalAyahs,
                        reciter: reciter,
                        surahTitle: widget.surahNameAr,
                      );
                      if (!startedAtAyah) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'quran.ayah_playback_unavailable'.tr(
                                args: [reciter.nameAr],
                              ),
                            ),
                          ),
                        );
                      }
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
  // The surah/ayah of the user's manually-placed bookmark (see
  // [SettingsProvider.bookmarkSurah]/[bookmarkAyah]), when it was placed on
  // a specific ayah rather than just a page — highlighted distinctly from
  // [activeAyahNumber] so the reader can spot exactly where they left off
  // once they land back on that page.
  final int? bookmarkedSurahNumber;
  final int? bookmarkedAyahNumber;
  final double fontSize;
  final bool startAtLastPage;
  final bool skipFirstPage;
  final bool skipLastPage;
  final int? startPage;
  final void Function(int delta, int boundaryPage) onAdjacentSurah;

  const _MushafPageView({
    required this.ayahs,
    required this.surahNumber,
    required this.surahNameAr,
    required this.surahsByNumber,
    required this.activeSurahNumber,
    required this.activeAyahNumber,
    required this.bookmarkedSurahNumber,
    required this.bookmarkedAyahNumber,
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

class _MushafPageViewState extends State<_MushafPageView>
    // Plural [TickerProviderStateMixin], not the Single- variant: every page
    // turn spins up its own short-lived AnimationController (see
    // [_startPageTurn]), and the single-ticker mixin only ever hands out one
    // ticker for the State's whole life — so the first swipe worked but every
    // turn after it silently failed to animate (and thus never committed the
    // page change), which looked like swiping back/forward "stops working"
    // after one page.
    with TickerProviderStateMixin {
  static const _pageBg = Color(0xFFFBF3E0);
  static const _frameGreen = Color(0xFF1F5C4A);
  static const _ink = Color(0xFF161410);
  static const _bookmarkGold = Color(0xFFB8860B);

  // Keyed by [Ayah.number] (global, unique across the whole Quran) and kept
  // alive for this whole surah-viewing session rather than recreated every
  // build — a long press has a real, multi-frame pending window between the
  // finger going down and [LongPressGestureRecognizer.onLongPress] firing,
  // and recreating+disposing every ayah's recognizer on each rebuild (as a
  // plain per-build list used to) would tear down whichever one is mid-press
  // the moment a rebuild happens for *any* reason — including the rebuild
  // [_pressedAyahNumber]'s own setState now triggers on every press-down, so
  // the long-press would never get the chance to actually fire.
  final Map<int, LongPressGestureRecognizer> _recognizersByAyah = {};
  // Only used while [_selectMode] is on: taps then pick whole ayahs instead
  // of toggling the chrome.
  final Map<int, TapGestureRecognizer> _selectRecognizersByAyah = {};
  late final PageController _pageController;
  late int _realPagesStart;
  late List<List<Ayah>> _screenPages;
  int? _prevSentinelIndex;
  int? _nextSentinelIndex;
  // Set once this screen's last Mushaf page is the Quran's very last page
  // (604) — reserves one extra, real slot right after it for a closing
  // "Khatm al-Quran" dua screen, so reaching the end of the whole Quran
  // lands somewhere deliberate instead of the swipe dead-ending on a
  // next-surah sentinel that can never resolve (see [initState]'s
  // `reachesQuranEnd`). [_handleScaleEnd]'s `target != _currentIndex` check
  // already stops the swipe cold once [_itemCount] is reached — this only
  // changes what that final index actually shows.
  int? _khatmIndex;
  bool _navigating = false;
  int _itemCount = 0;
  int _currentIndex = 0;

  /// Drives the manual page-turn slide (see [_startPageTurn]) — built
  /// entirely ourselves, independent of [PageView]'s own `reverse`/ambient
  /// [Directionality]-driven transition, so its on-screen slide direction
  /// always matches the swipe by construction rather than depending on how
  /// [PageView] happens to resolve `AxisDirection` for RTL-and-reversed.
  AnimationController? _turnController;
  int? _turnFromIndex;
  int? _turnToIndex;
  bool _turnSlideLeft = false;

  /// Manual pinch-zoom for the current page, on top of Small/Medium's own
  /// auto-fit scale (see [kQuranFontSizeFitsPage]) — Large already renders
  /// at its natural size and scrolls, so it doesn't need this. Reset back to
  /// 1.0/[Offset.zero] every time the page changes, see [_onPageChanged].
  double _zoomScale = 1.0;
  Offset _zoomOffset = Offset.zero;

  /// The ayah currently being held down on (identified by its global
  /// [Ayah.number], unique across the whole Quran), so it can show a
  /// pressed-state shadow for as long as the finger stays down — set as
  /// soon as the pointer lands (not just once the long-press threshold to
  /// open the tafsir/translation sheet is actually met), so the feedback
  /// reads as an immediate response to touch rather than a delayed one.
  int? _pressedAyahNumber;

  /// The tafsir/translation hold is driven by a plain [Listener] + timer
  /// (below) rather than the gesture arena: a [LongPressGestureRecognizer]
  /// has a fixed ~18px pre-accept slop, so a long hold was silently cancelled
  /// by ordinary finger drift — which is why the sheet failed to open on so
  /// many ayahs. The per-ayah recognizers are kept only to identify which
  /// ayah is under the finger (their `onLongPressDown` fires the instant the
  /// finger lands and captures [_holdAction]); this timer, with a far more
  /// forgiving 60px tolerance, is what actually opens the sheet once the hold
  /// completes. ~0.6s is a responsive but deliberate hold — long enough not
  /// to fire on a tap (which toggles the chrome), short enough that it
  /// triggers before the user lifts.
  static const Duration _holdDuration = Duration(milliseconds: 500);
  static const double _holdMoveTolerance = 60;
  Timer? _holdTimer;
  Offset? _holdStart;
  VoidCallback? _holdAction;
  // Which ayah the finger is currently down on. Remembered on touch-down but
  // only turned into a visible highlight once the hold actually completes —
  // see the [_holdTimer] below — so a plain tap or a page-turn swipe never
  // tints an ayah; only a deliberate press-and-hold for the tafsir sheet does.
  int? _holdAyahNumber;
  bool _suppressNextTap = false;

  /// Ayah-picking mode for copying. Selection is deliberately whole-ayah
  /// only — you tap ayahs rather than dragging through glyphs — because a
  /// free text selection over a Mushaf page can land mid-word or mid-ayah
  /// and produce a quotation that isn't a complete verse. Holds the *global*
  /// ayah numbers so a selection can span surahs across a page boundary.
  bool _selectMode = false;
  final Set<int> _selectedAyahs = <int>{};
  // Kept alongside the selection so the copied text can be assembled in
  // recitation order with each ayah's surah name and number, without having
  // to look the ayahs up again.
  final Map<int, Ayah> _selectedAyahData = <int, Ayah>{};

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      if (_selectMode) {
        // Keep the chrome up on the way in: tapping an ayah now picks it
        // instead of toggling the chrome, so a user who entered this mode
        // could otherwise be left with no visible way back out.
        _chromeVisible = true;
      } else {
        _selectedAyahs.clear();
        _selectedAyahData.clear();
      }
    });
  }

  /// Selection can only ever be one unbroken run of ayahs, so a copied
  /// passage always reads continuously — you can't stitch together verses
  /// that aren't actually consecutive in the Mushaf. A tap therefore either
  /// extends the run by one at either end, trims it from either end, or —
  /// when it lands somewhere disconnected — starts a fresh run there rather
  /// than leaving a gap.
  void _toggleAyahSelection(Ayah ayah) {
    setState(() {
      if (_selectedAyahs.isEmpty) {
        _selectedAyahs.add(ayah.number);
        _selectedAyahData[ayah.number] = ayah;
        return;
      }
      final first = _selectedAyahs.reduce((a, b) => a < b ? a : b);
      final last = _selectedAyahs.reduce((a, b) => a > b ? a : b);

      // Trimming an end (tapping the run's own first/last ayah again).
      if (ayah.number == last || ayah.number == first) {
        _selectedAyahs.remove(ayah.number);
        _selectedAyahData.remove(ayah.number);
        return;
      }
      // Extending by one at either end keeps the run unbroken.
      if (ayah.number == last + 1 || ayah.number == first - 1) {
        _selectedAyahs.add(ayah.number);
        _selectedAyahData[ayah.number] = ayah;
        return;
      }
      // Anywhere else would leave a hole — begin again from here.
      _selectedAyahs
        ..clear()
        ..add(ayah.number);
      _selectedAyahData
        ..clear()
        ..[ayah.number] = ayah;
    });
  }

  /// The selected run exactly as the page reads: each ayah's text followed
  /// by its end-of-ayah marker, separated by a single space.
  String _selectionCopyText() {
    final ayahs = _selectedAyahData.values.toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    return ayahs.map((a) => ayahWithEndMarker(a.textAr, a.numberInSurah)).join(' ');
  }

  /// Paints the selected ayahs into a PNG that reproduces the page itself —
  /// same Mushaf font, same cream background, same green ayah numbers.
  ///
  /// Copying as an image rather than only as text is deliberate: on the page
  /// each ayah number sits inside the font's own rosette, but a clipboard
  /// carries characters, not the font, so the number's appearance is decided
  /// by whatever app it's pasted into — most system fonts leave it outside
  /// the rosette, or draw no rosette at all. A picture is the only form that
  /// looks the same everywhere it lands.
  Future<Uint8List?> _renderSelectionImage(BuildContext context) async {
    final ayahs = _selectedAyahData.values.toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    if (ayahs.isEmpty) return null;

    const scale = 3.0; // render at 3x so the paste stays sharp when zoomed
    const maxWidth = 720.0;
    const padding = 28.0;
    final baseStyle = AppTheme.quranTextStyle(
      context,
      fontSize: kQuranListViewFontSizes[quranFontSizeStepIndex(
        context.read<SettingsProvider>().quranFontSize,
      )],
    ).copyWith(color: _ink, height: kQuranFontSizeLineHeight.first);

    final spans = <TextSpan>[];
    for (var i = 0; i < ayahs.length; i++) {
      final a = ayahs[i];
      spans.add(TextSpan(text: a.textAr, style: baseStyle));
      spans.add(
        TextSpan(
          // Bare digits, exactly as the page does it: the Mushaf font draws
          // its own ornament around them, and adding U+06DD here would paint
          // a second, empty rosette beside it.
          text: arabicIndicNumber(a.numberInSurah),
          style: baseStyle.copyWith(color: _frameGreen),
        ),
      );
      if (i != ayahs.length - 1) spans.add(TextSpan(text: ' ', style: baseStyle));
    }

    final painter = TextPainter(
      text: TextSpan(children: spans),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    )..layout(maxWidth: maxWidth - padding * 2);

    final width = maxWidth;
    final height = painter.height + padding * 2;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = _pageBg,
    );
    painter.paint(canvas, const Offset(padding, padding));
    final image = await recorder.endRecording().toImage(
      (width * scale).round(),
      (height * scale).round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }

  /// Whether the in-progress gesture turned out to be a pinch (`true`), a
  /// page-turn drag (`false`), or hasn't received enough info yet to tell
  /// (`null` — only a single pointer has been seen so far). Decided once a
  /// 2nd pointer joins, or immediately if already zoomed in; see
  /// [_handleScaleUpdate].
  bool? _gestureIsZoom;
  double _gestureBaseScale = 1.0;
  Offset _gestureBaseOffset = Offset.zero;

  /// Horizontal distance the (single-finger, non-zoom) gesture has travelled
  /// so far, accumulated in [_handleScaleUpdate]. Used so a deliberate but
  /// *slow* swipe — one whose release velocity is under the flick threshold —
  /// still turns the page once it has dragged far enough, instead of being
  /// silently dropped (which felt like the swipe "didn't take", especially
  /// turning back a page).
  double _gesturePanDx = 0;

  /// Whether the tap-to-reveal back/reciter/view-toggle/search bar (top)
  /// and embedded app-tab bar (bottom) are showing. Off by default so the
  /// reading view stays fully immersive — see [_toggleChrome].
  bool _chromeVisible = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<SurahSummary> _allSurahs = [];

  void _disposeRecognizers() {
    for (final r in _selectRecognizersByAyah.values) {
      r.dispose();
    }
    _selectRecognizersByAyah.clear();
    for (final r in _recognizersByAyah.values) {
      r.dispose();
    }
    _recognizersByAyah.clear();
  }

  void _toggleChrome() => setState(() => _chromeVisible = !_chromeVisible);

  /// The page's tap handler. When a 2-second hold has just opened an ayah's
  /// sheet, the finger lift still arrives here as a tap — swallow that one so
  /// the chrome doesn't toggle underneath the sheet.
  void _handleTap() {
    if (_suppressNextTap) {
      _suppressNextTap = false;
      return;
    }
    // While picking ayahs, a tap that misses the text shouldn't hide the
    // chrome and strand the selection bar; taps that land on an ayah are
    // handled by that ayah's own recogniser.
    if (_selectMode) return;
    _toggleChrome();
  }

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
    // The Quran's very last page (604) is shared by An-Nas (114) *and*
    // Al-Falaq/Al-Ikhlas (112/113) — see [_SurahDetailScreenState._loadBundle],
    // which folds every surah sharing a page into that page's content. Paging
    // forward reaches this screen's last page long before `surahNumber`
    // itself ever reaches 114 (swiping past Al-Ikhlas opens *it* at page 604,
    // not An-Nas — see [_goToAdjacentSurah]'s "lowest surah number owns the
    // page" rule), so checking `surahNumber < 114` alone left the swipe
    // dead-ending on a next-surah sentinel that could never resolve (its
    // target page, 605, doesn't exist) instead of ever reaching the khatm
    // page below. Checking the actual last page on screen instead of the
    // surah number is what [_khatmIndex] needs to trigger correctly no
    // matter which of the three surahs this screen happens to be opened as.
    final reachesQuranEnd =
        _screenPages.isNotEmpty && _screenPages.last.first.page >= 604;
    final hasNextSurah = widget.surahNumber < 114 && !reachesQuranEnd;

    _realPagesStart = hasPrevSurah ? 1 : 0;
    _prevSentinelIndex = hasPrevSurah ? 0 : null;
    _nextSentinelIndex = hasNextSurah
        ? _realPagesStart + _screenPages.length
        : null;
    _khatmIndex = reachesQuranEnd
        ? _realPagesStart + _screenPages.length
        : null;
    _itemCount =
        _screenPages.length +
        (_prevSentinelIndex != null ? 1 : 0) +
        (_nextSentinelIndex != null ? 1 : 0) +
        (_khatmIndex != null ? 1 : 0);

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
        if (!mounted) return;
        final boundaryPage = widget.startAtLastPage
            ? _screenPages.first.first.page
            : _screenPages.last.first.page;
        widget.onAdjacentSurah(widget.startAtLastPage ? -1 : 1, boundaryPage);
      });
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _disposeRecognizers();
    _pageController.dispose();
    _searchController.dispose();
    _turnController?.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    // Wrapped in setState (even when zoom is already at rest) so the
    // bookmark icon in the top overlay — which reads [_currentMushafPage],
    // derived from [_currentIndex] — stays in sync with whichever page is
    // now on screen.
    setState(() {
      _currentIndex = index;
      if (_zoomScale != 1.0 || _zoomOffset != Offset.zero) {
        _zoomScale = 1.0;
        _zoomOffset = Offset.zero;
      }
    });
    if (_navigating) return;
    if (index == _prevSentinelIndex) {
      _navigating = true;
      // Boundary page = this surah's first real page; the handler pages back
      // to the one before it.
      widget.onAdjacentSurah(-1, _screenPages.first.first.page);
    } else if (index == _nextSentinelIndex) {
      _navigating = true;
      widget.onAdjacentSurah(1, _screenPages.last.first.page);
    } else if (index == _khatmIndex) {
      // Not a real Ayah page — nothing to persist as "last read" here.
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

  /// The real Mushaf page number currently on screen — used by the
  /// manual "stop sign" bookmark (see [_toggleBookmarkHere]), distinct
  /// from [_persistCurrentPage]'s automatic last-read tracking.
  int _currentMushafPage() {
    final index = (_currentIndex - _realPagesStart).clamp(
      0,
      _screenPages.length - 1,
    );
    return _screenPages[index].first.page;
  }

  void _toggleBookmarkHere() {
    final settings = context.read<SettingsProvider>();
    final page = _currentMushafPage();
    final isHere =
        settings.bookmarkSurah == widget.surahNumber &&
        settings.bookmarkPage == page;
    if (isHere) {
      settings.clearBookmark();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('quran.bookmark_removed'.tr())),
      );
    } else {
      settings.setBookmark(widget.surahNumber, page);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('quran.bookmark_added'.tr())),
      );
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
  ///
  /// Deliberately *not* driving [PageController.position] live as the
  /// finger moves, and *not* using [PageController.animateToPage] for the
  /// turn either: this view's ambient [Directionality] is RTL (the whole
  /// app's locale is Arabic) and [PageView.reverse] is `true`, and that
  /// specific combination makes [PageView]'s own scroll/animate direction
  /// resolve inconsistently with the swipe — the page landed on is correct
  /// either way, but the visual slide can end up going the opposite screen
  /// direction from the finger. Rather than fight `AxisDirection`
  /// resolution, [_startPageTurn] plays a slide we build and position
  /// ourselves (see [_buildTurnOverlay]), so its direction is set directly
  /// from the swipe's velocity sign and can never depend on `reverse`/
  /// `Directionality` semantics. The target index (which page it lands on)
  /// is still decided exactly as before; only how that change is animated
  /// is now ours to control.
  ///
  /// A single [GestureDetector.onScale*] trio (rather than separate drag and
  /// scale recognizers competing for the same pointer) handles both page
  /// turning AND pinch-zoom, deciding which one a gesture is as soon as it
  /// can tell: a 2nd pointer joining mid-gesture (or already being zoomed
  /// in) commits it to zoom. Routing both through one recognizer avoids the
  /// framework ever having to arbitrate between two competing ones for the
  /// same finger.
  void _handleScaleStart(ScaleStartDetails details) {
    _gestureIsZoom = null;
    _gestureBaseScale = _zoomScale;
    _gestureBaseOffset = _zoomOffset;
    _gesturePanDx = 0;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final stepIndex = quranFontSizeStepIndex(widget.fontSize);
    final zoomAllowed = kQuranFontSizeFitsPage[stepIndex];
    if (!zoomAllowed) return;

    if (_gestureIsZoom == null) {
      _gestureIsZoom = details.pointerCount >= 2 || _zoomScale > 1.01;
    } else if (_gestureIsZoom == false && details.pointerCount >= 2) {
      _gestureIsZoom = true;
      _gestureBaseScale = _zoomScale;
      _gestureBaseOffset = _zoomOffset;
    }

    if (_gestureIsZoom == true) {
      setState(() {
        _zoomScale = (_gestureBaseScale * details.scale).clamp(1.0, 2.5);
        _zoomOffset = _gestureBaseOffset + details.focalPointDelta / _zoomScale;
      });
    } else {
      _gesturePanDx += details.focalPointDelta.dx;
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    if (_gestureIsZoom != true && _turnController == null) {
      final velocity = details.velocity.pixelsPerSecond.dx;
      // A page turns either on a quick flick (velocity) OR on a slow but
      // deliberate drag past a fraction of the screen width (distance). The
      // distance fallback is what makes a calm, low-velocity swipe — common
      // when paging *back* — register instead of being dropped. When the flick
      // is too weak to read a direction from, fall back to the drag's own
      // sign so forward/back still resolve correctly.
      final width = MediaQuery.sizeOf(context).width;
      final flicked = velocity.abs() >= 150;
      final dragged = _gesturePanDx.abs() >= width * 0.22;
      if (flicked || dragged) {
        final goNext = flicked ? velocity > 0 : _gesturePanDx > 0;
        final target = (goNext ? _currentIndex + 1 : _currentIndex - 1)
            .clamp(0, _itemCount - 1);
        if (target != _currentIndex) {
          _startPageTurn(target, slideLeft: !goNext);
        }
      }
    }
    _gestureIsZoom = null;
    _gesturePanDx = 0;
  }

  /// Plays the page-turn slide and only swaps [_pageController] to [target]
  /// once it finishes — see the doc comment above [_handleScaleStart] for
  /// why this is driven manually instead of [PageController.animateToPage].
  /// [slideLeft] is taken directly from the swipe's velocity sign, so the
  /// whole transition (outgoing page leaving, incoming page entering) moves
  /// in that exact screen direction, matching the finger by construction.
  void _startPageTurn(int target, {required bool slideLeft}) {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    setState(() {
      _turnController = controller;
      _turnFromIndex = _currentIndex;
      _turnToIndex = target;
      _turnSlideLeft = slideLeft;
    });
    controller.forward(from: 0).whenComplete(() {
      controller.dispose();
      if (!mounted || !identical(_turnController, controller)) return;
      _pageController.jumpToPage(target);
      setState(() {
        _turnController = null;
        _turnFromIndex = null;
        _turnToIndex = null;
      });
    });
  }

  Widget _buildStaticPage(BuildContext context, int index) {
    return SafeArea(
      bottom: false,
      child: ResponsiveCenter(maxWidth: 900, child: _buildPageForIndex(context, index)),
    );
  }

  Widget _buildTurnOverlay(BuildContext context) {
    final controller = _turnController;
    final fromIndex = _turnFromIndex;
    final toIndex = _turnToIndex;
    // Positioned even when idle: a bare (non-Positioned) SizedBox.shrink()
    // here would become the outer Stack's only non-Positioned child (every
    // other child is Positioned), which makes the Stack size itself to that
    // 0x0 child instead of filling the screen — collapsing the whole page
    // to nothing.
    if (controller == null || fromIndex == null || toIndex == null) {
      return const Positioned.fill(child: SizedBox.shrink());
    }
    final width = MediaQuery.sizeOf(context).width;
    final sign = _turnSlideLeft ? -1.0 : 1.0;
    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: _pageBg,
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final dx = sign * width * controller.value;
              return Stack(
                children: [
                  Transform.translate(
                    offset: Offset(dx, 0),
                    child: _buildStaticPage(context, fromIndex),
                  ),
                  Transform.translate(
                    offset: Offset(dx - sign * width, 0),
                    child: _buildStaticPage(context, toIndex),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Shared by the real [PageView]'s `itemBuilder` and [_buildStaticPage]
  /// (the manual page-turn overlay), so both render identical content for
  /// a given page index.
  Widget _buildPageForIndex(BuildContext context, int index) {
    if (index == _prevSentinelIndex) {
      return const _AdjacentSurahTransitionPage(forward: false);
    }
    if (index == _nextSentinelIndex) {
      return const _AdjacentSurahTransitionPage(forward: true);
    }
    if (index == _khatmIndex) {
      return const _KhatmQuranPage();
    }
    final screenPageIndex = index - _realPagesStart;
    final pageAyahs = _screenPages[screenPageIndex];
    final page = _buildMushafPage(context, pageAyahs, screenPageIndex);
    final stepIndex = quranFontSizeStepIndex(widget.fontSize);
    return kQuranFontSizeFitsPage[stepIndex] ? _applyZoom(page) : page;
  }

  Widget _applyZoom(Widget child) {
    if (_zoomScale == 1.0 && _zoomOffset == Offset.zero) return child;
    return Transform.scale(
      scale: _zoomScale,
      child: Transform.translate(offset: _zoomOffset, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Recognizers are no longer cleared/recreated here on every build (see
    // [_recognizersByAyah]) — they're created lazily, once per ayah, the
    // first time each one is built, and only ever disposed in [dispose].

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
        // A passive [Listener] (it never claims the gesture, so scale/tap/
        // page-turn are untouched) drives the tafsir hold: start a 2-second
        // timer on touch-down, cancel it if the finger drifts past 60px or
        // lifts early, and open the held ayah's sheet when it completes.
        child: Listener(
          onPointerDown: (event) {
            _holdStart = event.position;
            _holdTimer?.cancel();
            _holdTimer = Timer(_holdDuration, () {
              final action = _holdAction;
              if (action == null || !mounted) return;
              _suppressNextTap = true;
              // The shadow appears now, at the moment the hold completes and
              // the tafsir/translation sheet opens — never on a bare touch.
              setState(() => _pressedAyahNumber = _holdAyahNumber);
              action();
            });
          },
          onPointerMove: (event) {
            if (_holdStart != null &&
                (event.position - _holdStart!).distance > _holdMoveTolerance) {
              _holdTimer?.cancel();
            }
          },
          onPointerUp: (_) {
            _holdTimer?.cancel();
            _holdAction = null;
            _holdStart = null;
            _holdAyahNumber = null;
          },
          onPointerCancel: (_) {
            _holdTimer?.cancel();
            _holdAction = null;
            _holdStart = null;
            _holdAyahNumber = null;
          },
          child: GestureDetector(
            // Without this, a drag/tap starting on empty space (e.g. the
            // letterboxed margins FittedBox leaves around a shrunk page)
            // wouldn't be hit-tested at all, since the default
            // `deferToChild` behavior only recognizes gestures where a
            // child actually paints.
            behavior: HitTestBehavior.opaque,
            onScaleStart: _handleScaleStart,
            onScaleUpdate: _handleScaleUpdate,
            onScaleEnd: _handleScaleEnd,
            // A quick tap anywhere on the page toggles the chrome overlay;
            // a held tap (see the page [Listener] above) opens the ayah's
            // sheet instead. [_handleTap] swallows the up-tap that would
            // otherwise follow a completed hold so the chrome doesn't toggle
            // underneath the sheet that just opened.
            onTap: _handleTap,
            child: PageView.builder(
              controller: _pageController,
              reverse: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _itemCount,
              onPageChanged: _onPageChanged,
              itemBuilder: _buildPageForIndex,
            ),
          ),
        ),
      ),
    );

    return Container(
      color: _pageBg,
      child: Stack(
        children: [
          Positioned.fill(child: pageContent),
          _buildTurnOverlay(context),
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
              // While picking ayahs the copy bar takes the bottom slot, so
              // the tab bar doesn't cover it or compete for the same taps.
              visible: _chromeVisible && !_selectMode,
              fromTop: false,
              child: _buildBottomNavOverlay(context),
            ),
          ),
          if (_selectMode)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildSelectionBar(context),
            ),
        ],
      ),
    );
  }

  /// Bottom bar shown while picking ayahs to copy: how many are selected,
  /// and the actions for the selection.
  Widget _buildSelectionBar(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    final count = _selectedAyahs.length;
    return Material(
      color: _frameGreen,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: _pageBg),
                tooltip: 'quran.cancel_selection'.tr(),
                onPressed: _toggleSelectMode,
              ),
              Expanded(
                child: Text(
                  count == 0
                      ? 'quran.select_ayahs_hint'.tr()
                      : 'quran.ayahs_selected'.tr(
                          args: [
                            isArabic
                                ? arabicIndicNumber(count)
                                : count.toString(),
                          ],
                        ),
                  style: const TextStyle(color: _pageBg),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.copy, color: _pageBg, size: 18),
                label: Text(
                  'quran.copy'.tr(),
                  style: const TextStyle(color: _pageBg),
                ),
                onPressed: count == 0
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        // Text goes on the clipboard first so plain-text
                        // targets (a search box, a message field that won't
                        // take images) still get something useful, then the
                        // picture — which is what reproduces the page's own
                        // look wherever images can be pasted.
                        final pngFuture = _renderSelectionImage(context);
                        await Clipboard.setData(
                          ClipboardData(text: _selectionCopyText()),
                        );
                        final png = await pngFuture;
                        if (png != null) {
                          await Pasteboard.writeImage(png);
                        }
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'quran.ayahs_copied'.tr(
                                args: [
                                  isArabic
                                      ? arabicIndicNumber(count)
                                      : count.toString(),
                                ],
                              ),
                            ),
                          ),
                        );
                        _toggleSelectMode();
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Back/view-toggle/reciter and a local surah/Juz' search, revealed by
  /// [_toggleChrome] — see [_chromeVisible].
  Widget _buildTopOverlay(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final matches = _searchMatches;
    final juzMatches = _searchJuzMatches;
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
                    icon: Icon(
                      _selectMode
                          ? Icons.select_all
                          : Icons.content_copy_outlined,
                      color: _pageBg,
                    ),
                    tooltip: 'quran.select_ayahs'.tr(),
                    onPressed: _toggleSelectMode,
                  ),
                  IconButton(
                    icon: Icon(
                      settings.bookmarkSurah == widget.surahNumber &&
                              settings.bookmarkPage == _currentMushafPage()
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      color: _pageBg,
                    ),
                    tooltip: 'quran.toggle_bookmark'.tr(),
                    onPressed: _toggleBookmarkHere,
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
                // This list always sits on the cream [_pageBg] background
                // regardless of light/dark theme, so every text/icon color
                // below is set explicitly rather than left to inherit from
                // the ambient (theme-dependent) defaults — in dark mode
                // those default to a near-white color that's nearly
                // invisible against this light background.
                child: (matches.isEmpty && juzMatches.isEmpty)
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'quran.no_results'.tr(),
                          style: const TextStyle(color: _ink),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final juzNumber in juzMatches)
                            ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.bookmark_outline,
                                color: _frameGreen,
                              ),
                              title: Text(
                                'quran.juz_label'.tr(
                                  args: [localizedNumber(context, juzNumber)],
                                ),
                                style: const TextStyle(
                                  color: _ink,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onTap: () => _jumpToJuz(juzNumber),
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
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _frameGreen,
                                  ),
                                ),
                              ),
                              title: Text(
                                s.nameAr,
                                style: AppTheme.quranNameStyle(
                                  context,
                                  fontSize: 16,
                                  color: _ink,
                                ),
                              ),
                              subtitle: Text(
                                s.englishName,
                                style: TextStyle(
                                  color: _ink.withValues(alpha: 0.65),
                                ),
                              ),
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
    // Mirrors HomeShell's own nav icons so switching tabs from inside the
    // reading screen looks identical to the main nav bar.
    final destinations = [
      (const Icon(Icons.menu_book), 'nav.quran'.tr()),
      (const Icon(Icons.explore_outlined), 'nav.prayer'.tr()),
      (const Icon(Icons.favorite_outline), 'nav.athkar'.tr()),
      (const Icon(Icons.format_quote), 'nav.hadith'.tr()),
      (const Icon(Icons.settings_outlined), 'nav.settings'.tr()),
    ];
    // [NavigationBar] wraps itself in a SafeArea for *every* edge (see its
    // build method). On the other tabs it is the Scaffold's
    // bottomNavigationBar, so the top inset is already spoken for by the
    // body and that SafeArea contributes nothing at the top. Here the bar
    // lives in a Stack over a full-screen page where the status-bar inset
    // is still unconsumed, so it was padding a status bar's worth of empty
    // surface *above* the icons — the tall white band over the Mushaf page.
    // Dropping just the top inset for this subtree leaves the bar identical
    // to the one on every other tab.
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: NavigationBar(
          selectedIndex: 0,
          onDestinationSelected: (i) {
            if (i == 0) return;
            context.read<HomeNavigationProvider>().setIndex(i);
            Navigator.of(context).popUntil((r) => r.isFirst);
          },
          destinations: [
            for (final (icon, label) in destinations)
              NavigationDestination(icon: icon, label: label),
          ],
        ),
      ),
    );
  }

  List<SurahSummary> get _searchMatches {
    final q = _searchQuery.trim();
    if (q.isEmpty) return const [];
    final qLower = q.toLowerCase();
    // The API's Arabic names come back fully diacritized (e.g. "Surat
    // Al-Baqarah" with full tashkeel) while real users type plain
    // undiacritized Arabic, so both sides go through
    // [normalizeArabicSearch] before comparing — a literal [String.contains]
    // against the raw diacritized name almost never matches otherwise.
    final qNormalized = normalizeArabicSearch(q);
    final qDigits = westernDigits(q);
    return _allSurahs
        .where(
          (s) =>
              normalizeArabicSearch(s.nameAr).contains(qNormalized) ||
              s.englishName.toLowerCase().contains(qLower) ||
              s.number.toString() == qDigits,
        )
        .take(6)
        .toList();
  }

  /// Every Juz' number (1-30) that matches the current search query.
  ///
  /// A query containing a number (Western or Arabic-Indic digits, with or
  /// without the word "Juz'"/"جزء" alongside it) matches that one specific
  /// Juz' exactly. A query that's just the word itself, with no number —
  /// since that's how someone browsing for "a Juz'" rather than a specific
  /// one would naturally type — matches every Juz', the same way typing
  /// part of a surah's name lists every surah containing it.
  List<int> get _searchJuzMatches {
    final raw = _searchQuery.trim();
    if (raw.isEmpty) return const [];
    final normalized = westernDigits(raw);
    final digits = RegExp(r'\d+').firstMatch(normalized)?.group(0);
    if (digits != null) {
      final n = int.tryParse(digits);
      return (n != null && n >= 1 && n <= 30) ? [n] : const [];
    }
    final isJuzWord =
        normalizeArabicSearch(raw).contains('جز') ||
        raw.toLowerCase().contains('juz');
    return isJuzWord ? List<int>.generate(30, (i) => i + 1) : const [];
  }

  void _jumpToSurah(SurahSummary target, {int? startPage}) {
    setState(() {
      _chromeVisible = false;
      _searchQuery = '';
    });
    _searchController.clear();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SurahDetailScreen(surah: target, startPage: startPage),
      ),
    );
  }

  void _jumpToJuz(int juzNumber) {
    final boundary = kJuzBoundaries[juzNumber - 1];
    // [widget.surahsByNumber] (built from the same full surah list as
    // [_allSurahs], but already available synchronously when this page
    // first renders) rather than [_allSurahs] — that field is only
    // populated once its own async fetch resolves, so a Juz' tapped before
    // it lands would silently fall through to an unrelated arbitrary surah.
    final target = widget.surahsByNumber[boundary.startSurah]!;
    // Jump straight to this Juz's own starting page — most Juz' boundaries
    // fall mid-surah, so opening [target]'s default first page would land
    // well before (or, for surahs split across Juz', well after) the
    // actual Juz' start.
    _jumpToSurah(target, startPage: boundary.startPage);
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
              style: baseStyle,
            ),
          );
        }
        addBlock(const SizedBox(height: 18));
      }

      final spans = <InlineSpan>[];
      for (var ayahIndex = 0; ayahIndex < run.length; ayahIndex++) {
        final ayah = run[ayahIndex];
        // Almost always the ayah carrying the sajda *sign* also carries the
        // trigger word itself, but 41:38 is the one exception in the whole
        // Quran: its sign sits at the end of ayah 38, while the actual
        // imperative ("وَٱسْجُدُوا۟") is back in ayah 37's own text — so
        // when an obligatory ayah's own text has no سجد-rooted word, the
        // overline belongs on the *previous* ayah instead (see
        // [ayahHasSajdaTriggerWord]).
        final nextAyah = ayahIndex + 1 < run.length
            ? run[ayahIndex + 1]
            : null;
        final overlineSajdaWord = ayah.sajdaObligatory
            ? ayahHasSajdaTriggerWord(ayah.textAr)
            : (nextAyah != null &&
                  nextAyah.sajdaObligatory &&
                  ayahHasSajdaTriggerWord(ayah.textAr) &&
                  !ayahHasSajdaTriggerWord(nextAyah.textAr));
        final surahInfo = widget.surahsByNumber[ayah.surahNumber];
        final selectRecognizer = _selectRecognizersByAyah.putIfAbsent(
          ayah.number,
          () => TapGestureRecognizer()
            ..onTap = () {
              if (_selectMode) _toggleAyahSelection(ayah);
            },
        );
        final recognizer = _recognizersByAyah.putIfAbsent(ayah.number, () {
          // Fires the instant the finger lands on this ayah, so it's a
          // reliable way to know which ayah is being held (the actual
          // 2-second timing + drift tolerance live in the page [Listener],
          // not here — see [_holdAction]). A long deadline keeps this
          // recognizer from ever claiming the gesture arena, so taps and
          // page-turn swipes keep working normally.
          final r = LongPressGestureRecognizer(
            duration: const Duration(seconds: 10),
          );
          r.onLongPressDown = (_) {
            // Just remember which ayah is under the finger and what to do if
            // the hold completes — no highlight yet (see [_holdTimer]).
            _holdAyahNumber = ayah.number;
            _holdAction = () => _showAyahSheet(
              this.context,
              ayah,
              surahInfo?.numberOfAyahs ?? ayah.numberInSurah,
              surahInfo?.nameAr ?? '',
            );
          };
          r.onLongPressCancel = () {
            if (_holdAyahNumber == ayah.number) _holdAyahNumber = null;
            if (_pressedAyahNumber == ayah.number) {
              setState(() => _pressedAyahNumber = null);
            }
          };
          r.onLongPressUp = () {
            if (_holdAyahNumber == ayah.number) _holdAyahNumber = null;
            if (_pressedAyahNumber == ayah.number) {
              setState(() => _pressedAyahNumber = null);
            }
          };
          return r;
        });
        final isActive =
            widget.activeSurahNumber == ayah.surahNumber &&
            widget.activeAyahNumber == ayah.numberInSurah;
        final isBookmarked =
            widget.bookmarkedSurahNumber == ayah.surahNumber &&
            widget.bookmarkedAyahNumber == ayah.numberInSurah;
        final isPressed = _pressedAyahNumber == ayah.number;

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
        // A held-down ayah shows a darker, neutral shadow rather than the
        // green "currently playing" tint below — that color already means
        // something else, so reusing it here would read as the recitation
        // having jumped to this ayah rather than as a simple press response.
        final isSelected = _selectedAyahs.contains(ayah.number);
        final highlight = isSelected
            ? (Paint()..color = _frameGreen.withValues(alpha: 0.30))
            : isPressed
            ? (Paint()..color = _ink.withValues(alpha: 0.12))
            : isActive
            ? (Paint()..color = _frameGreen.withValues(alpha: 0.18))
            : isBookmarked
            ? (Paint()..color = _bookmarkGold.withValues(alpha: 0.22))
            : null;
        // [prevAyah] is null not just for the Quran's very first ayah, but
        // for *any* surah's first ayah when that surah is opened directly
        // (rather than swiped into from the previous one) and its first
        // page has no carried-over ayahs from the previous surah to compare
        // against — 40 surahs' opening ayah is itself a genuine quarter
        // start, and without this fallback the ۞ mark silently went
        // missing on all of them (see [kSurahsStartingNewQuarterAtAyah1]).
        final startsQuarter = prevAyah != null
            ? prevAyah.hizbQuarter != ayah.hizbQuarter
            : (ayah.numberInSurah == 1 &&
                  (ayah.surahNumber == 1 ||
                      kSurahsStartingNewQuarterAtAyah1.contains(
                        ayah.surahNumber,
                      )));
        if (startsQuarter) {
          spans.add(
            TextSpan(
              text: '۞ ',
              style: baseStyle.copyWith(
                color: _frameGreen,
                fontWeight: FontWeight.bold,
              ),
              // Carry the same long-press recognizer as the rest of the ayah
              // so holding on the leading quarter mark opens the sheet too,
              // rather than being a dead spot.
              recognizer: _selectMode ? selectRecognizer : recognizer,
            ),
          );
        }
        spans.addAll(
          _ayahTextSpans(
            text: ayah.textAr,
            style: baseStyle.copyWith(background: highlight),
            recognizer: _selectMode ? selectRecognizer : recognizer,
            overlineSajdaWord: overlineSajdaWord,
          ),
        );
        if (ayah.sajda) {
          // ۩ marks the place of prostration, placed right after the ayah
          // text and before its own ۝ ayah-end number — i.e. to the *right*
          // of (read before) that number in the RTL line, matching a
          // printed Mushaf rather than trailing after it. The obligatory-
          // sajda overline belongs on the actual trigger word earlier in
          // the ayah (see [_ayahTextSpans]), not on this sign itself.
          //
          // Deliberately *not* [baseStyle] (Amiri Quran) here: that face
          // draws U+06E9 as an ornate rosette nearly indistinguishable from
          // the ۞ quarter-Hizb mark at this size, reading as a duplicate of
          // it rather than its own distinct sajda sign. The plain default
          // font's glyph is the simple, immediately-recognizable ۩ shape.
          spans.add(
            TextSpan(
              text: ' ۩',
              style: TextStyle(
                fontSize: baseStyle.fontSize,
                height: baseStyle.height,
                color: _frameGreen,
                fontWeight: FontWeight.bold,
                background: highlight,
              ),
              recognizer: _selectMode ? selectRecognizer : recognizer,
            ),
          );
        }
        spans.add(
          TextSpan(
            // The KFGQPC Mushaf font draws the Arabic-Indic ayah digits
            // *inside* its own end-of-ayah ornament, so just the number is
            // needed — prefixing the U+06DD (۝) sign would add a second,
            // empty rosette beside it. Regular weight (synthetic bold breaks
            // the ornament shaping).
            text: arabicIndicNumber(ayah.numberInSurah),
            style: baseStyle.copyWith(
              fontWeight: FontWeight.normal,
              color: _frameGreen,
              background: highlight,
            ),
            recognizer: _selectMode ? selectRecognizer : recognizer,
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
    // Always pinned to the physical left edge — [Alignment.centerLeft]
    // rather than a directional start/end alignment, since this should
    // stay put on one side regardless of Arabic/English locale, unlike
    // the rest of this screen's start/end-mirrored layout.
    final footer = Align(
      alignment: Alignment.centerLeft,
      child: _footerBadge(
        context,
        hizbWord: hizbWord,
        hizbNumber: hizbNumber,
        hizbFraction: hizbFraction,
        pageText: 'quran.page_label'.tr(
          args: [localizedNumber(context, lastAyah.page)],
        ),
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
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 3),
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
  /// compare against for that second check — when that page is also a
  /// fresh page opening directly on one of the 40 surahs in
  /// [kSurahsStartingNewQuarterAtAyah1], it falls back to that lookup
  /// instead of silently missing the badge.
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
    } else if (first.numberInSurah == 1 &&
        kSurahsStartingNewQuarterAtAyah1.contains(first.surahNumber)) {
      return true;
    }
    return pageAyahs.last.hizbQuarter != first.hizbQuarter;
  }

  /// [Ayah.quarterInHizb] 1 is the Hizb's own start (no fraction mark
  /// needed — the bare Hizb number already says that); 2/3/4 are a
  /// quarter, half and three-quarters of the way through it. In Arabic this
  /// is written as a word (ربع/نصف/ثلاثة أرباع), the way it's printed on a
  /// real Mushaf page, rather than as a "1/4"-style digit fraction.
  String? _hizbQuarterFraction(BuildContext context, int quarterInHizb) {
    final isArabic = context.locale.languageCode == 'ar';
    switch (quarterInHizb) {
      case 2:
        return isArabic
            ? 'quran.hizb_quarter'.tr()
            : '${localizedNumber(context, 1)}/${localizedNumber(context, 4)}';
      case 3:
        return isArabic
            ? 'quran.hizb_half'.tr()
            : '${localizedNumber(context, 1)}/${localizedNumber(context, 2)}';
      case 4:
        return isArabic
            ? 'quran.hizb_three_quarters'.tr()
            : '${localizedNumber(context, 3)}/${localizedNumber(context, 4)}';
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
    // Plain default font rather than [AppTheme.quranTextStyle]'s Amiri
    // Quran — that face reserves extra vertical space above the line for
    // Uthmani diacritics, which threw off vertical centering for this
    // badge's plain digits/short word and didn't add anything, since none
    // of that content needs Quranic glyph support.
    //
    // [TextLeadingDistribution.even] splits the line's leading equally above
    // and below the glyphs (rather than the default, which puts more above),
    // so the text sits exactly in the middle of the rectangle vertically;
    // [Alignment.center] + symmetric padding centers it horizontally.
    const style = TextStyle(
      fontSize: 9,
      color: _frameGreen,
      fontWeight: FontWeight.bold,
      height: 1.3,
      leadingDistribution: TextLeadingDistribution.even,
    );
    const gap = SizedBox(width: 2.5);
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _frameGreen, width: 1),
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

/// The Quran's genuine last page — reached by swiping forward past An-Nas's
/// final Mushaf page (see [_MushafPageViewState._khatmIndex]). A closing
/// "Khatm al-Quran" dua screen so finishing the whole Mushaf lands somewhere
/// deliberate rather than the swipe just silently stopping.
class _KhatmQuranPage extends StatefulWidget {
  const _KhatmQuranPage();

  @override
  State<_KhatmQuranPage> createState() => _KhatmQuranPageState();
}

class _KhatmQuranPageState extends State<_KhatmQuranPage> {
  late final Future<List<Thikr>> _future = AthkarRepository()
      .getKhatmQuranDuaa();

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    return Container(
      color: _MushafPageViewState._pageBg,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 48),
          child: Column(
            children: [
              Text(
                'quran.khatm_title'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _MushafPageViewState._frameGreen,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'quran.khatm_subtitle'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: _MushafPageViewState._ink),
              ),
              const SizedBox(height: 28),
              Container(
                height: 1,
                width: 80,
                color: _MushafPageViewState._frameGreen.withValues(
                  alpha: 0.4,
                ),
              ),
              const SizedBox(height: 28),
              FutureBuilder<List<Thikr>>(
                future: _future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  return Column(
                    children: [
                      for (final duaa in snapshot.data!)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Text(
                            isArabic ? duaa.ar : duaa.en,
                            textAlign: TextAlign.center,
                            textDirection: isArabic
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                            style: isArabic
                                ? AppTheme.athkarTextStyle(
                                    context,
                                    fontSize: 20,
                                    height: 2.0,
                                  ).copyWith(color: _MushafPageViewState._ink)
                                : TextStyle(
                                    color: _MushafPageViewState._ink,
                                    height: 1.6,
                                    fontSize: responsiveFontSize(
                                      context,
                                      16,
                                    ),
                                  ),
                          ),
                        ),
                    ],
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
      // Real layout, not getDryLayout: the dry estimate for these justified,
      // diacritic-heavy paragraphs can come out a hair shorter than the height
      // they actually render at, and that small mismatch is what left a strip
      // of blank page under the last ayah at the fit-to-page size. Measuring
      // the same way we finally lay them out makes the chosen scale fill the
      // page exactly, so the last ayah's marker sits flush at the bottom. The
      // children get laid out for real once more below at [chosenWidth]; an
      // extra measure pass here is cheap since it only runs when the page
      // (re)builds, never per frame.
      child.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);
      total += child.size.height;
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
      // Always take [hi], the bound the search keeps on the side where the
      // scaled content is *no taller* than the page. For a too-tall (dense)
      // page that was already the case; for a too-short (sparse) page like
      // Al-Fatiha or Al-Baqarah's first page, the old `lo` sat on the
      // *overflow* side, so scaling up to fill clipped the final line (e.g.
      // Fatiha's وَلَا ٱلضَّآلِّينَ vanished off the bottom). Choosing [hi]
      // instead leaves an imperceptible sub-line gap rather than cropping a
      // whole ayah.
      chosenWidth = hi;
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

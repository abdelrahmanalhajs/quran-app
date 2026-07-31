import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/reciters.dart';

/// `page` renders a continuous, justified Mushaf-style page (like a printed
/// Quran); `list` renders each ayah as its own separate card. `page` is the
/// default since it matches the look of a real Quran page.
enum QuranViewMode { page, list }

/// The 3 selectable Quran text sizes: Small, Medium and Large. Small and
/// Medium both always fill the full page without scrolling (scaled up or
/// down to match the screen exactly, like a printed Mushaf page). Large
/// renders at its natural size and scrolls to keep reading instead of
/// shrinking the text or changing which ayahs are on the page (see
/// [_MushafPageViewState] in surah_detail_screen.dart).
///
/// Since Small and Medium both scale to *exactly* fill the page regardless
/// of their starting size (there's only one final on-screen size that fits
/// a given page), the raw values here can't make Medium look bigger than
/// Small on their own — see [kQuranFontSizeLineHeight] for what actually
/// does.
/// Small / Medium / Large, in logical pixels. Only Small auto-fits each
/// Mushaf page to the screen (no scrolling — see [kQuranFontSizeFitsPage]);
/// Medium and Large render at their literal 30 / 36 px and the page scrolls.
const List<double> kQuranFontSizeSteps = [28, 30, 36];

/// Parallel to [kQuranFontSizeSteps]: only Small auto-fits the page without
/// scrolling; Medium and Large render at their literal size and scroll.
const List<bool> kQuranFontSizeFitsPage = [true, false, false];

/// Parallel to [kQuranFontSizeSteps]: the line-height multiplier for that
/// step. Deliberately generous — the KFGQPC face stacks tall marks (the
/// superscript alef, the small-high ligatures, shadda+vowel) well above the
/// letters, so the lines need enough gap that those marks never reach into
/// the descenders of the line above.
const List<double> kQuranFontSizeLineHeight = [2.6, 2.6, 2.6];

/// Parallel to [kQuranFontSizeSteps]: the body-text weight for that step.
/// All regular — the Mushaf face is never bold.
const List<FontWeight> kQuranFontSizeWeight = [
  FontWeight.normal,
  FontWeight.normal,
  FontWeight.normal,
];

/// Parallel to [kQuranFontSizeSteps]: the font size in the separate list
/// view. The same literal Small/Medium/Large pixel sizes as the page.
const List<double> kQuranListViewFontSizes = [28, 30, 36];

/// Index into [kQuranFontSizeSteps]/[kQuranFontSizeFitsPage] for the step
/// nearest to [fontSize].
int quranFontSizeStepIndex(double fontSize) {
  var nearest = 0;
  var nearestDiff = double.infinity;
  for (var i = 0; i < kQuranFontSizeSteps.length; i++) {
    final diff = (kQuranFontSizeSteps[i] - fontSize).abs();
    if (diff < nearestDiff) {
      nearestDiff = diff;
      nearest = i;
    }
  }
  return nearest;
}

class SettingsProvider extends ChangeNotifier {
  static const _kThemeMode = 'theme_mode';
  static const _kReciterId = 'reciter_id';
  static const _kQuranFontSize = 'quran_font_size';
  static const _kQuranViewMode = 'quran_view_mode';
  static const _kLastReadSurah = 'last_read_surah';
  static const _kLastReadPage = 'last_read_page';
  static const _kOnboardingDone = 'onboarding_done';
  static const _kQuranSignsColored = 'quran_signs_colored';
  static const _kBookmarkSurah = 'bookmark_surah';
  static const _kBookmarkPage = 'bookmark_page';
  static const _kBookmarkAyah = 'bookmark_ayah';

  ThemeMode _themeMode = ThemeMode.system;
  Reciter _reciter = kReciters.first;
  // Default to Medium (30).
  double _quranFontSize = 30;
  QuranViewMode _quranViewMode = QuranViewMode.page;
  int? _lastReadSurah;
  int? _lastReadPage;
  bool _onboardingDone = false;
  bool _quranSignsColored = false;
  int? _bookmarkSurah;
  int? _bookmarkPage;
  int? _bookmarkAyah;

  ThemeMode get themeMode => _themeMode;
  Reciter get reciter => _reciter;
  double get quranFontSize => _quranFontSize;
  QuranViewMode get quranViewMode => _quranViewMode;

  /// Whether waqf marks, the sajda sign, the ayah-end marker and the
  /// quarter-Hizb mark render in their own distinct colors (the default,
  /// matching a printed Mushaf) or in the same color as the body text —
  /// see [_MushafPageViewState]'s use of `ColorFiltered` in
  /// surah_detail_screen.dart, which is what actually enforces this for
  /// marks whose color comes from the font's own glyphs rather than a
  /// [TextStyle] this app sets.
  bool get quranSignsColored => _quranSignsColored;

  /// Whether the first-time language-choice + feature walkthrough (see
  /// `OnboardingScreen`) has already been shown, so it only ever appears
  /// once per install rather than on every cold start.
  bool get onboardingDone => _onboardingDone;

  /// The surah/Mushaf-page the user was last reading, persisted so the
  /// Quran tab can resume there instead of the surah list — both when
  /// switching back to the tab after visiting another one, and after
  /// fully closing and reopening the app. Null until the user has opened
  /// a surah at least once.
  int? get lastReadSurah => _lastReadSurah;
  int? get lastReadPage => _lastReadPage;

  /// A manually-placed "stop sign" the user drops on purpose to come back to
  /// later — distinct from [lastReadSurah]/[lastReadPage], which moves on
  /// every page turn and just resumes where reading was left off. Null until
  /// the user places one. [bookmarkAyah] (the ayah's number within
  /// [bookmarkSurah]) is optional — a plain page-level bookmark leaves it
  /// null; bookmarking a specific ayah from its detail sheet sets it too, so
  /// [_MushafPageViewState] can highlight that exact ayah once its page is
  /// reached, instead of leaving the reader to spot it on their own.
  int? get bookmarkSurah => _bookmarkSurah;
  int? get bookmarkPage => _bookmarkPage;
  int? get bookmarkAyah => _bookmarkAyah;
  bool get hasBookmark => _bookmarkSurah != null && _bookmarkPage != null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString(_kThemeMode);
    if (themeStr == 'light') _themeMode = ThemeMode.light;
    if (themeStr == 'dark') _themeMode = ThemeMode.dark;

    final reciterId = prefs.getString(_kReciterId);
    if (reciterId != null) {
      _reciter = kReciters.firstWhere(
        (r) => r.id == reciterId,
        orElse: () => kReciters.first,
      );
    }

    _quranFontSize = prefs.getDouble(_kQuranFontSize) ?? 30;
    // Migrate users whose saved value is from an older scale (incl. the old
    // 24px and 26px Small) onto the current Small/Medium/Large pixel sizes,
    // defaulting to Medium.
    if (!kQuranFontSizeSteps.contains(_quranFontSize)) {
      _quranFontSize = 30;
    }
    final viewModeStr = prefs.getString(_kQuranViewMode);
    _quranViewMode = viewModeStr == 'list'
        ? QuranViewMode.list
        : QuranViewMode.page;
    _lastReadSurah = prefs.getInt(_kLastReadSurah);
    _lastReadPage = prefs.getInt(_kLastReadPage);
    _onboardingDone = prefs.getBool(_kOnboardingDone) ?? false;
    _quranSignsColored = prefs.getBool(_kQuranSignsColored) ?? false;
    _bookmarkSurah = prefs.getInt(_kBookmarkSurah);
    _bookmarkPage = prefs.getInt(_kBookmarkPage);
    _bookmarkAyah = prefs.getInt(_kBookmarkAyah);
    notifyListeners();
  }

  Future<void> setBookmark(int surahNumber, int page, {int? ayah}) async {
    _bookmarkSurah = surahNumber;
    _bookmarkPage = page;
    _bookmarkAyah = ayah;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kBookmarkSurah, surahNumber);
    await prefs.setInt(_kBookmarkPage, page);
    if (ayah != null) {
      await prefs.setInt(_kBookmarkAyah, ayah);
    } else {
      await prefs.remove(_kBookmarkAyah);
    }
  }

  Future<void> clearBookmark() async {
    _bookmarkSurah = null;
    _bookmarkPage = null;
    _bookmarkAyah = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBookmarkSurah);
    await prefs.remove(_kBookmarkPage);
    await prefs.remove(_kBookmarkAyah);
  }

  Future<void> setQuranSignsColored(bool colored) async {
    _quranSignsColored = colored;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kQuranSignsColored, colored);
  }

  Future<void> setOnboardingDone() async {
    _onboardingDone = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingDone, true);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kThemeMode,
      mode == ThemeMode.light
          ? 'light'
          : mode == ThemeMode.dark
          ? 'dark'
          : 'system',
    );
  }

  Future<void> setReciter(Reciter reciter) async {
    _reciter = reciter;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kReciterId, reciter.id);
  }

  Future<void> setQuranFontSize(double size) async {
    _quranFontSize = size;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kQuranFontSize, size);
  }

  Future<void> setQuranViewMode(QuranViewMode mode) async {
    _quranViewMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kQuranViewMode,
      mode == QuranViewMode.list ? 'list' : 'page',
    );
  }

  /// Called on every Mushaf page change, so it's deliberately silent
  /// (no [notifyListeners]) — nothing in the widget tree watches these
  /// two fields, only [HomeShell] reads them imperatively when resuming,
  /// so notifying here would just be a wasted broadcast on every swipe.
  Future<void> setLastRead(int surahNumber, int page) async {
    if (_lastReadSurah == surahNumber && _lastReadPage == page) return;
    _lastReadSurah = surahNumber;
    _lastReadPage = page;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastReadSurah, surahNumber);
    await prefs.setInt(_kLastReadPage, page);
  }
}

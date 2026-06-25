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
const List<double> kQuranFontSizeSteps = [40, 68, 36];

/// Parallel to [kQuranFontSizeSteps]: whether that step auto-fits the page
/// without scrolling. Kept separate from the raw font-size values so
/// Small/Medium's values can be tuned independently without being mistaken
/// for Large (which would flip which ones scroll if inferred from a `>=`
/// comparison).
const List<bool> kQuranFontSizeFitsPage = [true, true, false];

/// Parallel to [kQuranFontSizeSteps]: the line-height multiplier for that
/// step. This — not the font-size value — is what makes Medium look bigger
/// than Small: a tighter line height means less of the page's fixed height
/// budget goes to the gap between lines once the page is scaled to fill the
/// frame exactly, leaving more of it for the letters themselves. Medium was
/// tightened further (1.7 -> 1.5) to read as noticeably bigger now that it's
/// regular weight rather than bold (see [kQuranFontSizeWeight]).
const List<double> kQuranFontSizeLineHeight = [2.1, 1.5, 1.9];

/// Parallel to [kQuranFontSizeSteps]: the body-text weight for that step.
/// All 3 steps render at regular weight — Medium previously used bold to
/// read as clearly bigger than Small, but its tighter [kQuranFontSizeLineHeight]
/// already does that on its own now, so bold was dropped in favor of a
/// plain, less heavy-looking step.
const List<FontWeight> kQuranFontSizeWeight = [
  FontWeight.normal,
  FontWeight.normal,
  FontWeight.normal,
];

/// Parallel to [kQuranFontSizeSteps]: the literal font size to render at in
/// the separate (non-Mushaf) list view, where each ayah is its own card and
/// there's no auto-fit scaler to normalize away the raw step values — using
/// [kQuranFontSizeSteps] directly there made Medium (68) render far bigger
/// than Large (36), and Large smaller than Small (40).
const List<double> kQuranListViewFontSizes = [25, 33, 35];

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

  ThemeMode _themeMode = ThemeMode.system;
  Reciter _reciter = kReciters.first;
  double _quranFontSize = 40;
  QuranViewMode _quranViewMode = QuranViewMode.page;
  int? _lastReadSurah;
  int? _lastReadPage;
  bool _onboardingDone = false;
  bool _quranSignsColored = true;

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

    _quranFontSize = prefs.getDouble(_kQuranFontSize) ?? 40;
    final viewModeStr = prefs.getString(_kQuranViewMode);
    _quranViewMode = viewModeStr == 'list'
        ? QuranViewMode.list
        : QuranViewMode.page;
    _lastReadSurah = prefs.getInt(_kLastReadSurah);
    _lastReadPage = prefs.getInt(_kLastReadPage);
    _onboardingDone = prefs.getBool(_kOnboardingDone) ?? false;
    _quranSignsColored = prefs.getBool(_kQuranSignsColored) ?? true;
    notifyListeners();
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

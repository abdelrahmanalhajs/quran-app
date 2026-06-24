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
const List<double> kQuranFontSizeSteps = [40, 65, 36];

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
/// frame exactly, leaving more of it for the letters themselves.
const List<double> kQuranFontSizeLineHeight = [1.9, 1.5, 1.9];

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

  ThemeMode _themeMode = ThemeMode.system;
  Reciter _reciter = kReciters.first;
  double _quranFontSize = 40;
  QuranViewMode _quranViewMode = QuranViewMode.page;

  ThemeMode get themeMode => _themeMode;
  Reciter get reciter => _reciter;
  double get quranFontSize => _quranFontSize;
  QuranViewMode get quranViewMode => _quranViewMode;

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
    notifyListeners();
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
}

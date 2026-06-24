import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/reciters.dart';

/// `page` renders a continuous, justified Mushaf-style page (like a printed
/// Quran); `list` renders each ayah as its own separate card. `page` is the
/// default since it matches the look of a real Quran page.
enum QuranViewMode { page, list }

/// The 3 selectable Quran text sizes: small, medium, large. Small and medium
/// always fill the full page without scrolling (scaled up or down to match
/// the screen exactly); large renders at its natural, bigger size and
/// scrolls to keep reading instead of shrinking the text or changing which
/// ayahs are on the page (see [_MushafPageViewState] in
/// surah_detail_screen.dart).
const List<double> kQuranFontSizeSteps = [25, 30, 35];

class SettingsProvider extends ChangeNotifier {
  static const _kThemeMode = 'theme_mode';
  static const _kReciterId = 'reciter_id';
  static const _kQuranFontSize = 'quran_font_size';
  static const _kQuranViewMode = 'quran_view_mode';

  ThemeMode _themeMode = ThemeMode.system;
  Reciter _reciter = kReciters.first;
  double _quranFontSize = 30;
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

    _quranFontSize = prefs.getDouble(_kQuranFontSize) ?? 30;
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

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/reciters.dart';

class SettingsProvider extends ChangeNotifier {
  static const _kThemeMode = 'theme_mode';
  static const _kReciterId = 'reciter_id';
  static const _kQuranFontSize = 'quran_font_size';

  ThemeMode _themeMode = ThemeMode.system;
  Reciter _reciter = kReciters.first;
  double _quranFontSize = 26;

  ThemeMode get themeMode => _themeMode;
  Reciter get reciter => _reciter;
  double get quranFontSize => _quranFontSize;

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

    _quranFontSize = prefs.getDouble(_kQuranFontSize) ?? 26;
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
}

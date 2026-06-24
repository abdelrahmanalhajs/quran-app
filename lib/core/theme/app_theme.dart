import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color _seed = Color(0xFF0E6E55);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    );
    return _build(scheme);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    );
    return _build(scheme);
  }

  static ThemeData _build(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textTheme: GoogleFonts.tajawalTextTheme(
        ThemeData(brightness: scheme.brightness).textTheme,
      ).apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
    );
  }

  static TextStyle quranTextStyle(BuildContext context, {double fontSize = 26}) {
    return GoogleFonts.amiri(
      fontSize: fontSize,
      height: 1.9,
      color: Theme.of(context).colorScheme.onSurface,
    );
  }

  /// Surah names from the Quran API include Quranic annotation marks (e.g.
  /// the small high sign U+06E1) that a regular UI font like Tajawal can't
  /// shape, rendering as visibly disconnected letters. Amiri — the same font
  /// used for ayah text — supports the full Uthmani range, so surah names
  /// must always use this style rather than the default text theme.
  static TextStyle quranNameStyle(
    BuildContext context, {
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
  }) {
    return GoogleFonts.amiri(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../responsive.dart';

class AppTheme {
  static const Color _seed = Color(0xFF0E6E55);

  // [MaterialApp] always evaluates both `theme` and `darkTheme` on every
  // single rebuild (regardless of which one is actually active), and
  // [QuranApp] rebuilds on *any* [SettingsProvider] change — not just a
  // theme switch. Recomputing [ColorScheme.fromSeed] (a full Material 3
  // tonal palette) plus a 15-entry Google Fonts [TextTheme] from scratch
  // every time was real, avoidable work sitting on the critical path of
  // every settings change, including the theme toggle itself — memoized
  // here so each is built once and reused.
  static ThemeData? _light;
  static ThemeData? _dark;

  static ThemeData light() {
    return _light ??= _build(
      ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.light),
    );
  }

  static ThemeData dark() {
    return _dark ??= _build(
      ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark),
    );
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
      ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
    );
  }

  /// Amiri Quran (rather than plain Amiri) is purpose-built for Uthmani
  /// Quran typesetting — its waqf marks, the sajda sign (۩) and other
  /// recitation annotations are drawn larger and more distinctly than in
  /// the general-purpose Amiri face, which renders them too small/thin to
  /// read clearly at normal Mushaf font sizes.
  static TextStyle quranTextStyle(
    BuildContext context, {
    double fontSize = 26,
  }) {
    return GoogleFonts.amiriQuran(
      fontSize: responsiveFontSize(context, fontSize),
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
      fontSize: responsiveFontSize(context, fontSize),
      fontWeight: fontWeight,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );
  }

  /// Athkar/duaa text frequently quotes full ayahs verbatim (Ayat al-Kursi,
  /// Al-Falaq, An-Nas, etc.), which carry the same Quranic-only marks that
  /// break under Tajawal — see [quranNameStyle]. Use Amiri here too instead
  /// of the default text theme.
  static TextStyle athkarTextStyle(
    BuildContext context, {
    double fontSize = 18,
    double height = 1.7,
  }) {
    return GoogleFonts.amiri(
      fontSize: responsiveFontSize(context, fontSize),
      height: height,
      color: Theme.of(context).colorScheme.onSurface,
    );
  }
}

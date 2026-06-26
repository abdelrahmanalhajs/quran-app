import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/ayah.dart';
import '../models/surah.dart';

/// Reads the entire Quran (Uthmani Arabic + English Sahih International
/// translation) from a single bundled asset, `assets/data/quran_full.json`,
/// rather than fetching it page-by-page/surah-by-surah over the network.
///
/// This makes every reading screen open instantly and work fully offline:
/// the ~2.8 MB asset is parsed once on first access into in-memory indexes
/// (by surah and by real Mushaf page), then reused for the rest of the app's
/// lifetime. The parse is intentionally cached on static fields so that the
/// several [QuranRepository] instances created across the app all share the
/// same one-time work.
class QuranRepository {
  static List<SurahSummary>? _summaries;
  static Map<int, List<Ayah>>? _ayahsBySurah;
  static Map<int, List<Ayah>>? _ayahsByPage;
  static Future<void>? _loading;

  /// Whether [surahNumber] should show a separate Bismillah line under the
  /// surah banner. False for Al-Fatiha (it's already ayah 1) and At-Tawbah
  /// (it has none).
  static bool hasSeparateBismillah(int surahNumber) =>
      surahNumber != 1 && surahNumber != 9;

  // The Uthmani-script edition prepends the 4-word Bismillah phrase to the
  // text of ayah 1 for every surah except Al-Fatiha and At-Tawbah (see
  // [hasSeparateBismillah]). Diacritic encoding of that prefix isn't always
  // byte-identical (e.g. shadda placement can vary), so rather than matching
  // an exact literal string, strip everything up to and including the 4th
  // space — robust to those encoding differences.
  static String _stripBismillahPrefix(String text) {
    var spaceCount = 0;
    for (var i = 0; i < text.length; i++) {
      if (text[i] == ' ') {
        spaceCount++;
        if (spaceCount == 4) {
          return text.substring(i + 1).trimLeft();
        }
      }
    }
    return text;
  }

  Future<void> _ensureLoaded() {
    if (_summaries != null) return Future.value();
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    final raw = await rootBundle.loadString('assets/data/quran_full.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final surahs = (data['surahs'] as List).cast<Map<String, dynamic>>();

    final summaries = <SurahSummary>[];
    final bySurah = <int, List<Ayah>>{};
    final byPage = <int, List<Ayah>>{};

    for (final surah in surahs) {
      final surahNumber = surah['number'] as int;
      final ayahsJson = (surah['ayahs'] as List).cast<Map<String, dynamic>>();

      summaries.add(
        SurahSummary.fromJson({
          'number': surahNumber,
          'name': surah['name'],
          'englishName': surah['englishName'],
          'englishNameTranslation': surah['englishNameTranslation'],
          'numberOfAyahs': ayahsJson.length,
          'revelationType': surah['revelationType'],
        }),
      );

      final list = <Ayah>[];
      for (final aj in ayahsJson) {
        var ayah = Ayah.fromArabicJson(
          aj,
          surahNumber,
        ).copyWithTranslation(aj['en'] as String?);
        if (ayah.numberInSurah == 1 && hasSeparateBismillah(surahNumber)) {
          ayah = ayah.copyWithArabicText(_stripBismillahPrefix(ayah.textAr));
        }
        list.add(ayah);
        (byPage[ayah.page] ??= <Ayah>[]).add(ayah);
      }
      bySurah[surahNumber] = list;
    }

    _summaries = summaries;
    _ayahsBySurah = bySurah;
    _ayahsByPage = byPage;
  }

  Future<List<SurahSummary>> getSurahList() async {
    await _ensureLoaded();
    return _summaries!;
  }

  Future<List<Ayah>> getSurahAyahs(
    int surahNumber, {
    bool withTranslation = true,
  }) async {
    await _ensureLoaded();
    return _ayahsBySurah![surahNumber] ?? const [];
  }

  /// Every ayah on a real, absolute Mushaf page (1-604), regardless of which
  /// surah(s) it belongs to — a page shared between the end of one surah and
  /// the start of the next comes back with both, each ayah carrying its own
  /// correct [Ayah.surahNumber], exactly like a printed Mushaf.
  Future<List<Ayah>> getPageAyahs(
    int pageNumber, {
    bool withTranslation = true,
  }) async {
    await _ensureLoaded();
    return _ayahsByPage![pageNumber] ?? const [];
  }
}

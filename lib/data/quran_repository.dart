import 'dart:convert';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import '../models/ayah.dart';
import '../models/surah.dart';

/// The fully-parsed Quran, returned from the background-isolate parse in
/// [QuranRepository._load] so the heavy [jsonDecode] + object construction
/// never runs on the UI thread.
class _ParsedQuran {
  final List<SurahSummary> summaries;
  final Map<int, List<Ayah>> bySurah;
  final Map<int, List<Ayah>> byPage;

  _ParsedQuran(this.summaries, this.bySurah, this.byPage);
}

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

  Future<void> _ensureLoaded() {
    if (_summaries != null) return Future.value();
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    final raw = await rootBundle.loadString('assets/data/quran_full.json');
    // Parse on a background isolate: decoding ~2.8 MB of JSON and building
    // 6236 Ayah objects is enough work to drop frames if done on the UI
    // thread the first time a reading screen opens.
    final parsed = await compute(_parse, raw);
    _summaries = parsed.summaries;
    _ayahsBySurah = parsed.bySurah;
    _ayahsByPage = parsed.byPage;
  }

  static _ParsedQuran _parse(String raw) {
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
        // The bundled text (quran.com Uthmani, matched to the KFGQPC font)
        // already excludes the Bismillah from ayah 1 — it's shown as its own
        // line via [hasSeparateBismillah] — so nothing needs stripping here.
        final ayah = Ayah.fromArabicJson(
          aj,
          surahNumber,
        ).copyWithTranslation(aj['en'] as String?);
        list.add(ayah);
        (byPage[ayah.page] ??= <Ayah>[]).add(ayah);
      }
      bySurah[surahNumber] = list;
    }

    return _ParsedQuran(summaries, bySurah, byPage);
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

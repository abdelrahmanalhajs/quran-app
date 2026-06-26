import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Serves tafsir from bundled assets so it works fully offline and opens
/// instantly: Al-Muyassar (Arabic) and Ibn Kathir (English), each a
/// `verse_key -> text` map covering all 6236 ayahs (ranges already expanded
/// to every ayah and HTML stripped at build time). Loaded lazily once and
/// cached on static fields shared across instances.
class TafsirRepository {
  static Map<String, String>? _ar;
  static Map<String, String>? _en;
  static Future<void>? _loadingAr;
  static Future<void>? _loadingEn;

  static Future<void> _ensure(bool arabic) {
    if (arabic) {
      if (_ar != null) return Future.value();
      return _loadingAr ??= rootBundle
          .loadString('assets/data/tafsir_ar.json')
          .then((s) => _ar = _decode(s));
    } else {
      if (_en != null) return Future.value();
      return _loadingEn ??= rootBundle
          .loadString('assets/data/tafsir_en.json')
          .then((s) => _en = _decode(s));
    }
  }

  static Map<String, String> _decode(String s) {
    return (jsonDecode(s) as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, v as String),
    );
  }

  Future<String> getTafsir({
    required int surahNumber,
    required int ayahNumberInSurah,
    required bool arabic,
  }) async {
    await _ensure(arabic);
    final verseKey = '$surahNumber:$ayahNumberInSurah';
    final map = arabic ? _ar! : _en!;
    return map[verseKey] ?? '';
  }
}

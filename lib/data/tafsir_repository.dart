import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// One tafsir edition loaded from a bundled asset. Many ayahs share a single
/// tafsir entry (the commentary is written per *range* of ayahs, not per
/// ayah), so to avoid duplicating long passages thousands of times the asset
/// stores each range's text once under its anchor ayah ([_anchors]) plus a
/// compact `verse_key -> anchor_key` map ([_refs]) for every ayah that falls
/// inside a range. Looking up any ayah resolves through [_refs] to its
/// anchor's text.
class _TafsirEdition {
  final Map<String, String> anchors;
  final Map<String, String> refs;

  _TafsirEdition(this.anchors, this.refs);

  factory _TafsirEdition.fromJson(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return _TafsirEdition(
      (json['a'] as Map<String, dynamic>).cast<String, String>(),
      (json['r'] as Map<String, dynamic>).cast<String, String>(),
    );
  }

  String textFor(String verseKey) {
    final anchorKey = refs[verseKey] ?? verseKey;
    return anchors[anchorKey] ?? '';
  }
}

/// Serves tafsir from bundled assets so it works fully offline and opens
/// instantly: Al-Muyassar (Arabic) and Ibn Kathir (English), each covering
/// all 6236 ayahs. Loaded lazily once and cached on static fields shared
/// across instances.
class TafsirRepository {
  static _TafsirEdition? _ar;
  static _TafsirEdition? _en;
  static Future<void>? _loadingAr;
  static Future<void>? _loadingEn;

  static Future<void> _ensure(bool arabic) {
    if (arabic) {
      if (_ar != null) return Future.value();
      return _loadingAr ??= rootBundle
          .loadString('assets/data/tafsir_ar.json')
          .then((s) => _ar = _TafsirEdition.fromJson(s));
    } else {
      if (_en != null) return Future.value();
      return _loadingEn ??= rootBundle
          .loadString('assets/data/tafsir_en.json')
          .then((s) => _en = _TafsirEdition.fromJson(s));
    }
  }

  Future<String> getTafsir({
    required int surahNumber,
    required int ayahNumberInSurah,
    required bool arabic,
  }) async {
    await _ensure(arabic);
    final verseKey = '$surahNumber:$ayahNumberInSurah';
    return (arabic ? _ar! : _en!).textFor(verseKey);
  }
}

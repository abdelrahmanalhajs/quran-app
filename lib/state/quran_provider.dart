import 'package:flutter/material.dart';
import '../data/quran_repository.dart';
import '../models/surah.dart';

enum LoadStatus { idle, loading, loaded, error }

class QuranProvider extends ChangeNotifier {
  final QuranRepository _repo = QuranRepository();

  List<SurahSummary> _surahs = [];
  LoadStatus _status = LoadStatus.idle;
  String _query = '';

  // Arabic diacritics: tanween/harakat/shadda/sukun (U+064B-U+0652),
  // superscript alef (U+0670), and tatweel (U+0640).
  static final RegExp _diacritics = RegExp('[ً-ْٰـ]');
  // Alef variants (madda U+0622, hamza-above U+0623, hamza-below U+0625,
  // wasla U+0671) that should collapse to a plain alef (U+0627).
  static final RegExp _alefVariants = RegExp('[آأإٱ]');

  List<SurahSummary> get surahs => _surahs;
  LoadStatus get status => _status;
  String get query => _query;

  List<SurahSummary> get filteredSurahs {
    if (_query.trim().isEmpty) return _surahs;
    final q = _query.trim().toLowerCase();
    final normalizedQuery = _normalizeArabic(_query);
    return _surahs.where((s) {
      return _normalizeArabic(s.nameAr).contains(normalizedQuery) ||
          s.englishName.toLowerCase().contains(q) ||
          s.englishNameTranslation.toLowerCase().contains(q) ||
          s.number.toString() == q;
    }).toList();
  }

  /// Strips Arabic diacritics, normalizes alef variants, drops the leading
  /// "surah" word (سورة), and collapses whitespace so a
  /// plain-typed query (no diacritics) can match the diacritic-laden names
  /// returned by the API.
  static String _normalizeArabic(String input) {
    return input
        .replaceAll(_diacritics, '')
        .replaceAll(_alefVariants, 'ا')
        .replaceAll('سورة', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  Future<void> loadSurahs() async {
    _status = LoadStatus.loading;
    notifyListeners();
    try {
      _surahs = await _repo.getSurahList();
      _status = LoadStatus.loaded;
    } catch (_) {
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  QuranRepository get repository => _repo;
}

import 'package:flutter/material.dart';
import '../data/quran_repository.dart';
import '../models/surah.dart';

enum LoadStatus { idle, loading, loaded, error }

class QuranProvider extends ChangeNotifier {
  final QuranRepository _repo = QuranRepository();

  List<SurahSummary> _surahs = [];
  LoadStatus _status = LoadStatus.idle;
  String _query = '';

  List<SurahSummary> get surahs => _surahs;
  LoadStatus get status => _status;
  String get query => _query;

  List<SurahSummary> get filteredSurahs {
    if (_query.trim().isEmpty) return _surahs;
    final q = _query.trim().toLowerCase();
    return _surahs.where((s) {
      return s.nameAr.contains(_query.trim()) ||
          s.englishName.toLowerCase().contains(q) ||
          s.englishNameTranslation.toLowerCase().contains(q) ||
          s.number.toString() == q;
    }).toList();
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

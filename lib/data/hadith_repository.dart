import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/hadith.dart';

class HadithRepository {
  List<Hadith>? _cache;

  Future<List<Hadith>> _all() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/data/hadith.json');
    final list = jsonDecode(raw) as List;
    _cache = list.map((e) => Hadith.fromJson(e as Map<String, dynamic>)).toList();
    return _cache!;
  }

  Future<Hadith> getHadithForDay(DateTime day) async {
    final all = await _all();
    final dayOfYear = int.parse(
      '${day.difference(DateTime(day.year, 1, 1)).inDays}',
    );
    return all[dayOfYear % all.length];
  }

  Future<Hadith> getTodayHadith() => getHadithForDay(DateTime.now());
}

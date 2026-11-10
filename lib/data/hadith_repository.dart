import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/hadith.dart';

class HadithRepository {
  List<Hadith>? _cache;

  Future<List<Hadith>> _all() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/data/hadith.json');
    final list = jsonDecode(raw) as List;
    _cache = list
        .map((e) => Hadith.fromJson(e as Map<String, dynamic>))
        .toList();
    return _cache!;
  }

  /// The hadith for [day]. Walks the collection in a shuffled order (a
  /// fixed stride through it rather than file order) so consecutive days
  /// don't land on neighbouring, often similar, entries — while still
  /// visiting every hadith once before any repeats, and giving the same
  /// hadith for the same day everywhere (Hadith tab and notification).
  Future<Hadith> getHadithForDay(DateTime day) async {
    final all = await _all();
    final n = all.length;
    final dayNumber =
        DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    var stride = 97 % n;
    while (stride == 0 || _gcd(stride, n) != 1) {
      stride++;
    }
    return all[(dayNumber * stride) % n];
  }

  static int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

  Future<Hadith> getTodayHadith() => getHadithForDay(DateTime.now());

  /// Today's hadith plus the previous [days] - 1 days', newest first, so the
  /// Hadith tab keeps showing older entries as new ones are added each day
  /// instead of replacing them.
  Future<List<({DateTime day, Hadith hadith})>> getRecentHadiths({
    int days = 14,
  }) async {
    final today = DateTime.now();
    final result = <({DateTime day, Hadith hadith})>[];
    for (var i = 0; i < days; i++) {
      final day = DateTime(today.year, today.month, today.day - i);
      result.add((day: day, hadith: await getHadithForDay(day)));
    }
    return result;
  }
}

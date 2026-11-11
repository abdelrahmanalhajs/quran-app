import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/models/hadith.dart';
import 'package:quran_app/models/thikr.dart';

dynamic _json(String path) => jsonDecode(File(path).readAsStringSync());

void main() {
  test('hadith.json parses, every entry opens with the Prophet\'s name', () {
    final list = (_json('assets/data/hadith.json') as List)
        .map((e) => Hadith.fromJson(e as Map<String, dynamic>))
        .toList();
    expect(list.length, greaterThan(300));
    for (final h in list) {
      expect(h.ar, startsWith('قَالَ رَسُولُ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ: '));
      expect(h.en, startsWith('The Prophet Muhammad (ﷺ) said: '));
      expect(h.source, isNotEmpty);
    }
  });

  test('athkar files parse', () {
    for (final f in [
      'athkar_morning',
      'athkar_evening',
      'athkar_after_prayer',
      'athkar_sleep',
      'athkar_jumaa',
    ]) {
      final list = (_json('assets/data/$f.json') as List)
          .map((e) => Thikr.fromJson(e as Map<String, dynamic>))
          .toList();
      expect(list, isNotEmpty, reason: f);
    }
  });

  test('zikr_pool.json entries have text in both languages', () {
    final pool = (_json('assets/data/zikr_pool.json') as List)
        .cast<Map<String, dynamic>>();
    expect(pool.length, greaterThan(100));
    for (final z in pool) {
      expect((z['ar'] as String).trim(), isNotEmpty);
      expect((z['en'] as String).trim(), isNotEmpty);
      expect(z.containsKey('src_ar') && z.containsKey('src_en'), isTrue);
    }
  });
}

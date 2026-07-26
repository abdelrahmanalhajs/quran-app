import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/thikr.dart';

class AthkarRepository {
  Future<List<Thikr>> getMorningAthkar() =>
      _load('assets/data/athkar_morning.json');

  Future<List<Thikr>> getEveningAthkar() =>
      _load('assets/data/athkar_evening.json');

  Future<List<Thikr>> getAfterPrayerAthkar() =>
      _load('assets/data/athkar_after_prayer.json');

  Future<List<Thikr>> getJumaaAthkar() =>
      _load('assets/data/athkar_jumaa.json');

  Future<List<Thikr>> getSleepAthkar() =>
      _load('assets/data/athkar_sleep.json');

  Future<List<Thikr>> getGeneralDuaa() =>
      _load('assets/data/duaa_general.json');

  Future<List<Thikr>> getKhatmQuranDuaa() =>
      _load('assets/data/duaa_khatm_quran.json');

  Future<List<Thikr>> _load(String path) async {
    final raw = await rootBundle.loadString(path);
    final list = jsonDecode(raw) as List;
    return list.map((e) => Thikr.fromJson(e as Map<String, dynamic>)).toList();
  }
}

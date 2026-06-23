import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/thikr.dart';

class AthkarRepository {
  Future<List<Thikr>> getMorningAthkar() => _load('assets/data/athkar_morning.json');

  Future<List<Thikr>> getEveningAthkar() => _load('assets/data/athkar_evening.json');

  Future<List<Thikr>> _load(String path) async {
    final raw = await rootBundle.loadString(path);
    final list = jsonDecode(raw) as List;
    return list.map((e) => Thikr.fromJson(e as Map<String, dynamic>)).toList();
  }
}

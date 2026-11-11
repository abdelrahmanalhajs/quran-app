import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum HifzStatus { none, learning, memorized }

class HifzEntry {
  final int surah;
  final HifzStatus status;

  /// Index into [HifzProvider.reviewIntervals] (memorized surahs only).
  final int stage;

  /// Next review date (memorized surahs only).
  final DateTime? nextReview;

  const HifzEntry(this.surah, this.status, {this.stage = 0, this.nextReview});

  Map<String, dynamic> toJson() => {
    'st': status.index,
    'sg': stage,
    if (nextReview != null) 'nx': nextReview!.toIso8601String(),
  };

  static HifzEntry fromJson(int surah, Map<String, dynamic> j) => HifzEntry(
    surah,
    HifzStatus.values[(j['st'] as int).clamp(0, 2)],
    stage: j['sg'] as int? ?? 0,
    nextReview: j['nx'] == null ? null : DateTime.tryParse(j['nx'] as String),
  );
}

/// Memorization progress per surah plus a spaced-repetition review
/// schedule: each on-time review pushes the next one further out
/// ([reviewIntervals]); stored on the device only. Also keeps the user's
/// last-used session settings (repeats, pause, hide-text).
class HifzProvider extends ChangeNotifier {
  static const reviewIntervals = [1, 3, 7, 14, 30, 60, 120];

  static const _kState = 'hifz_state';
  static const _kRepeatEach = 'hifz_repeat_each';
  static const _kRepeatRange = 'hifz_repeat_range';
  static const _kPause = 'hifz_pause_sec';
  static const _kHide = 'hifz_hide_text';

  SharedPreferences? _prefs;
  final Map<int, HifzEntry> _entries = {};
  int repeatEach = 3;
  int repeatRange = 1;
  int pauseSeconds = 2;
  bool hideText = false;

  HifzProvider() {
    _load();
  }

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _prefs = p;
    try {
      final m = jsonDecode(p.getString(_kState) ?? '{}') as Map;
      m.forEach((k, v) {
        final s = int.parse(k as String);
        _entries[s] = HifzEntry.fromJson(s, (v as Map).cast<String, dynamic>());
      });
    } catch (_) {}
    repeatEach = p.getInt(_kRepeatEach) ?? 3;
    repeatRange = p.getInt(_kRepeatRange) ?? 1;
    pauseSeconds = p.getInt(_kPause) ?? 2;
    hideText = p.getBool(_kHide) ?? false;
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    await p.setString(
      _kState,
      jsonEncode({for (final e in _entries.values) '${e.surah}': e.toJson()}),
    );
  }

  HifzEntry entryFor(int surah) =>
      _entries[surah] ?? HifzEntry(surah, HifzStatus.none);

  List<HifzEntry> get learning =>
      _entries.values.where((e) => e.status == HifzStatus.learning).toList()
        ..sort((a, b) => a.surah.compareTo(b.surah));

  List<HifzEntry> get memorized =>
      _entries.values.where((e) => e.status == HifzStatus.memorized).toList()
        ..sort((a, b) => a.surah.compareTo(b.surah));

  /// Memorized surahs whose review date is today or overdue.
  List<HifzEntry> get dueForReview {
    final t = _today();
    return memorized
        .where((e) => e.nextReview == null || !e.nextReview!.isAfter(t))
        .toList()
      ..sort((a, b) => (a.nextReview ?? t).compareTo(b.nextReview ?? t));
  }

  Future<void> setLearning(int surah) async {
    _entries[surah] = HifzEntry(surah, HifzStatus.learning);
    notifyListeners();
    await _save();
  }

  Future<void> markMemorized(int surah) async {
    _entries[surah] = HifzEntry(
      surah,
      HifzStatus.memorized,
      stage: 0,
      nextReview: _today().add(Duration(days: reviewIntervals.first)),
    );
    notifyListeners();
    await _save();
  }

  /// Records a completed review: the next one moves a step further out.
  Future<void> markReviewed(int surah) async {
    final e = entryFor(surah);
    final stage = (e.status == HifzStatus.memorized ? e.stage + 1 : 0).clamp(
      0,
      reviewIntervals.length - 1,
    );
    _entries[surah] = HifzEntry(
      surah,
      HifzStatus.memorized,
      stage: stage,
      nextReview: _today().add(Duration(days: reviewIntervals[stage])),
    );
    notifyListeners();
    await _save();
  }

  Future<void> remove(int surah) async {
    _entries.remove(surah);
    notifyListeners();
    await _save();
  }

  Future<void> updateSessionSettings({
    int? repeatEach,
    int? repeatRange,
    int? pauseSeconds,
    bool? hideText,
  }) async {
    if (repeatEach != null) this.repeatEach = repeatEach;
    if (repeatRange != null) this.repeatRange = repeatRange;
    if (pauseSeconds != null) this.pauseSeconds = pauseSeconds;
    if (hideText != null) this.hideText = hideText;
    notifyListeners();
    final p = _prefs ?? await SharedPreferences.getInstance();
    await p.setInt(_kRepeatEach, this.repeatEach);
    await p.setInt(_kRepeatRange, this.repeatRange);
    await p.setInt(_kPause, this.pauseSeconds);
    await p.setBool(_kHide, this.hideText);
  }
}

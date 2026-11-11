import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Daily reading goal, reading streak and khatma (full-Quran completion)
/// planner. Pages count once per day each: swiping back and forth over the
/// same page doesn't inflate the total. Fed by the Mushaf reader through
/// [recordPage]; stored on the device only.
class ReadingPlanProvider extends ChangeNotifier {
  static const totalPages = 604;

  static const _kGoal = 'rp_daily_goal';
  static const _kDays = 'rp_days'; // {"2026-11-12": 4, ...}
  static const _kTodayDate = 'rp_today_date';
  static const _kTodayPages = 'rp_today_pages';
  static const _kKhatmaStart = 'rp_khatma_start';
  static const _kKhatmaEnd = 'rp_khatma_end';
  static const _kKhatmaRead = 'rp_khatma_read'; // 604-char 0/1 string
  static const _kKhatmasDone = 'rp_khatmas_done';

  SharedPreferences? _prefs;
  int _goal = 0;
  Map<String, int> _days = {};
  String _todayKey = '';
  Set<int> _todayPages = {};
  DateTime? _khatmaStart;
  DateTime? _khatmaEnd;
  List<bool> _khatmaRead = List.filled(totalPages, false);
  int _khatmasDone = 0;

  ReadingPlanProvider() {
    _load();
  }

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _prefs = p;
    _goal = p.getInt(_kGoal) ?? 0;
    try {
      _days = (jsonDecode(p.getString(_kDays) ?? '{}') as Map).map(
        (k, v) => MapEntry(k as String, v as int),
      );
    } catch (_) {
      _days = {};
    }
    _todayKey = _key(_today());
    if (p.getString(_kTodayDate) == _todayKey) {
      _todayPages = (p.getString(_kTodayPages) ?? '')
          .split(',')
          .where((e) => e.isNotEmpty)
          .map(int.parse)
          .toSet();
    }
    final s = p.getString(_kKhatmaStart);
    final e = p.getString(_kKhatmaEnd);
    _khatmaStart = s == null ? null : DateTime.tryParse(s);
    _khatmaEnd = e == null ? null : DateTime.tryParse(e);
    final bits = p.getString(_kKhatmaRead);
    if (bits != null && bits.length == totalPages) {
      _khatmaRead = [for (final c in bits.split('')) c == '1'];
    }
    _khatmasDone = p.getInt(_kKhatmasDone) ?? 0;
    notifyListeners();
  }

  // ---- Daily goal & streak ----

  /// Pages per day; 0 = no goal.
  int get dailyGoal => _goal;

  Future<void> setDailyGoal(int pages) async {
    _goal = pages;
    await _prefs?.setInt(_kGoal, pages);
    notifyListeners();
  }

  int get pagesToday {
    _rollDayIfNeeded();
    return _todayPages.length;
  }

  bool get goalMetToday => _goal > 0 && pagesToday >= _goal;

  /// Consecutive days, ending today (or yesterday, if nothing read yet
  /// today), on which the goal was met — or, with no goal, on which at
  /// least one page was read.
  int get streak {
    _rollDayIfNeeded();
    final need = math.max(1, _goal);
    var d = _today();
    if ((_days[_key(d)] ?? 0) < need) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while ((_days[_key(d)] ?? 0) >= need) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  /// Pages read on each of the last [days] days, oldest first.
  List<int> recentDays(int days) {
    final t = _today();
    return [
      for (var i = days - 1; i >= 0; i--)
        _days[_key(t.subtract(Duration(days: i)))] ?? 0,
    ];
  }

  void _rollDayIfNeeded() {
    final k = _key(_today());
    if (k != _todayKey) {
      _todayKey = k;
      _todayPages = {};
    }
  }

  /// Called by the Mushaf reader whenever a real page (1–604) is shown.
  Future<void> recordPage(int page) async {
    if (page < 1 || page > totalPages) return;
    _rollDayIfNeeded();
    var changed = false;
    if (_todayPages.add(page)) {
      _days[_todayKey] = _todayPages.length;
      // Keep ~4 months of history.
      if (_days.length > 130) {
        final keys = _days.keys.toList()..sort();
        for (final k in keys.take(_days.length - 130)) {
          _days.remove(k);
        }
      }
      changed = true;
    }
    if (hasKhatma && !_khatmaRead[page - 1]) {
      _khatmaRead[page - 1] = true;
      changed = true;
    }
    if (!changed) return;
    notifyListeners();
    final p = _prefs ?? await SharedPreferences.getInstance();
    await p.setString(_kDays, jsonEncode(_days));
    await p.setString(_kTodayDate, _todayKey);
    await p.setString(_kTodayPages, _todayPages.join(','));
    if (hasKhatma) {
      await p.setString(
        _kKhatmaRead,
        _khatmaRead.map((b) => b ? '1' : '0').join(),
      );
    }
  }

  // ---- Khatma ----

  bool get hasKhatma => _khatmaStart != null && _khatmaEnd != null;
  DateTime? get khatmaStart => _khatmaStart;
  DateTime? get khatmaEnd => _khatmaEnd;
  int get khatmasCompleted => _khatmasDone;
  int get khatmaPagesRead => _khatmaRead.where((b) => b).length;
  double get khatmaProgress => khatmaPagesRead / totalPages;
  bool get khatmaComplete => hasKhatma && khatmaPagesRead == totalPages;

  /// Days left including today (at least 1).
  int get khatmaDaysLeft {
    if (!hasKhatma) return 0;
    return math.max(1, _khatmaEnd!.difference(_today()).inDays + 1);
  }

  /// Pages to read per day from now on to finish on time.
  int get khatmaDailyPortion {
    if (!hasKhatma) return 0;
    final left = totalPages - khatmaPagesRead;
    return (left / khatmaDaysLeft).ceil();
  }

  /// First page not yet read in this khatma (where to continue).
  int? get khatmaNextPage {
    final i = _khatmaRead.indexOf(false);
    return i < 0 ? null : i + 1;
  }

  Future<void> startKhatma(DateTime end) async {
    _khatmaStart = _today();
    _khatmaEnd = DateTime(end.year, end.month, end.day);
    _khatmaRead = List.filled(totalPages, false);
    final p = _prefs ?? await SharedPreferences.getInstance();
    await p.setString(_kKhatmaStart, _khatmaStart!.toIso8601String());
    await p.setString(_kKhatmaEnd, _khatmaEnd!.toIso8601String());
    await p.setString(_kKhatmaRead, '0' * totalPages);
    notifyListeners();
  }

  /// Ends the current khatma; [completed] counts it towards the total.
  Future<void> endKhatma({bool completed = false}) async {
    if (completed) _khatmasDone++;
    _khatmaStart = null;
    _khatmaEnd = null;
    _khatmaRead = List.filled(totalPages, false);
    final p = _prefs ?? await SharedPreferences.getInstance();
    await p.remove(_kKhatmaStart);
    await p.remove(_kKhatmaEnd);
    await p.remove(_kKhatmaRead);
    await p.setInt(_kKhatmasDone, _khatmasDone);
    notifyListeners();
  }
}

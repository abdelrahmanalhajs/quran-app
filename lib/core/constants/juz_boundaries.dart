/// One of the 30 standard Juz' (equal reading portions) of the Quran,
/// identified by the surah:ayah it starts and ends at. These boundaries are
/// fixed across every printed and digital Quran edition, so they're
/// hardcoded here rather than fetched — there's no per-Juz' endpoint in the
/// underlying Quran API this app otherwise relies on.
class JuzBoundary {
  final int number;
  final int startSurah;
  final int endSurah;

  const JuzBoundary({
    required this.number,
    required this.startSurah,
    required this.endSurah,
  });

  /// Every surah number this Juz' touches, including ones it only partially
  /// covers at its start or end — Juz' boundaries fall mid-surah far more
  /// often than not.
  List<int> get surahNumbers => [
    for (var s = startSurah; s <= endSurah; s++) s,
  ];
}

const List<JuzBoundary> kJuzBoundaries = [
  JuzBoundary(number: 1, startSurah: 1, endSurah: 2),
  JuzBoundary(number: 2, startSurah: 2, endSurah: 2),
  JuzBoundary(number: 3, startSurah: 2, endSurah: 3),
  JuzBoundary(number: 4, startSurah: 3, endSurah: 4),
  JuzBoundary(number: 5, startSurah: 4, endSurah: 4),
  JuzBoundary(number: 6, startSurah: 4, endSurah: 5),
  JuzBoundary(number: 7, startSurah: 5, endSurah: 6),
  JuzBoundary(number: 8, startSurah: 6, endSurah: 7),
  JuzBoundary(number: 9, startSurah: 7, endSurah: 8),
  JuzBoundary(number: 10, startSurah: 8, endSurah: 9),
  JuzBoundary(number: 11, startSurah: 9, endSurah: 11),
  JuzBoundary(number: 12, startSurah: 11, endSurah: 12),
  JuzBoundary(number: 13, startSurah: 12, endSurah: 14),
  JuzBoundary(number: 14, startSurah: 15, endSurah: 16),
  JuzBoundary(number: 15, startSurah: 17, endSurah: 18),
  JuzBoundary(number: 16, startSurah: 18, endSurah: 20),
  JuzBoundary(number: 17, startSurah: 21, endSurah: 22),
  JuzBoundary(number: 18, startSurah: 23, endSurah: 25),
  JuzBoundary(number: 19, startSurah: 25, endSurah: 27),
  JuzBoundary(number: 20, startSurah: 27, endSurah: 29),
  JuzBoundary(number: 21, startSurah: 29, endSurah: 33),
  JuzBoundary(number: 22, startSurah: 33, endSurah: 36),
  JuzBoundary(number: 23, startSurah: 36, endSurah: 39),
  JuzBoundary(number: 24, startSurah: 39, endSurah: 41),
  JuzBoundary(number: 25, startSurah: 41, endSurah: 45),
  JuzBoundary(number: 26, startSurah: 46, endSurah: 51),
  JuzBoundary(number: 27, startSurah: 51, endSurah: 57),
  JuzBoundary(number: 28, startSurah: 58, endSurah: 66),
  JuzBoundary(number: 29, startSurah: 67, endSurah: 77),
  JuzBoundary(number: 30, startSurah: 78, endSurah: 114),
];

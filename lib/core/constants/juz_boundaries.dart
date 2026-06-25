/// One of the 30 standard Juz' (equal reading portions) of the Quran,
/// identified by the surah:ayah it starts and ends at. These boundaries are
/// fixed across every printed and digital Quran edition, so they're
/// hardcoded here rather than fetched — there's no per-Juz' endpoint in the
/// underlying Quran API this app otherwise relies on.
class JuzBoundary {
  final int number;
  final int startSurah;
  final int endSurah;

  /// The real, absolute Mushaf page (1-604) this Juz' starts on — not
  /// necessarily [startSurah]'s own first page, since a Juz' boundary falls
  /// mid-surah far more often than not. Jumping a search result straight to
  /// [startSurah]'s first page (rather than this page) is what made the
  /// in-app Juz' search land on the wrong spot.
  final int startPage;

  const JuzBoundary({
    required this.number,
    required this.startSurah,
    required this.endSurah,
    required this.startPage,
  });

  /// Every surah number this Juz' touches, including ones it only partially
  /// covers at its start or end — Juz' boundaries fall mid-surah far more
  /// often than not.
  List<int> get surahNumbers => [
    for (var s = startSurah; s <= endSurah; s++) s,
  ];
}

/// Every surah (other than Al-Fatiha) whose very first ayah is itself the
/// start of a new quarter-Hizb (۞) — i.e. the previous ayah, wherever it
/// falls, belongs to a different quarter. Detecting a quarter-Hizb start
/// normally just compares an ayah's [Ayah.hizbQuarter] to the one before
/// it, but the ayah *before* a surah's first one isn't loaded when the
/// surah is opened directly (rather than swiped into from the previous
/// one) — without this lookup, the ۞ mark silently went missing on these
/// 40 surahs' opening ayah specifically because there was nothing loaded
/// to compare against.
const Set<int> kSurahsStartingNewQuarterAtAyah1 = {
  4, 5, 7, 8, 9, 15, 16, 17, 20, 21, 22, 23, 24, 25, 26, 27, 29, 30, 33, 40,
  46, 49, 55, 56, 58, 62, 65, 66, 67, 68, 69, 72, 75, 78, 80, 82, 84, 87, 90,
  94,
};

const List<JuzBoundary> kJuzBoundaries = [
  JuzBoundary(number: 1, startSurah: 1, endSurah: 2, startPage: 1),
  JuzBoundary(number: 2, startSurah: 2, endSurah: 2, startPage: 22),
  JuzBoundary(number: 3, startSurah: 2, endSurah: 3, startPage: 42),
  JuzBoundary(number: 4, startSurah: 3, endSurah: 4, startPage: 62),
  JuzBoundary(number: 5, startSurah: 4, endSurah: 4, startPage: 82),
  JuzBoundary(number: 6, startSurah: 4, endSurah: 5, startPage: 102),
  JuzBoundary(number: 7, startSurah: 5, endSurah: 6, startPage: 121),
  JuzBoundary(number: 8, startSurah: 6, endSurah: 7, startPage: 142),
  JuzBoundary(number: 9, startSurah: 7, endSurah: 8, startPage: 162),
  JuzBoundary(number: 10, startSurah: 8, endSurah: 9, startPage: 182),
  JuzBoundary(number: 11, startSurah: 9, endSurah: 11, startPage: 201),
  JuzBoundary(number: 12, startSurah: 11, endSurah: 12, startPage: 222),
  JuzBoundary(number: 13, startSurah: 12, endSurah: 14, startPage: 242),
  JuzBoundary(number: 14, startSurah: 15, endSurah: 16, startPage: 262),
  JuzBoundary(number: 15, startSurah: 17, endSurah: 18, startPage: 282),
  JuzBoundary(number: 16, startSurah: 18, endSurah: 20, startPage: 302),
  JuzBoundary(number: 17, startSurah: 21, endSurah: 22, startPage: 322),
  JuzBoundary(number: 18, startSurah: 23, endSurah: 25, startPage: 342),
  JuzBoundary(number: 19, startSurah: 25, endSurah: 27, startPage: 362),
  JuzBoundary(number: 20, startSurah: 27, endSurah: 29, startPage: 382),
  JuzBoundary(number: 21, startSurah: 29, endSurah: 33, startPage: 402),
  JuzBoundary(number: 22, startSurah: 33, endSurah: 36, startPage: 422),
  JuzBoundary(number: 23, startSurah: 36, endSurah: 39, startPage: 442),
  JuzBoundary(number: 24, startSurah: 39, endSurah: 41, startPage: 462),
  JuzBoundary(number: 25, startSurah: 41, endSurah: 45, startPage: 482),
  JuzBoundary(number: 26, startSurah: 46, endSurah: 51, startPage: 502),
  JuzBoundary(number: 27, startSurah: 51, endSurah: 57, startPage: 522),
  JuzBoundary(number: 28, startSurah: 58, endSurah: 66, startPage: 542),
  JuzBoundary(number: 29, startSurah: 67, endSurah: 77, startPage: 562),
  JuzBoundary(number: 30, startSurah: 78, endSurah: 114, startPage: 582),
];

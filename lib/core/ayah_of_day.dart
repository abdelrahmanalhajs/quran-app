import '../data/quran_repository.dart';
import '../models/ayah.dart';
import '../models/surah.dart';
import 'arabic_numbers.dart';

/// Hand-picked passages that read well on their own (no story context
/// needed), as (surah, first ayah, last ayah). The text itself always comes
/// from the app's own Quran data — this list only says which ayahs.
const List<(int, int, int)> kDailyAyahRefs = [
  (1, 1, 7),
  (2, 45, 45),
  (2, 110, 110),
  (2, 152, 152),
  (2, 153, 153),
  (2, 155, 157),
  (2, 186, 186),
  (2, 201, 201),
  (2, 216, 216),
  (2, 255, 255),
  (2, 261, 261),
  (2, 286, 286),
  (3, 8, 8),
  (3, 26, 27),
  (3, 31, 31),
  (3, 92, 92),
  (3, 102, 102),
  (3, 133, 134),
  (3, 139, 139),
  (3, 159, 159),
  (3, 173, 173),
  (3, 185, 185),
  (3, 190, 191),
  (3, 200, 200),
  (4, 28, 28),
  (4, 110, 110),
  (6, 59, 59),
  (6, 162, 163),
  (7, 23, 23),
  (7, 55, 56),
  (7, 199, 199),
  (8, 2, 2),
  (8, 46, 46),
  (9, 51, 51),
  (9, 129, 129),
  (10, 57, 57),
  (10, 62, 64),
  (11, 6, 6),
  (11, 114, 115),
  (12, 86, 87),
  (13, 28, 28),
  (14, 7, 7),
  (14, 34, 34),
  (15, 49, 49),
  (16, 18, 18),
  (16, 90, 90),
  (16, 97, 97),
  (16, 125, 125),
  (16, 128, 128),
  (17, 23, 24),
  (17, 80, 80),
  (18, 10, 10),
  (18, 46, 46),
  (20, 25, 28),
  (20, 114, 114),
  (21, 83, 83),
  (21, 87, 88),
  (21, 107, 107),
  (23, 1, 2),
  (24, 35, 35),
  (25, 63, 63),
  (28, 24, 24),
  (28, 77, 77),
  (29, 69, 69),
  (31, 17, 17),
  (33, 21, 21),
  (33, 41, 42),
  (33, 56, 56),
  (35, 15, 15),
  (39, 9, 9),
  (39, 10, 10),
  (39, 53, 53),
  (40, 44, 44),
  (40, 60, 60),
  (41, 30, 30),
  (41, 34, 34),
  (41, 46, 46),
  (42, 19, 19),
  (42, 43, 43),
  (47, 7, 7),
  (49, 10, 10),
  (49, 12, 12),
  (49, 13, 13),
  (50, 16, 16),
  (51, 56, 56),
  (55, 13, 13),
  (55, 26, 27),
  (57, 21, 21),
  (59, 18, 18),
  (59, 22, 24),
  (62, 10, 10),
  (64, 11, 11),
  (65, 2, 3),
  (65, 7, 7),
  (66, 8, 8),
  (67, 1, 2),
  (76, 9, 9),
  (89, 27, 30),
  (93, 3, 5),
  (94, 5, 8),
  (103, 1, 3),
  (112, 1, 4),
];

class DailyAyah {
  final SurahSummary surah;
  final List<Ayah> ayahs;
  DailyAyah(this.surah, this.ayahs);

  int get firstAyah => ayahs.first.numberInSurah;
  int get lastAyah => ayahs.last.numberInSurah;

  /// The Arabic text with each ayah's end marker.
  String get textAr =>
      ayahs.map((a) => ayahWithEndMarker(a.textAr, a.numberInSurah)).join(' ');

  String get textEn => ayahs.map((a) => a.textEn ?? '').join(' ');

  /// "البقرة: ١٥٢" / "البقرة: ١٥٥–١٥٧".
  String get refAr {
    final a = arabicIndicNumber(firstAyah);
    final b = arabicIndicNumber(lastAyah);
    return '${surah.nameAr}: ${firstAyah == lastAyah ? a : '$a–$b'}';
  }

  /// "Al-Baqarah 2:152" / "Al-Baqarah 2:155-157".
  String get refEn =>
      '${surah.englishName} ${surah.number}:$firstAyah'
      '${firstAyah == lastAyah ? '' : '-$lastAyah'}';
}

/// The passage for [day]: walks [kDailyAyahRefs] in a shuffled order
/// (a fixed stride coprime with the list length), so every passage comes
/// up once before any repeats and the same day always gets the same ayah.
Future<DailyAyah> dailyAyahFor(DateTime day) async {
  final n = kDailyAyahRefs.length;
  final dayNumber =
      DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
  var stride = 37 % n;
  while (stride == 0 || _gcd(stride, n) != 1) {
    stride++;
  }
  final (s, from, to) = kDailyAyahRefs[(dayNumber * stride) % n];
  final repo = QuranRepository();
  final surahs = await repo.getSurahList();
  final surah = surahs.firstWhere((x) => x.number == s);
  final ayahs = (await repo.getSurahAyahs(
    s,
  )).where((a) => a.numberInSurah >= from && a.numberInSurah <= to).toList();
  return DailyAyah(surah, ayahs);
}

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

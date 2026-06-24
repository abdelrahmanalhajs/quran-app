class Ayah {
  final int number;
  final int numberInSurah;
  final int surahNumber;
  final String textAr;
  final String? textEn;
  final int juz;
  final int page;
  final int hizbQuarter;
  final bool sajda;

  Ayah({
    required this.number,
    required this.numberInSurah,
    required this.surahNumber,
    required this.textAr,
    this.textEn,
    required this.juz,
    required this.page,
    required this.hizbQuarter,
    required this.sajda,
  });

  /// 1-based Hizb number (1-60). Each Juz contains 2 Hizb.
  int get hizb => ((hizbQuarter - 1) ~/ 4) + 1;

  /// Quarter within the current Hizb: 1 = start (no fraction mark), 2 = ¼,
  /// 3 = ½, 4 = ¾.
  int get quarterInHizb => ((hizbQuarter - 1) % 4) + 1;

  Ayah copyWithTranslation(String? translation) {
    return Ayah(
      number: number,
      numberInSurah: numberInSurah,
      surahNumber: surahNumber,
      textAr: textAr,
      textEn: translation,
      juz: juz,
      page: page,
      hizbQuarter: hizbQuarter,
      sajda: sajda,
    );
  }

  Ayah copyWithArabicText(String text) {
    return Ayah(
      number: number,
      numberInSurah: numberInSurah,
      surahNumber: surahNumber,
      textAr: text,
      textEn: textEn,
      juz: juz,
      page: page,
      hizbQuarter: hizbQuarter,
      sajda: sajda,
    );
  }

  String get verseKey => '$surahNumber:$numberInSurah';

  factory Ayah.fromArabicJson(Map<String, dynamic> json, int surahNumber) {
    final sajdaValue = json['sajda'];
    return Ayah(
      number: json['number'] as int,
      numberInSurah: json['numberInSurah'] as int,
      surahNumber: surahNumber,
      textAr: json['text'] as String,
      juz: json['juz'] as int,
      page: json['page'] as int,
      hizbQuarter: json['hizbQuarter'] as int,
      sajda: sajdaValue is bool ? sajdaValue : (sajdaValue != null && sajdaValue != false),
    );
  }
}

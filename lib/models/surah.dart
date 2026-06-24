class SurahSummary {
  final int number;
  final String nameAr;
  final String englishName;
  final String englishNameTranslation;
  final int numberOfAyahs;
  final String revelationType;

  SurahSummary({
    required this.number,
    required this.nameAr,
    required this.englishName,
    required this.englishNameTranslation,
    required this.numberOfAyahs,
    required this.revelationType,
  });

  factory SurahSummary.fromJson(Map<String, dynamic> json) {
    return SurahSummary(
      number: json['number'] as int,
      nameAr: json['name'] as String,
      englishName: json['englishName'] as String,
      englishNameTranslation: json['englishNameTranslation'] as String,
      numberOfAyahs: json['numberOfAyahs'] as int,
      revelationType: json['revelationType'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'number': number,
    'name': nameAr,
    'englishName': englishName,
    'englishNameTranslation': englishNameTranslation,
    'numberOfAyahs': numberOfAyahs,
    'revelationType': revelationType,
  };
}

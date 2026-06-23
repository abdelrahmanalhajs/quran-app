class Hadith {
  final String ar;
  final String en;
  final String narrator;
  final String narratorAr;
  final String source;
  final String sourceAr;

  Hadith({
    required this.ar,
    required this.en,
    required this.narrator,
    required this.narratorAr,
    required this.source,
    required this.sourceAr,
  });

  factory Hadith.fromJson(Map<String, dynamic> json) {
    return Hadith(
      ar: json['ar'] as String,
      en: json['en'] as String,
      narrator: json['narrator'] as String,
      narratorAr: json['narrator_ar'] as String,
      source: json['source'] as String,
      sourceAr: json['source_ar'] as String,
    );
  }
}

class Hadith {
  final String ar;
  final String en;
  final String narrator;
  final String source;

  Hadith({required this.ar, required this.en, required this.narrator, required this.source});

  factory Hadith.fromJson(Map<String, dynamic> json) {
    return Hadith(
      ar: json['ar'] as String,
      en: json['en'] as String,
      narrator: json['narrator'] as String,
      source: json['source'] as String,
    );
  }
}

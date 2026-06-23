class Thikr {
  final String ar;
  final String en;
  final int repeat;

  Thikr({required this.ar, required this.en, required this.repeat});

  factory Thikr.fromJson(Map<String, dynamic> json) {
    return Thikr(
      ar: json['ar'] as String,
      en: json['en'] as String,
      repeat: json['repeat'] as int,
    );
  }
}

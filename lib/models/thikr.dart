class Thikr {
  final String ar;
  final String en;
  final int repeat;

  /// True for a recommended practice (sunnah) rather than a recitation, e.g.
  /// "take a bath before Friday prayer" — rendered without the tap-to-count
  /// affordance since there's nothing to recite a specific number of times.
  final bool isSunnah;

  /// Category labels, only set for entries in the classified general
  /// athkar/duaa tab, used to group items under a section header.
  final String? categoryAr;
  final String? categoryEn;

  Thikr({
    required this.ar,
    required this.en,
    required this.repeat,
    this.isSunnah = false,
    this.categoryAr,
    this.categoryEn,
  });

  factory Thikr.fromJson(Map<String, dynamic> json) {
    return Thikr(
      ar: json['ar'] as String,
      en: json['en'] as String,
      repeat: json['repeat'] as int? ?? 1,
      isSunnah: json['isSunnah'] as bool? ?? false,
      categoryAr: json['categoryAr'] as String?,
      categoryEn: json['categoryEn'] as String?,
    );
  }
}

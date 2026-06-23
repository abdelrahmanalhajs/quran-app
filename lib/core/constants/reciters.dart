class Reciter {
  final String id;
  final String nameAr;
  final String nameEn;
  final String baseUrl;
  final int surahCount;

  const Reciter({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.baseUrl,
    required this.surahCount,
  });

  String audioUrlForSurah(int surahNumber) {
    final padded = surahNumber.toString().padLeft(3, '0');
    return '$baseUrl$padded.mp3';
  }

  bool hasSurah(int surahNumber) => surahNumber <= surahCount;
}

const List<Reciter> kReciters = [
  Reciter(
    id: 'abdul_basit',
    nameAr: 'عبد الباسط عبد الصمد',
    nameEn: 'Abdul Basit Abdul Samad',
    baseUrl: 'https://server7.mp3quran.net/basit/',
    surahCount: 114,
  ),
  Reciter(
    id: 'yasser_dosari',
    nameAr: 'ياسر الدوسري',
    nameEn: 'Yasser Al-Dosari',
    baseUrl: 'https://server11.mp3quran.net/yasser/',
    surahCount: 114,
  ),
  Reciter(
    id: 'abdulrahman_sudais',
    nameAr: 'عبد الرحمن السديس',
    nameEn: 'Abdul Rahman Al-Sudais',
    baseUrl: 'https://server11.mp3quran.net/sds/',
    surahCount: 114,
  ),
  Reciter(
    id: 'mahmoud_hussary',
    nameAr: 'محمود خليل الحصري',
    nameEn: 'Mahmoud Khalil Al-Hussary',
    baseUrl: 'https://server13.mp3quran.net/husr/',
    surahCount: 114,
  ),
  Reciter(
    id: 'mohamed_minshawy',
    nameAr: 'محمد صديق المنشاوي',
    nameEn: 'Mohamed Siddiq El-Minshawy',
    baseUrl: 'https://server10.mp3quran.net/minsh/',
    surahCount: 114,
  ),
  Reciter(
    id: 'islam_sobhy',
    nameAr: 'إسلام صبحي',
    nameEn: 'Islam Sobhy',
    baseUrl: 'https://server14.mp3quran.net/islam/Rewayat-Hafs-A-n-Assem/',
    surahCount: 109,
  ),
  Reciter(
    id: 'mishary_afasy',
    nameAr: 'مشاري راشد العفاسي',
    nameEn: 'Mishary Rashid Alafasy',
    baseUrl: 'https://server8.mp3quran.net/afs/',
    surahCount: 114,
  ),
];

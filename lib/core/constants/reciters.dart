class Reciter {
  final String id;
  final String nameAr;
  final String nameEn;
  final String baseUrl;
  final int surahCount;
  // Base URL for individual per-ayah audio files (filename: SSSAAA.mp3),
  // used to start playback from a specific ayah. Null when no per-ayah
  // source is available for this reciter, in which case playback can only
  // start from the beginning of the surah.
  final String? ayahAudioBaseUrl;

  const Reciter({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.baseUrl,
    required this.surahCount,
    this.ayahAudioBaseUrl,
  });

  String audioUrlForSurah(int surahNumber) {
    final padded = surahNumber.toString().padLeft(3, '0');
    return '$baseUrl$padded.mp3';
  }

  bool get supportsAyahPlayback => ayahAudioBaseUrl != null;

  String? audioUrlForAyah(int surahNumber, int ayahNumberInSurah) {
    if (ayahAudioBaseUrl == null) return null;
    final s = surahNumber.toString().padLeft(3, '0');
    final a = ayahNumberInSurah.toString().padLeft(3, '0');
    return '$ayahAudioBaseUrl$s$a.mp3';
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
    ayahAudioBaseUrl: 'https://verses.quran.com/AbdulBaset/Murattal/mp3/',
  ),
  Reciter(
    id: 'yasser_dosari',
    nameAr: 'ياسر الدوسري',
    nameEn: 'Yasser Al-Dosari',
    baseUrl: 'https://server11.mp3quran.net/yasser/',
    surahCount: 114,
    ayahAudioBaseUrl:
        'https://mirrors.quranicaudio.com/everyayah/Yasser_Ad-Dussary_128kbps/',
  ),
  Reciter(
    id: 'abdulrahman_sudais',
    nameAr: 'عبد الرحمن السديس',
    nameEn: 'Abdul Rahman Al-Sudais',
    baseUrl: 'https://server11.mp3quran.net/sds/',
    surahCount: 114,
    ayahAudioBaseUrl: 'https://verses.quran.com/Sudais/mp3/',
  ),
  Reciter(
    id: 'mahmoud_hussary',
    nameAr: 'محمود خليل الحصري',
    nameEn: 'Mahmoud Khalil Al-Hussary',
    baseUrl: 'https://server13.mp3quran.net/husr/',
    surahCount: 114,
    ayahAudioBaseUrl:
        'https://mirrors.quranicaudio.com/everyayah/Husary_64kbps/',
  ),
  Reciter(
    id: 'mohamed_minshawy',
    nameAr: 'محمد صديق المنشاوي',
    nameEn: 'Mohamed Siddiq El-Minshawy',
    baseUrl: 'https://server10.mp3quran.net/minsh/',
    surahCount: 114,
    ayahAudioBaseUrl: 'https://verses.quran.com/Minshawi/Murattal/mp3/',
  ),
  Reciter(
    id: 'islam_sobhy',
    nameAr: 'إسلام صبحي',
    nameEn: 'Islam Sobhy',
    baseUrl: 'https://server14.mp3quran.net/islam/Rewayat-Hafs-A-n-Assem/',
    surahCount: 109,
    // No per-ayah audio source found for this reciter; playback always
    // starts from the beginning of the surah.
  ),
  Reciter(
    id: 'mishary_afasy',
    nameAr: 'مشاري راشد العفاسي',
    nameEn: 'Mishary Rashid Alafasy',
    baseUrl: 'https://server8.mp3quran.net/afs/',
    surahCount: 114,
    ayahAudioBaseUrl: 'https://verses.quran.com/Alafasy/mp3/',
  ),
  Reciter(
    id: 'ahmed_ajamy',
    nameAr: 'الشيخ أحمد العجمي',
    nameEn: 'Sheikh Ahmed Al-Ajamy',
    baseUrl: 'https://server10.mp3quran.net/ajm/',
    surahCount: 114,
    ayahAudioBaseUrl:
        'https://everyayah.com/data/ahmed_ibn_ali_al_ajamy_128kbps/',
  ),
  Reciter(
    id: 'naser_alqatami',
    nameAr: 'ناصر القطامي',
    nameEn: 'Naser Al-Qatami',
    baseUrl: 'https://server6.mp3quran.net/qtm/',
    surahCount: 114,
    ayahAudioBaseUrl: 'https://everyayah.com/data/Nasser_Alqatami_128kbps/',
  ),
];

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../core/services/file_cache.dart';
import '../models/ayah.dart';
import '../models/surah.dart';

class QuranRepository {
  List<SurahSummary>? _surahCache;

  Future<List<SurahSummary>> getSurahList() async {
    if (_surahCache != null) return _surahCache!;

    final cached = await FileCache.read('surah_list');
    if (cached != null) {
      final list = (cached['data'] as List)
          .map((e) => SurahSummary.fromJson(e as Map<String, dynamic>))
          .toList();
      _surahCache = list;
      // Refresh in background; ignore errors.
      _fetchAndCacheSurahList();
      return list;
    }

    return _fetchAndCacheSurahList();
  }

  Future<List<SurahSummary>> _fetchAndCacheSurahList() async {
    final uri = Uri.parse('${ApiConstants.quranBase}/surah');
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      if (_surahCache != null) return _surahCache!;
      throw Exception('Failed to load surah list');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (body['data'] as List)
        .map((e) => SurahSummary.fromJson(e as Map<String, dynamic>))
        .toList();
    _surahCache = list;
    await FileCache.write('surah_list', {'data': list.map((e) => e.toJson()).toList()});
    return list;
  }

  Future<List<Ayah>> getSurahAyahs(int surahNumber, {bool withTranslation = true}) async {
    final cacheKey = 'surah_$surahNumber';
    final cached = await FileCache.read(cacheKey);
    if (cached != null) {
      return _ayahsFromCache(cached, surahNumber);
    }

    final arUri = Uri.parse(
      '${ApiConstants.quranBase}/surah/$surahNumber/${ApiConstants.arabicEdition}',
    );
    final arRes = await http.get(arUri);
    if (arRes.statusCode != 200) {
      throw Exception('Failed to load surah $surahNumber');
    }
    final arBody = jsonDecode(arRes.body) as Map<String, dynamic>;
    final arAyahs = (arBody['data']['ayahs'] as List)
        .map((e) => Ayah.fromArabicJson(e as Map<String, dynamic>, surahNumber))
        .toList();

    List<String>? translations;
    if (withTranslation) {
      final enUri = Uri.parse(
        '${ApiConstants.quranBase}/surah/$surahNumber/${ApiConstants.englishEdition}',
      );
      final enRes = await http.get(enUri);
      if (enRes.statusCode == 200) {
        final enBody = jsonDecode(enRes.body) as Map<String, dynamic>;
        translations = (enBody['data']['ayahs'] as List)
            .map((e) => (e as Map<String, dynamic>)['text'] as String)
            .toList();
      }
    }

    final ayahs = <Ayah>[];
    for (var i = 0; i < arAyahs.length; i++) {
      final translation = translations != null && i < translations.length ? translations[i] : null;
      ayahs.add(arAyahs[i].copyWithTranslation(translation));
    }

    await FileCache.write(cacheKey, {
      'ayahs': ayahs
          .map((a) => {
                'number': a.number,
                'numberInSurah': a.numberInSurah,
                'textAr': a.textAr,
                'textEn': a.textEn,
                'juz': a.juz,
                'page': a.page,
                'sajda': a.sajda,
              })
          .toList(),
    });

    return ayahs;
  }

  List<Ayah> _ayahsFromCache(Map<String, dynamic> cached, int surahNumber) {
    return (cached['ayahs'] as List).map((e) {
      final m = e as Map<String, dynamic>;
      return Ayah(
        number: m['number'] as int,
        numberInSurah: m['numberInSurah'] as int,
        surahNumber: surahNumber,
        textAr: m['textAr'] as String,
        textEn: m['textEn'] as String?,
        juz: m['juz'] as int,
        page: m['page'] as int,
        sajda: m['sajda'] as bool,
      );
    }).toList();
  }
}

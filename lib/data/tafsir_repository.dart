import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../core/services/file_cache.dart';

class TafsirRepository {
  Future<String> getTafsir({
    required int surahNumber,
    required int ayahNumberInSurah,
    required bool arabic,
  }) async {
    final resourceId = arabic
        ? ApiConstants.tafsirMuyassarAr
        : ApiConstants.tafsirIbnKathirEn;
    final verseKey = '$surahNumber:$ayahNumberInSurah';
    final cacheKey = 'tafsir_${resourceId}_$verseKey';

    final cached = await FileCache.read(cacheKey);
    if (cached != null) {
      return cached['text'] as String;
    }

    final uri = Uri.parse(
      '${ApiConstants.tafsirBase}/tafsirs/$resourceId/by_ayah/$verseKey',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed to load tafsir');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final text = (body['tafsir']?['text'] as String?) ?? '';
    final clean = _stripHtml(text);
    await FileCache.write(cacheKey, {'text': clean});
    return clean;
  }

  String _stripHtml(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

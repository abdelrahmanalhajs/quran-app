import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileCache {
  static Directory? _dir;

  static Future<Directory> _cacheDir() async {
    if (_dir != null) return _dir!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/quran_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _dir = dir;
    return dir;
  }

  static Future<Map<String, dynamic>?> read(String key) async {
    try {
      final dir = await _cacheDir();
      final file = File('${dir.path}/$key.json');
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String key, Map<String, dynamic> data) async {
    try {
      final dir = await _cacheDir();
      final file = File('${dir.path}/$key.json');
      await file.writeAsString(jsonEncode(data));
    } catch (_) {
      // Caching is best-effort; ignore failures.
    }
  }
}

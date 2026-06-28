import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import '../constants/reciters.dart';

/// Saves whole-surah recitation audio to permanent on-device storage so the
/// Quran audio can be played fully offline — not just after it has been
/// streamed once (the [LockCachingAudioSource] cache the player keeps can be
/// evicted by the OS and only covers what was actually listened to). A user
/// downloads a reciter once over the network, and from then on every surah
/// plays straight from local files with no connection.
///
/// Per-surah files (114 of them) are downloaded rather than the ~6236 per-ayah
/// clips: full-surah playback is what "play this surah" uses, and bundling the
/// per-ayah grid would multiply the storage many times over for little gain.
class OfflineRecitations {
  OfflineRecitations._();
  static final OfflineRecitations instance = OfflineRecitations._();

  Directory? _root;

  Future<Directory> _reciterDir(String reciterId) async {
    _root ??= await getApplicationSupportDirectory();
    final dir = Directory('${_root!.path}/recitations/$reciterId');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Absolute path a given surah's audio is (or would be) stored at. Sync so
  /// the player can probe it cheaply on every play; relies on [_root] having
  /// been resolved already by an earlier async call (see [warmUp]).
  String? localSurahPath(String reciterId, int surahNumber) {
    if (_root == null) return null;
    final padded = surahNumber.toString().padLeft(3, '0');
    return '${_root!.path}/recitations/$reciterId/$padded.mp3';
  }

  /// Whether [surahNumber] for [reciterId] is already downloaded.
  bool isDownloaded(String reciterId, int surahNumber) {
    final p = localSurahPath(reciterId, surahNumber);
    return p != null && File(p).existsSync();
  }

  /// Resolves and caches the storage root up front so [localSurahPath] /
  /// [isDownloaded] work synchronously thereafter. Call once at startup.
  Future<void> warmUp() async {
    _root ??= await getApplicationSupportDirectory();
  }

  /// How many of [reciter]'s surahs are already on disk.
  Future<int> downloadedCount(Reciter reciter) async {
    await _reciterDir(reciter.id);
    var n = 0;
    for (var s = 1; s <= reciter.surahCount; s++) {
      if (isDownloaded(reciter.id, s)) n++;
    }
    return n;
  }

  /// Downloads every surah of [reciter] that isn't already saved, reporting
  /// progress as (done, total) after each file. Re-runnable: existing files
  /// are skipped, so an interrupted download just resumes. Throws on a network
  /// error so the caller can surface it; partially written files are cleaned
  /// up so a failed surah is retried rather than left corrupt.
  Future<void> downloadAll(
    Reciter reciter, {
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    await _reciterDir(reciter.id);
    final total = reciter.surahCount;
    final client = HttpClient();
    try {
      for (var s = 1; s <= total; s++) {
        if (isCancelled?.call() ?? false) return;
        if (!isDownloaded(reciter.id, s)) {
          await _downloadOne(client, reciter, s);
        }
        onProgress?.call(s, total);
      }
    } finally {
      client.close();
    }
  }

  Future<void> _downloadOne(HttpClient client, Reciter reciter, int surah) async {
    final url = reciter.audioUrlForSurah(surah);
    final path = localSurahPath(reciter.id, surah)!;
    final tmp = File('$path.part');
    try {
      final req = await client.getUrl(Uri.parse(url));
      final resp = await req.close();
      if (resp.statusCode != 200) {
        throw HttpException('HTTP ${resp.statusCode} for $url');
      }
      final sink = tmp.openWrite();
      await resp.pipe(sink);
      await tmp.rename(path);
    } catch (_) {
      if (tmp.existsSync()) tmp.deleteSync();
      rethrow;
    }
  }

  /// Removes all downloaded surahs for [reciter], freeing the space.
  Future<void> deleteAll(Reciter reciter) async {
    final dir = await _reciterDir(reciter.id);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}

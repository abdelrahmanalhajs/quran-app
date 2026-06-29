import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/reciters.dart';
import '../core/services/offline_recitations.dart';

class AudioProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  int? _currentSurah;
  Reciter? _currentReciter;
  bool _isLoading = false;
  int? _currentAyahIndex; // 0-based index into the playing-from-ayah playlist
  int?
  _ayahPlaylistStart; // 1-based ayah number the current playlist started at

  static const _kLastSurah = 'audio_last_surah';
  static const _kLastReciter = 'audio_last_reciter';
  static const _kLastPositionMs = 'audio_last_position_ms';

  AudioProvider() {
    _player.playerStateStream.listen((_) => notifyListeners());
    _player.positionStream.listen((pos) {
      if (_currentSurah != null && _currentReciter != null && _player.playing) {
        _savePosition(pos);
      }
    });
    _player.currentIndexStream.listen((index) {
      _currentAyahIndex = index;
      notifyListeners();
    });
  }

  AudioPlayer get player => _player;
  int? get currentSurah => _currentSurah;
  Reciter? get currentReciter => _currentReciter;
  bool get isLoading => _isLoading;
  bool get isPlaying => _player.playing;
  int? get currentAyahIndex => _currentAyahIndex;
  int? get currentAbsoluteAyah =>
      (_ayahPlaylistStart != null && _currentAyahIndex != null)
      ? _ayahPlaylistStart! + _currentAyahIndex!
      : null;

  bool isCurrentlyPlaying(int surahNumber, Reciter reciter) {
    return _currentSurah == surahNumber &&
        _currentReciter?.id == reciter.id &&
        _player.playing;
  }

  DateTime? _lastSaveTime;
  void _savePosition(Duration pos) {
    final now = DateTime.now();
    if (_lastSaveTime != null &&
        now.difference(_lastSaveTime!) < const Duration(seconds: 2)) {
      return;
    }
    _lastSaveTime = now;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt(_kLastSurah, _currentSurah!);
      prefs.setString(_kLastReciter, _currentReciter!.id);
      prefs.setInt(_kLastPositionMs, pos.inMilliseconds);
    });
  }

  /// Returns the saved playback position for [surahNumber]/[reciter], if the
  /// app was closed or navigated away while that surah was playing.
  Future<Duration?> savedPositionFor(int surahNumber, Reciter reciter) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt(_kLastSurah) == surahNumber &&
        prefs.getString(_kLastReciter) == reciter.id) {
      final ms = prefs.getInt(_kLastPositionMs);
      if (ms != null && ms > 0) return Duration(milliseconds: ms);
    }
    return null;
  }

  /// Streams a recording straight from its URL. We deliberately do *not* use
  /// the caching proxy source any more: it ran a local 127.0.0.1 HTTP proxy
  /// that intermittently answered the player with a 500 on the first load even
  /// when the CDN itself returned 200 — which showed up as audio "not loading
  /// until you restart the app". Offline playback is now handled explicitly by
  /// [OfflineRecitations] (a downloaded surah plays from its local file in
  /// [playSurah]), so plain direct streaming here is both simpler and far more
  /// reliable, on every platform including web.
  AudioSource _audioSource(String url, MediaItem tag) {
    return AudioSource.uri(Uri.parse(url), tag: tag);
  }

  Future<void> playSurah(
    int surahNumber,
    Reciter reciter, {
    bool resume = false,
    String? surahTitle,
  }) async {
    if (!reciter.hasSurah(surahNumber)) {
      throw Exception('This reciter has no recording for this surah');
    }

    if (_currentSurah == surahNumber && _currentReciter?.id == reciter.id) {
      if (_player.playing) {
        await _player.pause();
      } else {
        // After playback reaches the end, just_audio won't restart on play()
        // alone — seek back to the start first so pressing play again
        // repeats the surah instead of doing nothing.
        if (_player.processingState == ProcessingState.completed) {
          await _player.seek(Duration.zero);
        }
        await _player.play();
      }
      return;
    }

    _isLoading = true;
    _currentSurah = surahNumber;
    _currentReciter = reciter;
    _currentAyahIndex = null;
    _ayahPlaylistStart = null;
    notifyListeners();
    try {
      final tag = MediaItem(
        id: 'surah_${surahNumber}_${reciter.id}',
        title: surahTitle ?? 'Surah $surahNumber',
        artist: reciter.nameEn,
      );
      // Prefer a fully downloaded local file (see [OfflineRecitations]) so a
      // downloaded surah plays with no network at all; otherwise stream.
      final localPath = kIsWeb
          ? null
          : OfflineRecitations.instance.localSurahPath(reciter.id, surahNumber);
      final source = (localPath != null && OfflineRecitations.instance.isDownloaded(reciter.id, surahNumber))
          ? AudioSource.file(localPath, tag: tag)
          : _audioSource(reciter.audioUrlForSurah(surahNumber), tag);
      await _player.setAudioSource(source);
      if (resume) {
        final saved = await savedPositionFor(surahNumber, reciter);
        if (saved != null) {
          await _player.seek(saved);
        }
      }
      await _player.play();
    } catch (_) {
      // The source never loaded (a transient network/proxy hiccup on the first
      // attempt). Clear the "current" pointers so the next tap re-runs
      // setAudioSource from scratch instead of taking the "same surah, just
      // play()" shortcut above on a dead source — which looked like audio
      // "not loading until you restart the app".
      _currentSurah = null;
      _currentReciter = null;
      await _player.stop();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Plays [surahNumber] starting from [ayahNumberInSurah] (1-based) through
  /// to the end of the surah, using per-ayah audio files chained as a
  /// playlist so playback continues seamlessly into the following ayahs.
  /// Falls back to playing the whole surah from the start if [reciter] has
  /// no per-ayah audio source.
  Future<void> playFromAyah({
    required int surahNumber,
    required int ayahNumberInSurah,
    required int totalAyahsInSurah,
    required Reciter reciter,
    String? surahTitle,
  }) async {
    if (!reciter.supportsAyahPlayback) {
      await playSurah(surahNumber, reciter, surahTitle: surahTitle);
      return;
    }

    _isLoading = true;
    _currentSurah = surahNumber;
    _currentReciter = reciter;
    _currentAyahIndex = 0;
    _ayahPlaylistStart = ayahNumberInSurah;
    notifyListeners();
    try {
      final title = surahTitle ?? 'Surah $surahNumber';
      final sources = [
        for (var ayah = ayahNumberInSurah; ayah <= totalAyahsInSurah; ayah++)
          _audioSource(
            reciter.audioUrlForAyah(surahNumber, ayah)!,
            MediaItem(
              id: 'ayah_${surahNumber}_${ayah}_${reciter.id}',
              title: '$title · ${ayah.toString()}',
              artist: reciter.nameEn,
            ),
          ),
      ];
      await _player.setAudioSource(ConcatenatingAudioSource(children: sources));
      await _player.play();
    } catch (_) {
      // See [playSurah]: clear state on a failed first load so a retry works
      // without restarting the app.
      _currentSurah = null;
      _currentReciter = null;
      _ayahPlaylistStart = null;
      await _player.stop();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _currentSurah = null;
    _currentReciter = null;
    _currentAyahIndex = null;
    _ayahPlaylistStart = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

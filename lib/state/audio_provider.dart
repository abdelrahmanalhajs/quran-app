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

  /// Builds the right [AudioSource] for the platform. On mobile/desktop we use
  /// `LockCachingAudioSource`, which streams while saving to disk so a once-
  /// played recording then replays fully offline. That source relies on a
  /// local 127.0.0.1 proxy, which doesn't exist on the web — there it simply
  /// never starts, which is why Quran audio "did nothing" in the browser. On
  /// web, stream the URL directly instead.
  AudioSource _audioSource(String url, MediaItem tag) {
    if (kIsWeb) {
      return AudioSource.uri(Uri.parse(url), tag: tag);
    }
    // ignore: experimental_member_use
    return LockCachingAudioSource(Uri.parse(url), tag: tag);
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

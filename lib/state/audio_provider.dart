import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/reciters.dart';
import '../core/services/offline_recitations.dart';
import '../data/quran_repository.dart';

class AudioProvider extends ChangeNotifier {
  // Not final — see [_recreatePlayer]: a setAudioSource failure can leave
  // the underlying native ExoPlayer/AVPlayer instance itself wedged, in
  // which case retrying setAudioSource on the *same* player keeps failing
  // silently no matter how many times the user taps play, and only fully
  // closing and reopening the app (which tears down and recreates
  // everything) ever got it playing again. Recreating just this one player
  // on a failed load gets the same clean slate without needing a restart.
  AudioPlayer _player = AudioPlayer();
  int? _currentSurah;
  Reciter? _currentReciter;
  bool _isLoading = false;
  int? _currentAyahIndex; // 0-based index into the playing-from-ayah playlist
  int?
  _ayahPlaylistStart; // 1-based ayah number the current playlist started at

  // Identifies a short, non-Quran clip played through this same player (an
  // athan preview or a notification's full athan replay — see [playOneShot]).
  // Not just a nice-to-have: [JustAudioBackground] hard-codes support for
  // exactly one live [AudioPlayer] for the whole app (its `init()` throws
  // "supports only a single player instance" for a second one), so every
  // sound the app plays *has* to share this one player rather than each
  // feature owning its own — see [playOneShot]'s doc comment.
  String? _oneShotId;

  static const _kLastSurah = 'audio_last_surah';
  static const _kLastReciter = 'audio_last_reciter';
  static const _kLastPositionMs = 'audio_last_position_ms';
  // Set instead of [_kLastPositionMs] while playing from an ayah: the
  // player's position then is inside that one ayah's clip, so saving it as
  // a whole-surah position resumed the full surah near its start instead
  // of where the user stopped. The ayah number is what resumes correctly.
  static const _kLastAyah = 'audio_last_ayah';

  AudioProvider() {
    _attachListeners();
  }

  // Tracks the previous emission so a completed-state auto-advance only
  // fires once per actual completion, not on every rebuild-triggered replay
  // of the stream's latest value.
  ProcessingState? _lastProcessingState;

  void _attachListeners() {
    _player.playerStateStream.listen((state) {
      notifyListeners();
      final justCompleted =
          state.processingState == ProcessingState.completed &&
          _lastProcessingState != ProcessingState.completed;
      _lastProcessingState = state.processingState;
      if (justCompleted) _playNextSurah();
    });
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

  /// Continues straight into the next surah once the current one finishes —
  /// whether it was played whole ([playSurah]) or from a specific ayah
  /// onward ([playFromAyah]), both of which set [_currentSurah]/
  /// [_currentReciter] the same way. Silently does nothing past An-Nas
  /// (114) or if the reciter has no recording for the next surah, rather
  /// than throwing mid-playback.
  Future<void> _playNextSurah() async {
    final surah = _currentSurah;
    final reciter = _currentReciter;
    if (surah == null || reciter == null) return;
    final next = surah + 1;
    if (next > 114 || !reciter.hasSurah(next)) return;
    String? title;
    try {
      final list = await QuranRepository().getSurahList();
      for (final s in list) {
        if (s.number == next) {
          title = s.nameAr;
          break;
        }
      }
    } catch (_) {
      // Falls back to playSurah's own generic title below.
    }
    await playSurah(next, reciter, surahTitle: title);
  }

  /// Tears down the current player and swaps in a fresh one with its own
  /// listeners re-attached — see the field doc on [_player] for why this is
  /// necessary on a failed load rather than just clearing surah/reciter
  /// state and letting the next tap retry on the same instance.
  Future<void> _recreatePlayer() async {
    final old = _player;
    _player = AudioPlayer();
    _attachListeners();
    await old.dispose();
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
  String? get currentOneShotId => _oneShotId;

  bool isCurrentlyPlaying(int surahNumber, Reciter reciter) {
    return _currentSurah == surahNumber &&
        _currentReciter?.id == reciter.id &&
        _player.playing;
  }

  bool isOneShotPlaying(String id) => _oneShotId == id && _player.playing;

  DateTime? _lastSaveTime;
  void _savePosition(Duration pos) {
    final now = DateTime.now();
    if (_lastSaveTime != null &&
        now.difference(_lastSaveTime!) < const Duration(seconds: 2)) {
      return;
    }
    _lastSaveTime = now;
    final ayah = currentAbsoluteAyah;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt(_kLastSurah, _currentSurah!);
      prefs.setString(_kLastReciter, _currentReciter!.id);
      if (ayah != null) {
        // "Ayah 0" is the Basmala lead-in; resuming from it means ayah 1.
        prefs.setInt(_kLastAyah, ayah < 1 ? 1 : ayah);
        prefs.remove(_kLastPositionMs);
      } else {
        prefs.setInt(_kLastPositionMs, pos.inMilliseconds);
        prefs.remove(_kLastAyah);
      }
    });
  }

  /// The ayah (1-based, within [surahNumber]) that playback was last at when
  /// it was playing from an ayah onward, if that's how it was last left.
  Future<int?> _savedAyahFor(int surahNumber, Reciter reciter) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt(_kLastSurah) == surahNumber &&
        prefs.getString(_kLastReciter) == reciter.id) {
      return prefs.getInt(_kLastAyah);
    }
    return null;
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
    _cancelHifz();
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

    // Last left mid-surah while playing from an ayah (e.g. paused, then the
    // app was closed): carry on from that same ayah through to the end of
    // the surah, rather than restarting the whole surah from the top.
    if (resume && reciter.supportsAyahPlayback) {
      final savedAyah = await _savedAyahFor(surahNumber, reciter);
      if (savedAyah != null) {
        int? total;
        try {
          final list = await QuranRepository().getSurahList();
          for (final s in list) {
            if (s.number == surahNumber) total = s.numberOfAyahs;
          }
        } catch (_) {}
        if (total != null && savedAyah <= total) {
          await playFromAyah(
            surahNumber: surahNumber,
            ayahNumberInSurah: savedAyah,
            totalAyahsInSurah: total,
            reciter: reciter,
            surahTitle: surahTitle,
          );
          return;
        }
      }
    }

    // Play the whole surah ayah by ayah when the reciter publishes per-ayah
    // recordings and the surah isn't downloaded for offline use: the
    // playlist knows which ayah is playing, so the reader highlights it and
    // turns the page with the recitation (a single whole-surah file has no
    // per-ayah timing to do that with). A saved mid-file position from a
    // whole-surah session still resumes in the whole-surah file below.
    final downloaded =
        !kIsWeb &&
        OfflineRecitations.instance.isDownloaded(reciter.id, surahNumber);
    final hasSavedFilePosition =
        resume && await savedPositionFor(surahNumber, reciter) != null;
    if (reciter.supportsAyahPlayback && !downloaded && !hasSavedFilePosition) {
      int? total;
      try {
        final list = await QuranRepository().getSurahList();
        for (final s in list) {
          if (s.number == surahNumber) total = s.numberOfAyahs;
        }
      } catch (_) {}
      if (total != null) {
        await playFromAyah(
          surahNumber: surahNumber,
          ayahNumberInSurah: 1,
          totalAyahsInSurah: total,
          reciter: reciter,
          surahTitle: surahTitle,
        );
        return;
      }
    }

    _isLoading = true;
    _currentSurah = surahNumber;
    _currentReciter = reciter;
    _currentAyahIndex = null;
    _ayahPlaylistStart = null;
    _oneShotId = null;
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
      final source =
          (localPath != null &&
              OfflineRecitations.instance.isDownloaded(reciter.id, surahNumber))
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
      // The source never loaded (a transient network/proxy hiccup on the
      // first attempt, or the player itself wedged — see [_recreatePlayer]).
      // Clear the "current" pointers so the next tap re-runs setAudioSource
      // from scratch instead of taking the "same surah, just play()"
      // shortcut above on a dead source, and get a fresh player so that
      // retry isn't doomed to fail the same way again — together this is
      // what used to require fully restarting the app.
      _currentSurah = null;
      _currentReciter = null;
      await _recreatePlayer();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Plays [surahNumber] starting from [ayahNumberInSurah] (1-based) through
  /// to the end of the surah, using per-ayah audio files chained as a
  /// playlist so playback continues seamlessly into the following ayahs.
  ///
  /// Returns false — after falling back to playing the whole surah from the
  /// start — when [reciter] publishes no per-ayah recordings and so can't
  /// start mid-surah at all. Callers are expected to tell the user why they
  /// got the whole surah instead of the ayah they asked for; silently doing
  /// something different looks exactly like the feature being broken.
  Future<bool> playFromAyah({
    required int surahNumber,
    required int ayahNumberInSurah,
    required int totalAyahsInSurah,
    required Reciter reciter,
    String? surahTitle,
  }) async {
    _cancelHifz();
    if (!reciter.supportsAyahPlayback) {
      await playSurah(surahNumber, reciter, surahTitle: surahTitle);
      return false;
    }

    _isLoading = true;
    _currentSurah = surahNumber;
    _currentReciter = reciter;
    _currentAyahIndex = 0;
    _ayahPlaylistStart = ayahNumberInSurah;
    _oneShotId = null;
    notifyListeners();
    try {
      final title = surahTitle ?? 'Surah $surahNumber';
      // Guards against a caller that couldn't resolve the surah's real ayah
      // count passing a total below the starting ayah: that would build an
      // empty playlist, which loads "successfully" and then sits silent
      // before auto-advancing to the next surah.
      final lastAyah = totalAyahsInSurah < ayahNumberInSurah
          ? ayahNumberInSurah
          : totalAyahsInSurah;
      // Per-ayah recordings don't include the Basmala that opens every surah
      // except Al-Fatiha (where it is ayah 1) and At-Tawbah (which has
      // none), so recite it first when starting from the top. It sits at
      // playlist index 0 as "ayah 0", which highlights nothing.
      final withBasmala =
          ayahNumberInSurah == 1 && surahNumber != 1 && surahNumber != 9;
      if (withBasmala) _ayahPlaylistStart = 0;
      final sources = [
        if (withBasmala)
          _audioSource(
            reciter.audioUrlForAyah(1, 1)!,
            MediaItem(
              id: 'basmala_${surahNumber}_${reciter.id}',
              title: title,
              artist: reciter.nameEn,
            ),
          ),
        for (var ayah = ayahNumberInSurah; ayah <= lastAyah; ayah++)
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
      // Per-ayah playback only ever streams from the network — there's no
      // downloaded per-ayah file to fall back to (see [OfflineRecitations]'s
      // doc comment: only whole-surah files are saved). So a failure here is
      // exactly what happens with no connection, which is precisely when a
      // downloaded surah is most likely to be in use. Rather than leaving
      // playback dead, fall back to the local whole-surah file like
      // [playSurah] does, same as the no-per-ayah-support case above — the
      // caller shows the same "played from the start instead" message.
      _ayahPlaylistStart = null;
      final localPath = kIsWeb
          ? null
          : OfflineRecitations.instance.localSurahPath(reciter.id, surahNumber);
      if (localPath != null &&
          OfflineRecitations.instance.isDownloaded(reciter.id, surahNumber)) {
        _currentAyahIndex = null;
        try {
          final tag = MediaItem(
            id: 'surah_${surahNumber}_${reciter.id}',
            title: surahTitle ?? 'Surah $surahNumber',
            artist: reciter.nameEn,
          );
          await _player.setAudioSource(AudioSource.file(localPath, tag: tag));
          await _player.play();
          return false;
        } catch (_) {
          // Even the local file failed to load — fall through to the same
          // recreate-and-clear recovery as the network-only case.
        }
      }
      // See [playSurah]: clear state and get a fresh player so a retry
      // works without restarting the app.
      _currentSurah = null;
      _currentReciter = null;
      await _recreatePlayer();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return true;
  }

  /// Plays a short local clip — an athan preview (Settings) or a
  /// notification's full athan replay (see [NotificationService.playAthan])
  /// — through this same shared player rather than a separate [AudioPlayer]
  /// of the clip's own. [JustAudioBackground] only ever supports one live
  /// player for the whole app; a second instance's very first
  /// `setAudioSource` throws "supports only a single player instance" and
  /// that feature's audio silently never plays again for the rest of the
  /// session — which is exactly what made the athan preview (and, whichever
  /// of the two claimed the single slot first, Quran playback too) stop
  /// working. Interrupts whatever else was playing, same as tapping a
  /// different surah would.
  Future<void> playOneShot({
    required String assetPath,
    required String id,
    required String title,
  }) async {
    _cancelHifz();
    if (_oneShotId == id) {
      if (_player.playing) {
        await _player.pause();
      } else {
        if (_player.processingState == ProcessingState.completed) {
          await _player.seek(Duration.zero);
        }
        await _player.play();
      }
      return;
    }

    _oneShotId = id;
    _currentSurah = null;
    _currentReciter = null;
    _currentAyahIndex = null;
    _ayahPlaylistStart = null;
    notifyListeners();
    try {
      await _player.setAudioSource(
        AudioSource.asset(
          assetPath,
          tag: MediaItem(id: id, title: title),
        ),
      );
      await _player.play();
    } catch (_) {
      _oneShotId = null;
      await _recreatePlayer();
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> stop() async {
    _cancelHifz();
    await _player.stop();
    _currentSurah = null;
    _currentReciter = null;
    _currentAyahIndex = null;
    _ayahPlaylistStart = null;
    _oneShotId = null;
    notifyListeners();
  }

  // ---- Hifz (memorization) repeat player ----

  int _hifzToken = 0;
  bool _hifzActive = false;
  int? _hifzSurah;
  int? _hifzAyah;
  int _hifzRepeat = 0;
  int _hifzRound = 0;

  bool get hifzActive => _hifzActive;
  int? get hifzSurah => _hifzSurah;

  /// The ayah currently being repeated in a Hifz session.
  int? get hifzAyah => _hifzAyah;

  /// 1-based repetition of [hifzAyah] in progress.
  int get hifzRepeat => _hifzRepeat;

  /// 1-based pass over the whole range.
  int get hifzRound => _hifzRound;

  void _cancelHifz() {
    if (!_hifzActive && _hifzAyah == null) return;
    _hifzToken++;
    _hifzActive = false;
    _hifzSurah = null;
    _hifzAyah = null;
    notifyListeners();
  }

  /// Memorization playback: each ayah of [fromAyah]..[toAyah] is recited
  /// [repeatEach] times with [pause] between repetitions, and the whole
  /// range is gone through [repeatRange] times (0 = until stopped). Runs one
  /// ayah file at a time on the shared player; anything else starting to
  /// play (or [stopHifz]) ends the session.
  Future<void> playHifz({
    required int surahNumber,
    required int fromAyah,
    required int toAyah,
    required Reciter reciter,
    required int repeatEach,
    required int repeatRange,
    required Duration pause,
    String? surahTitle,
  }) async {
    if (!reciter.supportsAyahPlayback) return;
    _cancelHifz();
    final token = ++_hifzToken;
    // Not a surah session: keeps the auto-advance-to-next-surah listener
    // and position saving out of the way.
    await _player.stop();
    _currentSurah = null;
    _currentReciter = null;
    _currentAyahIndex = null;
    _ayahPlaylistStart = null;
    _oneShotId = null;
    _hifzActive = true;
    _hifzSurah = surahNumber;
    notifyListeners();

    bool alive() => token == _hifzToken;
    try {
      for (var round = 1; repeatRange == 0 || round <= repeatRange; round++) {
        for (var ayah = fromAyah; ayah <= toAyah; ayah++) {
          for (var rep = 1; rep <= repeatEach; rep++) {
            if (!alive()) return;
            _hifzRound = round;
            _hifzAyah = ayah;
            _hifzRepeat = rep;
            notifyListeners();
            await _player.setAudioSource(
              _audioSource(
                reciter.audioUrlForAyah(surahNumber, ayah)!,
                MediaItem(
                  id: 'hifz_${surahNumber}_${ayah}_$rep',
                  title: '${surahTitle ?? 'Surah $surahNumber'} · $ayah',
                  artist: reciter.nameEn,
                ),
              ),
            );
            if (!alive()) return;
            await _player.play();
            // play() returns once playback completes, pauses or stops; only
            // a natural completion carries on.
            if (!alive() ||
                _player.processingState != ProcessingState.completed) {
              if (alive()) _cancelHifz();
              return;
            }
            final lastOfAll =
                ayah == toAyah && rep == repeatEach && round == repeatRange;
            if (!lastOfAll && pause > Duration.zero) {
              await Future.delayed(pause);
            }
          }
        }
      }
    } catch (_) {
      // Network failure mid-session: end it cleanly.
    } finally {
      if (alive()) {
        _hifzActive = false;
        _hifzAyah = null;
        notifyListeners();
      }
    }
  }

  Future<void> stopHifz() async {
    _cancelHifz();
    await _player.stop();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

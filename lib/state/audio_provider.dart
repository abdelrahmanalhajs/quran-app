import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../core/constants/reciters.dart';

class AudioProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  int? _currentSurah;
  Reciter? _currentReciter;
  bool _isLoading = false;

  AudioProvider() {
    _player.playerStateStream.listen((_) => notifyListeners());
  }

  AudioPlayer get player => _player;
  int? get currentSurah => _currentSurah;
  Reciter? get currentReciter => _currentReciter;
  bool get isLoading => _isLoading;
  bool get isPlaying => _player.playing;

  bool isCurrentlyPlaying(int surahNumber, Reciter reciter) {
    return _currentSurah == surahNumber && _currentReciter?.id == reciter.id && _player.playing;
  }

  Future<void> playSurah(int surahNumber, Reciter reciter) async {
    if (!reciter.hasSurah(surahNumber)) {
      throw Exception('This reciter has no recording for this surah');
    }

    if (_currentSurah == surahNumber && _currentReciter?.id == reciter.id) {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
      return;
    }

    _isLoading = true;
    _currentSurah = surahNumber;
    _currentReciter = reciter;
    notifyListeners();
    try {
      await _player.setUrl(reciter.audioUrlForSurah(surahNumber));
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
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

import 'package:flutter/foundation.dart';
import '../core/services/athan_settings.dart';
import '../core/services/notification_service.dart';
import '../data/prayer_repository.dart';
import '../models/prayer_times.dart';

enum PrayerLoadStatus { idle, loadingLocation, loadingData, loaded, permissionDenied, error }

class PrayerProvider extends ChangeNotifier {
  final PrayerRepository _repo = PrayerRepository();

  PrayerLoadStatus _status = PrayerLoadStatus.idle;
  PrayerTimes? _times;
  double? _qiblaDirection;
  double? _latitude;
  double? _longitude;
  String? _errorMessage;

  PrayerLoadStatus get status => _status;
  PrayerTimes? get times => _times;
  double? get qiblaDirection => _qiblaDirection;
  String? get errorMessage => _errorMessage;

  Future<void> load({bool arabicAthanLabels = false}) async {
    _status = PrayerLoadStatus.loadingLocation;
    notifyListeners();
    try {
      final position = await _repo.getCurrentPosition();
      _latitude = position.latitude;
      _longitude = position.longitude;

      _status = PrayerLoadStatus.loadingData;
      notifyListeners();

      final results = await Future.wait([
        _repo.getPrayerTimes(_latitude!, _longitude!),
        _repo.getQiblaDirection(_latitude!, _longitude!),
      ]);
      _times = results[0] as PrayerTimes;
      _qiblaDirection = results[1] as double;
      _status = PrayerLoadStatus.loaded;

      if (!kIsWeb && await AthanSettings.isEnabled()) {
        final athan = await AthanSettings.getReciter();
        await NotificationService.schedulePrayerAthans(
          times: _times!.obligatoryPrayers,
          athan: athan,
          arabic: arabicAthanLabels,
        );
      }
    } catch (e) {
      _errorMessage = e.toString();
      _status = e.toString().contains('permission')
          ? PrayerLoadStatus.permissionDenied
          : PrayerLoadStatus.error;
    }
    notifyListeners();
  }
}

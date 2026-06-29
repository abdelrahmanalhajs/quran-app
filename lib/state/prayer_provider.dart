import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/services/athan_settings.dart';
import '../core/services/athkar_prayer_reminder_settings.dart';
import '../core/services/notification_service.dart';
import '../core/services/prayer_widget.dart';
import '../data/prayer_repository.dart';
import '../models/prayer_times.dart';

enum PrayerLoadStatus {
  idle,
  loadingLocation,
  loadingData,
  loaded,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  timedOut,
  error,
}

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
  double? get latitude => _latitude;
  double? get longitude => _longitude;
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

      // Prayer times and qibla are computed locally (see PrayerRepository),
      // so this no longer depends on a network call that can fail.
      _times = _repo.getPrayerTimes(_latitude!, _longitude!);
      _qiblaDirection = _repo.getQiblaDirection(_latitude!, _longitude!);
      _status = PrayerLoadStatus.loaded;

      if (!kIsWeb) {
        await PrayerWidget.update(
          times: _times!.obligatoryPrayers,
          arabic: arabicAthanLabels,
        );
      }

      if (!kIsWeb && await AthanSettings.isEnabled()) {
        final athan = await AthanSettings.getReciter();
        await NotificationService.schedulePrayerAthans(
          times: _times!.obligatoryPrayers,
          athan: athan,
          arabic: arabicAthanLabels,
        );
      }
      if (!kIsWeb && await AthkarPrayerReminderSettings.isEnabled()) {
        await NotificationService.scheduleAthkarPrayerReminders(
          times: _times!.obligatoryPrayers,
          arabic: arabicAthanLabels,
        );
      }
    } on LocationPermissionDeniedForeverException {
      _status = PrayerLoadStatus.permissionDeniedForever;
    } on LocationPermissionDeniedException {
      _status = PrayerLoadStatus.permissionDenied;
    } on LocationServiceDisabledException {
      _status = PrayerLoadStatus.serviceDisabled;
    } on TimeoutException {
      _status = PrayerLoadStatus.timedOut;
    } catch (e) {
      _errorMessage = e.toString();
      _status = PrayerLoadStatus.error;
    }
    notifyListeners();
  }
}

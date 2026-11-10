import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart' show Geolocator;
import 'package:shared_preferences/shared_preferences.dart';
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

const _kPlaceName = 'prayer_place_name';
const _kPlaceLang = 'prayer_place_lang';
const _kPlaceLat = 'prayer_place_lat';
const _kPlaceLng = 'prayer_place_lng';
const _kCountryCode = 'prayer_country_code';

/// Moving further than this re-geocodes the governorate name and
/// recomputes prayer times for the new place.
const _kSignificantMoveMeters = 3000.0;

class PrayerProvider extends ChangeNotifier with WidgetsBindingObserver {
  PrayerProvider() {
    WidgetsBinding.instance.addObserver(this);
  }

  final PrayerRepository _repo = PrayerRepository();

  PrayerLoadStatus _status = PrayerLoadStatus.idle;
  PrayerTimes? _times;
  double? _qiblaDirection;
  double? _latitude;
  double? _longitude;
  String? _errorMessage;
  String? _placeName;
  String? _placeLang;
  String? _countryCode;
  bool _arabic = false;
  bool _loading = false;

  // Lets times follow the device without the user having to pull to
  // refresh: the day rolling over, the time zone changing (travel, DST) or
  // the device moving all recompute them. See [_tick] / [didChangeAppLifecycleState].
  Timer? _ticker;
  DateTime? _computedForDay;
  Duration? _computedForOffset;
  DateTime? _lastLocationCheck;

  PrayerLoadStatus get status => _status;
  PrayerTimes? get times => _times;
  double? get qiblaDirection => _qiblaDirection;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  String? get errorMessage => _errorMessage;

  /// The device's governorate / state / province, in the app language.
  String? get placeName => _placeName;

  /// Language [placeName] was geocoded in, so the screen can ask for it
  /// again in the other language after a locale switch.
  String? get placeLanguage => _placeLang;

  Future<void> load({
    bool arabicAthanLabels = false,
    bool silent = false,
  }) async {
    if (_loading) return;
    _loading = true;
    _arabic = arabicAthanLabels;
    // A background refresh (resume, time-zone change, periodic check) keeps
    // showing the current times instead of flashing a spinner, and keeps
    // them if the refresh itself fails.
    final quiet = silent && _status == PrayerLoadStatus.loaded;
    if (!quiet) {
      _status = PrayerLoadStatus.loadingLocation;
      notifyListeners();
    }
    try {
      await _restoreCachedPlace();
      final position = await _repo.getCurrentPosition();
      _lastLocationCheck = DateTime.now();
      final moved =
          _latitude == null ||
          Geolocator.distanceBetween(
                _latitude!,
                _longitude!,
                position.latitude,
                position.longitude,
              ) >
              _kSignificantMoveMeters;
      _latitude = position.latitude;
      _longitude = position.longitude;

      if (!quiet) {
        _status = PrayerLoadStatus.loadingData;
        notifyListeners();
      }

      await _updatePlace(force: moved);
      await _recompute();
      _status = PrayerLoadStatus.loaded;
      _startTicker();
    } on LocationPermissionDeniedForeverException {
      if (!quiet) _status = PrayerLoadStatus.permissionDeniedForever;
    } on LocationPermissionDeniedException {
      if (!quiet) _status = PrayerLoadStatus.permissionDenied;
    } on LocationServiceDisabledException {
      if (!quiet) _status = PrayerLoadStatus.serviceDisabled;
    } on TimeoutException {
      if (!quiet) _status = PrayerLoadStatus.timedOut;
    } catch (e) {
      if (!quiet) {
        _errorMessage = e.toString();
        _status = PrayerLoadStatus.error;
      }
    } finally {
      _loading = false;
    }
    notifyListeners();
  }

  /// Re-geocodes the place name in the current app language (e.g. after
  /// switching between Arabic and English) without re-fetching location.
  Future<void> refreshPlaceName({required bool arabic}) async {
    final lang = arabic ? 'ar' : 'en';
    // Called from build; one attempt per language, so an offline geocoder
    // failure can't turn into a rebuild/retry loop.
    if (_latitude == null || _placeLangAttempted == lang) return;
    _placeLangAttempted = lang;
    _arabic = arabic;
    await _updatePlace(force: true);
    notifyListeners();
  }

  String? _placeLangAttempted;

  Future<void> _restoreCachedPlace() async {
    if (_placeName != null) return;
    final prefs = await SharedPreferences.getInstance();
    _countryCode = prefs.getString(_kCountryCode);
    final cachedLat = prefs.getDouble(_kPlaceLat);
    final cachedLng = prefs.getDouble(_kPlaceLng);
    if (cachedLat != null && cachedLng != null) {
      final cached = prefs.getString(_kPlaceName);
      // Names cached by an earlier version still carry "محافظة" etc.
      _placeName = cached == null
          ? null
          : PrayerRepository.cleanPlaceName(cached);
      _placeLang = prefs.getString(_kPlaceLang);
      _latitude ??= cachedLat;
      _longitude ??= cachedLng;
    }
  }

  Future<void> _updatePlace({required bool force}) async {
    final lang = _arabic ? 'ar' : 'en';
    if (!force && _placeName != null && _placeLang == lang) return;
    final result = await _repo.reverseGeocode(_latitude!, _longitude!, lang);
    if (result == null) return; // offline: keep the cached name/country
    _placeName = result.place;
    _placeLang = lang;
    _countryCode = result.countryCode ?? _countryCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPlaceName, result.place);
    await prefs.setString(_kPlaceLang, lang);
    await prefs.setDouble(_kPlaceLat, _latitude!);
    await prefs.setDouble(_kPlaceLng, _longitude!);
    if (_countryCode != null) {
      await prefs.setString(_kCountryCode, _countryCode!);
    }
  }

  /// Recomputes today's times for the current location / day / time zone
  /// and reschedules everything that depends on them.
  Future<void> _recompute() async {
    final now = DateTime.now();
    _times = _repo.getPrayerTimes(
      _latitude!,
      _longitude!,
      countryCode: _countryCode,
    );
    _qiblaDirection = _repo.getQiblaDirection(_latitude!, _longitude!);
    _computedForDay = DateTime(now.year, now.month, now.day);
    _computedForOffset = now.timeZoneOffset;

    if (kIsWeb) return;
    await PrayerWidget.update(
      times: _times!.obligatoryPrayers,
      arabic: _arabic,
    );
    if (await AthanSettings.isEnabled()) {
      final athan = await AthanSettings.getReciter();
      await NotificationService.schedulePrayerAthans(
        times: _times!.obligatoryPrayers,
        athan: athan,
        arabic: _arabic,
      );
    }
    if (await AthkarPrayerReminderSettings.isEnabled()) {
      await NotificationService.scheduleAthkarPrayerReminders(
        times: _times!.obligatoryPrayers,
        arabic: _arabic,
      );
    }
  }

  void _startTicker() {
    _ticker ??= Timer.periodic(const Duration(minutes: 1), (_) => _tick());
  }

  Future<void> _tick() async {
    if (_status != PrayerLoadStatus.loaded || _latitude == null) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (today != _computedForDay || now.timeZoneOffset != _computedForOffset) {
      // New day or new time zone: same place, so no location fetch needed.
      await _recompute();
      notifyListeners();
      return;
    }
    final lastCheck = _lastLocationCheck;
    if (lastCheck == null ||
        now.difference(lastCheck) > const Duration(minutes: 15)) {
      await load(arabicAthanLabels: _arabic, silent: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _status == PrayerLoadStatus.loaded) {
      // Coming back to the app is when travel / time-zone changes show up.
      load(arabicAthanLabels: _arabic, silent: true);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

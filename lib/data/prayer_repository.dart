import 'dart:async';
import 'package:adhan/adhan.dart' as adhan;
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:geolocator/geolocator.dart';
import '../models/prayer_times.dart';

/// Location permission was denied for this request, but the user can still
/// be re-prompted (e.g. via [PrayerRepository.getCurrentPosition] again).
class LocationPermissionDeniedException implements Exception {}

/// Location permission was permanently denied ("don't ask again" / iOS
/// "Never"). Re-requesting from within the app is a no-op on most
/// platforms — the user must enable it from system settings instead.
class LocationPermissionDeniedForeverException implements Exception {}

/// The device's location service (GPS) is turned off entirely.
class LocationServiceDisabledException implements Exception {}

const _kLocationTimeout = Duration(seconds: 20);

class PrayerRepository {
  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// On Android, force geolocator to use the platform [LocationManager]
  /// rather than the default fused provider (Google Play Services). The
  /// fused provider silently fails to return a fix on devices/emulators
  /// where Play Services is missing or misbehaving — the most common cause
  /// of "location doesn't work at all" — so going straight to the OS
  /// LocationManager is far more reliable.
  static LocationSettings get _locationSettings {
    if (_isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.medium,
        forceLocationManager: true,
        timeLimit: _kLocationTimeout,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.medium,
      timeLimit: _kLocationTimeout,
    );
  }

  Future<Position> getCurrentPosition() async {
    await _ensurePermission();
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationServiceDisabledException();
    }

    // A recent cached fix is plenty for prayer times/qibla and is instant —
    // it skips both the wait for a fresh GPS lock and the fused-provider
    // failures above. Use it whenever one exists.
    try {
      final last = await Geolocator.getLastKnownPosition(
        forceAndroidLocationManager: _isAndroid,
      );
      if (last != null) return last;
    } catch (_) {
      // getLastKnownPosition is best-effort; fall through to a live fix.
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: _locationSettings,
      );
    } on TimeoutException {
      throw TimeoutException('Location request timed out');
    }
  }

  Future<void> _ensurePermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      throw LocationPermissionDeniedForeverException();
    }
    if (perm != LocationPermission.always &&
        perm != LocationPermission.whileInUse) {
      throw LocationPermissionDeniedException();
    }
  }

  /// Computes today's prayer times locally with the Umm al-Qura method
  /// (the same `method=4` the app previously requested from the aladhan API)
  /// so prayer times work fully offline and never depend on a network call
  /// that can fail. Returns "HH:mm" strings in the device's local time.
  PrayerTimes getPrayerTimes(double lat, double lng) {
    final params = adhan.CalculationMethod.umm_al_qura.getParameters()
      ..madhab = adhan.Madhab.shafi;
    final times = adhan.PrayerTimes(
      adhan.Coordinates(lat, lng),
      adhan.DateComponents.from(DateTime.now()),
      params,
      utcOffset: DateTime.now().timeZoneOffset,
    );
    String fmt(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return PrayerTimes(
      fajr: fmt(times.fajr),
      sunrise: fmt(times.sunrise),
      dhuhr: fmt(times.dhuhr),
      asr: fmt(times.asr),
      maghrib: fmt(times.maghrib),
      isha: fmt(times.isha),
    );
  }

  /// Qibla direction (degrees clockwise from true north), computed locally
  /// from the great-circle bearing to the Kaaba — no network required.
  double getQiblaDirection(double lat, double lng) {
    return adhan.Qibla(adhan.Coordinates(lat, lng)).direction;
  }
}

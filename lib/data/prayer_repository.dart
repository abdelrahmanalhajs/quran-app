import 'dart:async';
import 'package:adhan/adhan.dart' as adhan;
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/widgets.dart' show Locale;
import 'package:geocoding/geocoding.dart';
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

/// How old a cached location fix may be and still be used as-is.
const _kFreshFixMaxAge = Duration(minutes: 15);

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

    // A cached fix is instant and skips the wait for a GPS lock, but it can
    // be arbitrarily old — e.g. from before the user travelled to another
    // city — which made prayer times silently belong to the wrong place.
    // Only trust it if it's recent; otherwise get a live fix, and fall back
    // to the stale cached one only if a live fix can't be had at all.
    Position? last;
    try {
      last = await Geolocator.getLastKnownPosition(
        forceAndroidLocationManager: _isAndroid,
      );
      if (last != null &&
          DateTime.now().difference(last.timestamp) < _kFreshFixMaxAge) {
        return last;
      }
    } catch (_) {
      // getLastKnownPosition is best-effort; fall through to a live fix.
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: _locationSettings,
      );
    } on TimeoutException {
      if (last != null) return last;
      throw TimeoutException('Location request timed out');
    } catch (_) {
      if (last != null) return last;
      rethrow;
    }
  }

  /// The governorate / state / province of [lat],[lng] (e.g. "Cairo
  /// Governorate" / "محافظة القاهرة") plus its ISO country code, in the
  /// requested [languageCode], via the OS's own geocoder (no API key). Null
  /// when the geocoder is unavailable or offline — callers fall back to a
  /// cached value.
  Future<({String place, String? countryCode})?> reverseGeocode(
    double lat,
    double lng,
    String languageCode,
  ) async {
    try {
      final marks = await Geocoding(
        locale: Locale(languageCode),
      ).placemarkFromCoordinates(lat, lng).timeout(const Duration(seconds: 10));
      if (marks.isEmpty) return null;
      final m = marks.first;
      String? pick(String? s) => (s == null || s.trim().isEmpty) ? null : s;
      final raw =
          pick(m.administrativeArea) ??
          pick(m.subAdministrativeArea) ??
          pick(m.locality) ??
          pick(m.country);
      if (raw == null) return null;
      final place = cleanPlaceName(raw);
      return (place: place, countryCode: pick(m.isoCountryCode)?.toUpperCase());
    } catch (_) {
      return null;
    }
  }

  /// Reduces a geocoder's administrative-area name to just the place
  /// itself: "محافظة القاهرة" → "القاهرة", "منطقة الرياض" → "الرياض",
  /// "Cairo Governorate" → "Cairo", "Riyadh Province" → "Riyadh".
  static String cleanPlaceName(String name) {
    var s = name.trim();
    final arPrefix = RegExp(
      r'^(محافظة|منطقة|ولاية|إمارة|امارة|مقاطعة|إقليم|اقليم|لواء|قضاء|مدينة)\s+',
    );
    final enPrefix = RegExp(
      r'^(Governorate|Province|Region|State|Emirate|Prefecture|Wilayat|Muhafazat)\s+of\s+',
      caseSensitive: false,
    );
    final enSuffix = RegExp(
      r'\s+(Governorate|Province|Region|State|Emirate|Prefecture|Municipality|District|Division|Capital Governorate)$',
      caseSensitive: false,
    );
    s = s.replaceFirst(arPrefix, '');
    s = s.replaceFirst(enPrefix, '');
    s = s.replaceFirst(enSuffix, '');
    s = s.trim();
    return s.isEmpty ? name.trim() : s;
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

  /// Computes today's prayer times locally (fully offline) with the
  /// calculation method that country's own religious authority uses — see
  /// [_paramsFor]. Returns "HH:mm" strings in the device's local time zone.
  PrayerTimes getPrayerTimes(double lat, double lng, {String? countryCode}) {
    final now = DateTime.now();
    final times = adhan.PrayerTimes(
      adhan.Coordinates(lat, lng),
      adhan.DateComponents.from(now),
      _paramsFor(countryCode, lat, lng),
      utcOffset: now.timeZoneOffset,
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

  /// The app used to apply Umm al-Qura to everyone, which is only correct in
  /// Saudi Arabia: its Isha is a fixed 90 minutes after Maghrib, so e.g. in
  /// Egypt Isha came out noticeably off from the official (twilight-angle)
  /// time. Pick the method each country's authority actually publishes,
  /// with Muslim World League as the international default. Hanafi Asr for
  /// the regions that follow it.
  adhan.CalculationParameters _paramsFor(
    String? countryCode,
    double lat,
    double lng,
  ) {
    final cc = countryCode ?? _guessCountryFromCoordinates(lat, lng);
    final method = switch (cc) {
      'SA' || 'YE' => adhan.CalculationMethod.umm_al_qura,
      'EG' ||
      'SD' ||
      'LY' ||
      'SY' ||
      'LB' ||
      'IQ' ||
      'JO' ||
      'PS' => adhan.CalculationMethod.egyptian,
      'AE' => adhan.CalculationMethod.dubai,
      'QA' || 'BH' || 'OM' => adhan.CalculationMethod.qatar,
      'KW' => adhan.CalculationMethod.kuwait,
      'PK' || 'IN' || 'BD' || 'AF' => adhan.CalculationMethod.karachi,
      'TR' => adhan.CalculationMethod.turkey,
      'IR' => adhan.CalculationMethod.tehran,
      'SG' || 'MY' || 'ID' || 'BN' => adhan.CalculationMethod.singapore,
      'US' || 'CA' => adhan.CalculationMethod.north_america,
      _ => adhan.CalculationMethod.muslim_world_league,
    };
    final hanafi = const {'PK', 'IN', 'BD', 'AF', 'TR'}.contains(cc);
    return method.getParameters()
      ..madhab = hanafi ? adhan.Madhab.hanafi : adhan.Madhab.shafi;
  }

  /// Offline fallback for when the geocoder couldn't name the country yet
  /// (first run with no network): rough boxes for the countries most
  /// likely to use this app, so the right method still applies.
  String? _guessCountryFromCoordinates(double lat, double lng) {
    bool inBox(double s, double n, double w, double e) =>
        lat >= s && lat <= n && lng >= w && lng <= e;
    if (inBox(22, 31.7, 24.7, 36.9)) return 'EG';
    if (inBox(16.3, 32.2, 34.5, 55.7)) return 'SA';
    if (inBox(22.6, 26.1, 51.5, 56.4)) return 'AE';
    return null;
  }

  /// Qibla direction (degrees clockwise from true north), computed locally
  /// from the great-circle bearing to the Kaaba — no network required.
  double getQiblaDirection(double lat, double lng) {
    return adhan.Qibla(adhan.Coordinates(lat, lng)).direction;
  }
}

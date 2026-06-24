import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../core/constants/api_constants.dart';
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

const _kHttpTimeout = Duration(seconds: 15);
const _kLocationTimeout = Duration(seconds: 20);

class PrayerRepository {
  Future<Position> getCurrentPosition() async {
    await _ensurePermission();
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationServiceDisabledException();
    }
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: _kLocationTimeout,
        ),
      );
    } on TimeoutException {
      // geolocator's own TimeoutException doesn't carry a useful message;
      // a fresh, explicit one keeps the UI's error text meaningful.
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

  Future<PrayerTimes> getPrayerTimes(double lat, double lng) async {
    final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round();
    final uri = Uri.parse(
      '${ApiConstants.prayerBase}/timings/$timestamp?latitude=$lat&longitude=$lng&method=4',
    );
    final res = await http.get(uri).timeout(_kHttpTimeout);
    if (res.statusCode != 200) {
      throw Exception('Failed to load prayer times (HTTP ${res.statusCode})');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return PrayerTimes.fromJson(
      body['data']['timings'] as Map<String, dynamic>,
    );
  }

  Future<double> getQiblaDirection(double lat, double lng) async {
    final uri = Uri.parse('${ApiConstants.prayerBase}/qibla/$lat/$lng');
    final res = await http.get(uri).timeout(_kHttpTimeout);
    if (res.statusCode != 200) {
      throw Exception(
        'Failed to load qibla direction (HTTP ${res.statusCode})',
      );
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['data']['direction'] as num).toDouble();
  }
}

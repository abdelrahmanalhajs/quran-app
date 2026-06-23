import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../core/constants/api_constants.dart';
import '../models/prayer_times.dart';

class PrayerRepository {
  Future<Position> getCurrentPosition() async {
    final permission = await _ensurePermission();
    if (!permission) {
      throw Exception('Location permission denied');
    }
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services disabled');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
    );
  }

  Future<bool> _ensurePermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always || perm == LocationPermission.whileInUse;
  }

  Future<PrayerTimes> getPrayerTimes(double lat, double lng) async {
    final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round();
    final uri = Uri.parse(
      '${ApiConstants.prayerBase}/timings/$timestamp?latitude=$lat&longitude=$lng&method=4',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed to load prayer times');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return PrayerTimes.fromJson(body['data']['timings'] as Map<String, dynamic>);
  }

  Future<double> getQiblaDirection(double lat, double lng) async {
    final uri = Uri.parse('${ApiConstants.prayerBase}/qibla/$lat/$lng');
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed to load qibla direction');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['data']['direction'] as num).toDouble();
  }
}

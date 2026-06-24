import 'dart:async';
import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../state/prayer_provider.dart';
import '../../widgets/responsive_center.dart';

class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrayerProvider>().load(
        arabicAthanLabels: context.locale.languageCode == 'ar',
      );
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('prayer.title'.tr()),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'prayer.times'.tr()),
            Tab(text: 'prayer.qibla'.tr()),
          ],
        ),
      ),
      body: ResponsiveCenter(
        child: TabBarView(
          controller: _tabController,
          children: const [_PrayerTimesTab(), _QiblaTab()],
        ),
      ),
    );
  }
}

/// Shared status UI for every non-`loaded` [PrayerLoadStatus] — both the
/// prayer-times tab and the qibla tab show the exact same set of states
/// (fetching location, permission issues, service disabled, timeout,
/// generic error), so this is built once and reused by both.
Widget? buildPrayerStatusScreen(BuildContext context, PrayerProvider provider) {
  void reload() => provider.load(
        arabicAthanLabels: context.locale.languageCode == 'ar',
      );

  switch (provider.status) {
    case PrayerLoadStatus.idle:
    case PrayerLoadStatus.loadingLocation:
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text('prayer.fetching_location'.tr()),
          ],
        ),
      );
    case PrayerLoadStatus.loadingData:
      return const Center(child: CircularProgressIndicator());
    case PrayerLoadStatus.permissionDenied:
      return _StatusMessage(
        icon: Icons.location_off,
        message: 'prayer.location_permission'.tr(),
        buttonLabel: 'prayer.enable_location'.tr(),
        onButtonPressed: reload,
      );
    case PrayerLoadStatus.permissionDeniedForever:
      return _StatusMessage(
        icon: Icons.location_disabled,
        message: 'prayer.permission_denied_forever'.tr(),
        buttonLabel: 'prayer.open_settings'.tr(),
        onButtonPressed: Geolocator.openAppSettings,
      );
    case PrayerLoadStatus.serviceDisabled:
      return _StatusMessage(
        icon: Icons.location_disabled,
        message: 'prayer.service_disabled'.tr(),
        buttonLabel: 'prayer.open_location_settings'.tr(),
        onButtonPressed: Geolocator.openLocationSettings,
      );
    case PrayerLoadStatus.timedOut:
      return _StatusMessage(
        icon: Icons.location_searching,
        message: 'prayer.timed_out'.tr(),
        buttonLabel: 'prayer.retry'.tr(),
        onButtonPressed: reload,
      );
    case PrayerLoadStatus.error:
      return _StatusMessage(
        icon: Icons.error_outline,
        message: provider.errorMessage ?? 'prayer.error_generic'.tr(),
        buttonLabel: 'prayer.retry'.tr(),
        onButtonPressed: reload,
      );
    case PrayerLoadStatus.loaded:
      return null;
  }
}

class _StatusMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String buttonLabel;
  final VoidCallback onButtonPressed;

  const _StatusMessage({
    required this.icon,
    required this.message,
    required this.buttonLabel,
    required this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onButtonPressed, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}

class _PrayerTimesTab extends StatelessWidget {
  const _PrayerTimesTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrayerProvider>();
    final status = buildPrayerStatusScreen(context, provider);
    if (status != null) return status;

    final t = provider.times!;
    final entries = [
      ('prayer.fajr', t.fajr, Icons.dark_mode_outlined),
      ('prayer.sunrise', t.sunrise, Icons.wb_twilight),
      ('prayer.dhuhr', t.dhuhr, Icons.light_mode_outlined),
      ('prayer.asr', t.asr, Icons.sunny),
      ('prayer.maghrib', t.maghrib, Icons.nights_stay_outlined),
      ('prayer.isha', t.isha, Icons.bedtime_outlined),
    ];
    return RefreshIndicator(
      onRefresh: () => provider.load(
        arabicAthanLabels: context.locale.languageCode == 'ar',
      ),
      child: ListView.separated(
        padding: EdgeInsets.all(responsiveHorizontalPadding(context)),
        itemCount: entries.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final (key, time, icon) = entries[i];
          return Card(
            child: ListTile(
              leading: Icon(icon),
              title: Text(key.tr()),
              trailing: Text(
                time,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QiblaTab extends StatefulWidget {
  const _QiblaTab();

  @override
  State<_QiblaTab> createState() => _QiblaTabState();
}

class _QiblaTabState extends State<_QiblaTab> {
  static const double _alignmentThresholdDegrees = 8;
  double? _heading;
  // A device without a magnetometer (common on emulators, some tablets)
  // never emits a compass event with a non-null heading. There's no direct
  // "sensor unavailable" API, so absence is detected by waiting a few
  // seconds for a usable reading before falling back to the static
  // degrees-from-north display also used on web.
  bool _compassUnavailable = false;
  StreamSubscription<CompassEvent>? _compassSub;
  Timer? _compassTimeoutTimer;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _compassTimeoutTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && _heading == null) {
          setState(() => _compassUnavailable = true);
        }
      });
      _compassSub = FlutterCompass.events?.listen((event) {
        if (event.heading == null) return;
        _compassTimeoutTimer?.cancel();
        if (mounted) {
          setState(() {
            _heading = event.heading;
            _compassUnavailable = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    _compassTimeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrayerProvider>();
    final status = buildPrayerStatusScreen(context, provider);
    if (status != null) return status;

    final qibla = provider.qiblaDirection!;

    if (kIsWeb || _compassUnavailable) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off_outlined, size: 48),
              const SizedBox(height: 12),
              Text(
                kIsWeb
                    ? 'prayer.compass_unavailable_web'.tr()
                    : 'prayer.compass_unavailable_native'.tr(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'prayer.degrees_from_north'.tr(args: ['${qibla.round()}°']),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    final heading = _heading ?? 0;
    var diff = (qibla - heading) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    final aligned = diff.abs() <= _alignmentThresholdDegrees;

    final angle = diff * (math.pi / 180);
    final color =
        aligned ? Colors.green : Theme.of(context).colorScheme.primary;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        Text(
          aligned ? 'prayer.facing_qiblah'.tr() : 'prayer.qibla_hint'.tr(),
          textAlign: TextAlign.center,
          style: aligned
              ? Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                )
              : null,
        ),
        const SizedBox(height: 32),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
          ),
          padding: const EdgeInsets.all(20),
          child: Transform.rotate(
            angle: angle,
            child: Icon(Icons.navigation, size: 100, color: color),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'prayer.degrees_from_north'.tr(args: ['${qibla.round()}°']),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Spacer(),
      ],
    );
  }
}

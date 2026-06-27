import 'dart:async';
import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../state/navigation_provider.dart';
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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Requests location (and loads prayer times / qiblah) the first time the
  /// user actually opens this tab — not at app launch. The IndexedStack in
  /// HomeShell builds every tab up front, so loading in initState fired the
  /// system location prompt in the background before the user ever navigated
  /// here; gating it on the prayer tab being selected makes the permission
  /// pop-up appear in context, when they tap "Prayer".
  void _maybeLoadOnOpen() {
    final nav = context.read<HomeNavigationProvider>();
    final provider = context.read<PrayerProvider>();
    if (nav.index == 1 && provider.status == PrayerLoadStatus.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final p = context.read<PrayerProvider>();
        if (p.status == PrayerLoadStatus.idle) {
          p.load(arabicAthanLabels: context.locale.languageCode == 'ar');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds on tab change (prayer tab is index 1) so [_maybeLoadOnOpen]
    // fires the location request the moment this tab is opened.
    context.watch<HomeNavigationProvider>();
    _maybeLoadOnOpen();
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
  void reload() =>
      provider.load(arabicAthanLabels: context.locale.languageCode == 'ar');

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
    // Scrollable so a long error message (e.g. a raw platform exception
    // string) can never overflow the column and push the action button
    // off-screen — that's how "an error with no retry button" happened.
    return Center(
      child: SingleChildScrollView(
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
      onRefresh: () =>
          provider.load(arabicAthanLabels: context.locale.languageCode == 'ar'),
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
      // No magnetometer: a live "rotate to face" simulation isn't possible.
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
            ],
          ),
        ),
      );
    }

    final heading = _heading ?? 0;
    // How far (and which way) the Kaaba sits from where the phone is
    // currently pointing. 0 = the Kaaba is straight ahead (facing Qiblah).
    var diff = (qibla - heading) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    final aligned = diff.abs() <= _alignmentThresholdDegrees;
    final angle = diff * (math.pi / 180);
    final scheme = Theme.of(context).colorScheme;
    final accent = aligned ? Colors.green : scheme.primary;

    const dialSize = 300.0;
    const orbitRadius = 118.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        Text(
          aligned ? 'prayer.facing_qiblah'.tr() : 'prayer.qibla_rotate_hint'.tr(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: aligned ? Colors.green : null,
            fontWeight: aligned ? FontWeight.bold : null,
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: dialSize,
          height: dialSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The dial.
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: dialSize,
                height: dialSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: aligned
                      ? Colors.green.withValues(alpha: 0.12)
                      : scheme.surfaceContainerHighest,
                  border: Border.all(
                    color: accent.withValues(alpha: 0.6),
                    width: 2,
                  ),
                ),
              ),
              // Fixed marker at the top: the direction the phone is pointing.
              // When the Kaaba reaches it, the user faces the Qiblah.
              Positioned(
                top: 2,
                child: Icon(Icons.arrow_drop_down, color: accent, size: 40),
              ),
              // "You are here" at the centre.
              Icon(Icons.my_location, size: 18, color: scheme.outline),
              // The Kaaba, kept upright but orbited to the Qiblah bearing
              // relative to where the phone points. Rotate the phone until it
              // sits under the top marker.
              Transform.translate(
                offset: Offset(
                  orbitRadius * math.sin(angle),
                  -orbitRadius * math.cos(angle),
                ),
                child: _KaabaMarker(highlighted: aligned),
              ),
            ],
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

/// A small upright Kaaba (black cube with the gold kiswah band) used as the
/// Qiblah marker on the compass dial.
class _KaabaMarker extends StatelessWidget {
  final bool highlighted;

  const _KaabaMarker({required this.highlighted});

  @override
  Widget build(BuildContext context) {
    final border = highlighted ? Colors.green : Colors.amber.shade700;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border, width: 2),
            boxShadow: highlighted
                ? [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.5),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          // The gold band of the kiswah, sitting near the top of the cube.
          child: Align(
            alignment: const Alignment(0, -0.35),
            child: Container(height: 6, color: Colors.amber.shade600),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'prayer.kaaba'.tr(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: highlighted
                ? Colors.green
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

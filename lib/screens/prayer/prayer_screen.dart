import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'qada_view.dart';
import '../../core/islamic_calendar.dart';
import '../../core/arabic_numbers.dart';
import '../../core/responsive.dart';
import '../../state/navigation_provider.dart';
import '../../state/prayer_provider.dart';
import '../../widgets/responsive_center.dart';
import '../../core/plural_text.dart';

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
    _tabController = TabController(length: 3, vsync: this);
    // Reopen on whichever tab the user was last on (e.g. after picking this
    // section from the start menu), and remember each switch.
    SharedPreferences.getInstance().then((prefs) {
      final last = prefs.getInt('prayer_last_tab');
      if (mounted && last != null && last >= 0 && last < 3) {
        _tabController.index = last;
      }
    });
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setInt('prayer_last_tab', _tabController.index),
      );
    });
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
            Tab(text: 'prayer.qada'.tr()),
          ],
        ),
      ),
      body: ResponsiveCenter(
        child: TabBarView(
          controller: _tabController,
          children: const [_PrayerTimesTab(), _QiblaTab(), QadaView()],
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
    final lang = context.locale.languageCode;
    if (provider.placeName != null && provider.placeLanguage != lang) {
      // Language was switched since the name was looked up — fetch it again
      // in the current language.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => provider.refreshPlaceName(arabic: lang == 'ar'),
      );
    }
    // Read the theme here, in this widget's own build, rather than inside
    // the list's itemBuilder: the builder's context belongs to the list's
    // internal element, which doesn't rebuild its items when the theme
    // changes — so the times kept the old colour after a light/dark switch
    // until a manual refresh. Depending on the theme here rebuilds the whole
    // list with the new colours immediately.
    final theme = Theme.of(context);
    final timeStyle = theme.textTheme.titleMedium?.copyWith(
      color: theme.colorScheme.onSurface,
    );
    return RefreshIndicator(
      onRefresh: () =>
          provider.load(arabicAthanLabels: context.locale.languageCode == 'ar'),
      child: ListView.separated(
        padding: EdgeInsets.all(responsiveHorizontalPadding(context)),
        itemCount: entries.length + 2,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          if (i == entries.length) {
            return _LocationAndHijriDate(placeName: provider.placeName);
          }
          if (i == entries.length + 1) return const _UpcomingIslamicDays();
          final (key, time, icon) = entries[i];
          return Card(
            child: ListTile(
              leading: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
              title: Text(
                key.tr(),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              trailing: Text(time, style: timeStyle),
            ),
          );
        },
      ),
    );
  }
}

/// Shown in the space under the prayer times: the device's governorate and,
/// under it, today's Hijri date.
class _LocationAndHijriDate extends StatelessWidget {
  const _LocationAndHijriDate({required this.placeName});

  final String? placeName;

  @override
  Widget build(BuildContext context) {
    final arabic = context.locale.languageCode == 'ar';
    HijriCalendar.setLocal(arabic ? 'ar' : 'en');
    final h = HijriCalendar.now();
    final day = localizedNumber(context, h.hDay);
    final year = localizedNumber(context, h.hYear);
    final hijri = arabic
        ? '$day ${h.longMonthName} $year هـ'
        : '$day ${h.longMonthName} $year AH';
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 16),
      child: Column(
        children: [
          if (placeName != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    placeName!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          if (placeName != null) const SizedBox(height: 8),
          Text(
            hijri,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
  static const MethodChannel _declinationChannel = MethodChannel(
    'qibla/declination',
  );
  double? _heading;
  // Android's reported accuracy is unreliable (see [CompassEvent.accuracy]
  // docs) so this only ever makes the calibration hint more insistent, never
  // hides it — a figure-8 calibration is harmless to suggest even when the
  // heading is actually fine.
  double? _accuracy;
  // A device without a magnetometer (common on emulators, some tablets)
  // never emits a compass event with a non-null heading. There's no direct
  // "sensor unavailable" API, so absence is detected by waiting a few
  // seconds for a usable reading before falling back to the static
  // degrees-from-north display also used on web.
  bool _compassUnavailable = false;
  StreamSubscription<CompassEvent>? _compassSub;
  Timer? _compassTimeoutTimer;

  // flutter_compass's heading on Android is relative to MAGNETIC north (raw
  // rotation-vector sensor), while the qibla bearing is computed from TRUE
  // north — so without correction the needle is off by the local magnetic
  // declination (can be 15-20°+ depending on where the user is, which is why
  // the bug only showed up "sometimes"). iOS already reports trueHeading via
  // CoreLocation, so this stays 0 there. Fetched once per session via
  // MainActivity's GeomagneticField-backed channel.
  double _declination = 0;
  bool _declinationRequested = false;

  Future<void> _maybeFetchDeclination() async {
    if (_declinationRequested || kIsWeb || !Platform.isAndroid) return;
    final provider = context.read<PrayerProvider>();
    final lat = provider.latitude;
    final lng = provider.longitude;
    if (lat == null || lng == null) return;
    _declinationRequested = true;
    try {
      final result = await _declinationChannel.invokeMethod<double>(
        'declination',
        {'lat': lat, 'lng': lng},
      );
      if (mounted && result != null) {
        setState(() => _declination = result);
      }
    } catch (_) {
      // Leave declination at 0 if the channel isn't available for any
      // reason — better an uncorrected heading than a crash.
    }
  }

  // Smooths out magnetometer jitter (a raw heading can jump several degrees
  // between consecutive sensor events) with an exponential moving average,
  // taking the shortest signed angular delta so it doesn't glitch across the
  // 0/360 boundary.
  double _smoothHeading(double previous, double next) {
    final delta = (next - previous + 540) % 360 - 180;
    return (previous + 0.15 * delta + 360) % 360;
  }

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
        _maybeFetchDeclination();
        final corrected = (event.heading! + _declination) % 360;
        final next = _heading == null
            ? corrected
            : _smoothHeading(_heading!, corrected);
        if (mounted) {
          setState(() {
            _heading = next;
            _accuracy = event.accuracy;
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
    final color = aligned
        ? Colors.green
        : Theme.of(context).colorScheme.primary;
    final lowAccuracy = _accuracy != null && _accuracy! > 15;

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
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.threesixty_outlined,
                size: 16,
                color: lowAccuracy
                    ? Colors.amber.shade800
                    : Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  lowAccuracy
                      ? 'prayer.calibration_hint_low_accuracy'.tr()
                      : 'prayer.calibration_hint'.tr(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: lowAccuracy
                        ? Colors.amber.shade800
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

/// The coming Islamic occasions (Ramadan, the two Eids, Arafah, Ashura, the
/// Hijri new year) and Sunnah fast days, each with how far away it is.
class _UpcomingIslamicDays extends StatelessWidget {
  const _UpcomingIslamicDays();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.locale.languageCode;
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    final events = upcomingIslamicEvents();

    String when(IslamicEvent e) {
      if (!todayDay.isBefore(e.date) && !todayDay.isAfter(e.endDate)) {
        return 'prayer.today'.tr();
      }
      final days = e.date.difference(todayDay).inDays;
      if (days == 1) return 'prayer.tomorrow'.tr();
      return 'prayer.in_days'.tr(args: [daysText(context, days)]);
    }

    String hijriLabel(DateTime d) {
      HijriCalendar.setLocal(locale == 'ar' ? 'ar' : 'en');
      final h = HijriCalendar.fromDate(d);
      return '${localizedNumber(context, h.hDay)} ${h.longMonthName}';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'prayer.upcoming_days'.tr(),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            for (final e in events)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  e.isFast ? Icons.nights_stay_outlined : Icons.event_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: Text('prayer.${e.key}'.tr()),
                subtitle: Text(
                  '${hijriLabel(e.date)} · '
                  '${_gregorianLabel(context, e.date)}'
                  '${e.isFast ? ' · ${'prayer.sunnah_fast'.tr()}' : ''}',
                ),
                trailing: Text(
                  when(e),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'prayer.dates_note'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _kMonthsAr = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];
const _kMonthsEn = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "12 Mar" / "١٢ مارس" without needing intl's locale date data.
String _gregorianLabel(BuildContext context, DateTime d) {
  final ar = context.locale.languageCode == 'ar';
  return '${localizedNumber(context, d.day)} '
      '${(ar ? _kMonthsAr : _kMonthsEn)[d.month - 1]}';
}

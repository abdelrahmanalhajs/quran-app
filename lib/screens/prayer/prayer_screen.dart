import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:provider/provider.dart';
import '../../state/prayer_provider.dart';

class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrayerProvider>().load();
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
            Tab(text: 'prayer.title'.tr()),
            Tab(text: 'prayer.qibla'.tr()),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _PrayerTimesTab(),
          _QiblaTab(),
        ],
      ),
    );
  }
}

class _PrayerTimesTab extends StatelessWidget {
  const _PrayerTimesTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrayerProvider>();

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
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_off, size: 48),
                const SizedBox(height: 12),
                Text('prayer.location_permission'.tr(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => provider.load(),
                  child: Text('prayer.enable_location'.tr()),
                ),
              ],
            ),
          ),
        );
      case PrayerLoadStatus.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(provider.errorMessage ?? 'Error'),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => provider.load(), child: const Icon(Icons.refresh)),
            ],
          ),
        );
      case PrayerLoadStatus.loaded:
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
          onRefresh: provider.load,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final (key, time, icon) = entries[i];
              return Card(
                child: ListTile(
                  leading: Icon(icon),
                  title: Text(key.tr()),
                  trailing: Text(time, style: Theme.of(context).textTheme.titleMedium),
                ),
              );
            },
          ),
        );
    }
  }
}

class _QiblaTab extends StatefulWidget {
  const _QiblaTab();

  @override
  State<_QiblaTab> createState() => _QiblaTabState();
}

class _QiblaTabState extends State<_QiblaTab> {
  double? _heading;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrayerProvider>();

    if (provider.status != PrayerLoadStatus.loaded || provider.qiblaDirection == null) {
      return Center(
        child: provider.status == PrayerLoadStatus.permissionDenied
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text('prayer.location_permission'.tr(), textAlign: TextAlign.center),
              )
            : const CircularProgressIndicator(),
      );
    }

    final qibla = provider.qiblaDirection!;

    return StreamBuilder<CompassEvent>(
      stream: FlutterCompass.events,
      builder: (context, snapshot) {
        final heading = snapshot.data?.heading ?? _heading ?? 0;
        _heading = heading;
        final angle = (qibla - heading) * (math.pi / 180);

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Text('prayer.qibla_hint'.tr(), textAlign: TextAlign.center),
            const SizedBox(height: 32),
            Transform.rotate(
              angle: angle,
              child: Icon(
                Icons.navigation,
                size: 140,
                color: Theme.of(context).colorScheme.primary,
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
      },
    );
  }
}

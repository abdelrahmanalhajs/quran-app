import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import '../../core/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../data/athkar_repository.dart';
import '../../models/thikr.dart';
import '../../widgets/responsive_center.dart';

class AthkarScreen extends StatefulWidget {
  const AthkarScreen({super.key});

  @override
  State<AthkarScreen> createState() => _AthkarScreenState();
}

class _AthkarScreenState extends State<AthkarScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final AthkarRepository _repo = AthkarRepository();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
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
        title: Text('athkar.title'.tr()),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          // Material 3's default for scrollable tabs (TabAlignment.startOffset)
          // insets the first tab ~52px from the edge instead of hugging it,
          // which reads as "not aligned" — TabAlignment.start hugs the true
          // leading edge instead, flipping correctly with text direction
          // (left in English, right in Arabic) since "start" is direction-aware.
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'athkar.morning'.tr()),
            Tab(text: 'athkar.evening'.tr()),
            Tab(text: 'athkar.after_prayer'.tr()),
            Tab(text: 'athkar.jumaa'.tr()),
            Tab(text: 'athkar.sleep'.tr()),
            Tab(text: 'athkar.general'.tr()),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AthkarList(future: _repo.getMorningAthkar()),
          _AthkarList(future: _repo.getEveningAthkar()),
          _AthkarList(future: _repo.getAfterPrayerAthkar()),
          _AthkarList(future: _repo.getJumaaAthkar()),
          _AthkarList(future: _repo.getSleepAthkar()),
          _AthkarList(future: _repo.getGeneralDuaa(), classified: true),
        ],
      ),
    );
  }
}

class _AthkarList extends StatelessWidget {
  final Future<List<Thikr>> future;
  final bool classified;

  const _AthkarList({required this.future, this.classified = false});

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    return FutureBuilder<List<Thikr>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (!classified) {
          return ResponsiveCenter(
            child: ListView.separated(
              padding: EdgeInsets.all(responsiveHorizontalPadding(context)),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _ThikrCard(thikr: items[index]),
            ),
          );
        }

        // Build a flat list of section-header / item widgets grouped by
        // category, preserving the order categories first appear in.
        final widgets = <Widget>[];
        String? lastCategory;
        for (final item in items) {
          final category = isArabic ? item.categoryAr : item.categoryEn;
          if (category != null && category != lastCategory) {
            if (lastCategory != null) widgets.add(const SizedBox(height: 6));
            widgets.add(_CategoryHeader(title: category));
            lastCategory = category;
          }
          widgets.add(Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ThikrCard(thikr: item),
          ));
        }
        return ResponsiveCenter(
          child: ListView(
            padding: EdgeInsets.all(responsiveHorizontalPadding(context)),
            children: widgets,
          ),
        );
      },
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  final String title;

  const _CategoryHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        textAlign: isArabic ? TextAlign.right : TextAlign.left,
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _ThikrCard extends StatefulWidget {
  final Thikr thikr;

  const _ThikrCard({required this.thikr});

  @override
  State<_ThikrCard> createState() => _ThikrCardState();
}

class _ThikrCardState extends State<_ThikrCard> {
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    _remaining = widget.thikr.repeat;
  }

  @override
  Widget build(BuildContext context) {
    final done = _remaining <= 0;
    final isArabic = context.locale.languageCode == 'ar';
    final isSunnah = widget.thikr.isSunnah;
    return Card(
      color: done && !isSunnah
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isSunnah
            ? null
            : () {
                if (_remaining > 0) {
                  setState(() => _remaining--);
                }
              },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.thikr.ar,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: AppTheme.athkarTextStyle(context),
              ),
              if (!isArabic) ...[
                const SizedBox(height: 10),
                Text(
                  widget.thikr.en,
                  textAlign: TextAlign.left,
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    isSunnah
                        ? Icons.star_outline
                        : (done ? Icons.check_circle : Icons.touch_app_outlined),
                    size: 18,
                    color: isSunnah
                        ? Theme.of(context).colorScheme.primary
                        : (done ? Colors.green : null),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isSunnah
                        ? 'athkar.sunnah'.tr()
                        : (done
                            ? 'athkar.repeat'.tr()
                            : '${'athkar.tap_to_count'.tr()} ($_remaining/${widget.thikr.repeat})'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

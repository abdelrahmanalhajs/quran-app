import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import '../../core/responsive.dart';
import '../../data/hadith_repository.dart';
import '../../models/hadith.dart';
import '../../widgets/responsive_center.dart';

class HadithScreen extends StatefulWidget {
  const HadithScreen({super.key});

  @override
  State<HadithScreen> createState() => _HadithScreenState();
}

class _HadithScreenState extends State<HadithScreen> {
  final HadithRepository _repo = HadithRepository();
  late Future<Hadith> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.getTodayHadith();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('hadith.title'.tr())),
      body: FutureBuilder<Hadith>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final h = snapshot.data!;
          final isArabic = context.locale.languageCode == 'ar';
          return ResponsiveCenter(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(responsiveHorizontalPadding(context) + 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'hadith.today'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            h.ar,
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(height: 1.8),
                          ),
                          if (!isArabic) ...[
                            const Divider(height: 28),
                            Text(
                              h.en,
                              textAlign: TextAlign.left,
                              textDirection: TextDirection.ltr,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.menu_book_outlined, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                '${'hadith.source'.tr()}: ${isArabic ? h.sourceAr : h.source}',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

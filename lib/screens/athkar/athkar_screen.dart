import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import '../../data/athkar_repository.dart';
import '../../models/thikr.dart';

class AthkarScreen extends StatefulWidget {
  const AthkarScreen({super.key});

  @override
  State<AthkarScreen> createState() => _AthkarScreenState();
}

class _AthkarScreenState extends State<AthkarScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final AthkarRepository _repo = AthkarRepository();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('athkar.title'.tr()),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'athkar.morning'.tr()),
            Tab(text: 'athkar.evening'.tr()),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AthkarList(future: _repo.getMorningAthkar()),
          _AthkarList(future: _repo.getEveningAthkar()),
        ],
      ),
    );
  }
}

class _AthkarList extends StatelessWidget {
  final Future<List<Thikr>> future;

  const _AthkarList({required this.future});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Thikr>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _ThikrCard(thikr: items[index]),
        );
      },
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
    return Card(
      color: done ? Theme.of(context).colorScheme.surfaceContainerHighest : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.7),
              ),
              const SizedBox(height: 10),
              Text(
                widget.thikr.en,
                textAlign: TextAlign.left,
                textDirection: TextDirection.ltr,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    done ? Icons.check_circle : Icons.touch_app_outlined,
                    size: 18,
                    color: done ? Colors.green : null,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    done
                        ? 'athkar.repeat'.tr()
                        : '${'athkar.tap_to_count'.tr()} ($_remaining/${widget.thikr.repeat})',
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

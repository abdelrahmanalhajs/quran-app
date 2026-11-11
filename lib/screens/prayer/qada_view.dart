import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/arabic_numbers.dart';

/// Missed (qada) prayers tracker: a running count of prayers still owed for
/// each of the five daily prayers. "+" adds a missed prayer, "−" (or
/// "Prayed one") records one made up. Stored on the device only.
class QadaView extends StatefulWidget {
  const QadaView({super.key});

  @override
  State<QadaView> createState() => _QadaViewState();
}

class _QadaViewState extends State<QadaView> {
  static const _keys = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
  static String _prefKey(String k) => 'qada_$k';
  static const _kMadeUp = 'qada_made_up_total';

  final Map<String, int> _counts = {for (final k in _keys) k: 0};
  int _madeUp = 0;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        for (final k in _keys) {
          _counts[k] = prefs.getInt(_prefKey(k)) ?? 0;
        }
        _madeUp = prefs.getInt(_kMadeUp) ?? 0;
      });
    });
  }

  void _change(String key, int delta) {
    final next = (_counts[key]! + delta).clamp(0, 99999);
    if (next == _counts[key]) return;
    setState(() {
      if (delta < 0) _madeUp += _counts[key]! - next;
      _counts[key] = next;
    });
    HapticFeedback.selectionClick();
    _prefs?.setInt(_prefKey(key), next);
    _prefs?.setInt(_kMadeUp, _madeUp);
  }

  Future<void> _setExact(String key, String label) async {
    final controller = TextEditingController(text: '${_counts[key]}');
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: 'prayer.qada_owed'.tr()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('prayer.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              ctx,
            ).pop(int.tryParse(westernDigits(controller.text.trim()))),
            child: Text('prayer.save'.tr()),
          ),
        ],
      ),
    );
    if (value == null) return;
    setState(() => _counts[key] = value.clamp(0, 99999));
    _prefs?.setInt(_prefKey(key), _counts[key]!);
  }

  @override
  Widget build(BuildContext context) {
    final total = _counts.values.fold<int>(0, (a, b) => a + b);
    final scheme = Theme.of(context).colorScheme;
    String n(int v) => localizedNumber(context, v);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: scheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'prayer.qada_total'.tr(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  n(total),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_madeUp > 0)
                  Text(
                    '${'prayer.qada_made_up'.tr()}: ${n(_madeUp)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final k in _keys)
          Card(
            child: ListTile(
              title: Text('prayer.$k'.tr()),
              subtitle: Text('${'prayer.qada_owed'.tr()}: ${n(_counts[k]!)}'),
              onLongPress: () => _setExact(k, 'prayer.$k'.tr()),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'prayer.qada_prayed_one'.tr(),
                    icon: const Icon(Icons.remove),
                    onPressed: _counts[k]! > 0 ? () => _change(k, -1) : null,
                  ),
                  const SizedBox(width: 4),
                  IconButton.filledTonal(
                    tooltip: 'prayer.qada_add_missed'.tr(),
                    icon: const Icon(Icons.add),
                    onPressed: () => _change(k, 1),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'prayer.qada_hint'.tr(),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.outline),
        ),
      ],
    );
  }
}

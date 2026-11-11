import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/arabic_numbers.dart';
import '../../core/theme/app_theme.dart';

/// One dhikr the counter can be set to.
class _Dhikr {
  final String ar;
  final String en;
  const _Dhikr(this.ar, this.en);
}

const _kDhikrs = [
  _Dhikr('سُبْحَانَ اللَّهِ', 'SubhanAllah (Glory be to Allah)'),
  _Dhikr('الْحَمْدُ لِلَّهِ', 'Alhamdulillah (All praise is for Allah)'),
  _Dhikr('اللَّهُ أَكْبَرُ', 'Allahu Akbar (Allah is the Greatest)'),
  _Dhikr('لَا إِلَهَ إِلَّا اللَّهُ', 'La ilaha illa Allah'),
  _Dhikr(
    'أَسْتَغْفِرُ اللَّهَ',
    'Astaghfirullah (I seek Allah\'s forgiveness)',
  ),
  _Dhikr('سُبْحَانَ اللَّهِ وَبِحَمْدِهِ', 'SubhanAllahi wa bihamdihi'),
  _Dhikr(
    'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
    'La hawla wa la quwwata illa billah',
  ),
  _Dhikr('اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ', 'Salawat upon the Prophet ﷺ'),
];

/// Target choices; 0 means "no target" (count freely).
const _kTargets = [33, 34, 99, 100, 1000, 0];

/// A digital tasbih: tap the circle to count, pick the dhikr and a target,
/// feel a vibration each time the target is reached, and keep each dhikr's
/// running and all-time totals across app launches.
class TasbihView extends StatefulWidget {
  const TasbihView({super.key});

  @override
  State<TasbihView> createState() => _TasbihViewState();
}

class _TasbihViewState extends State<TasbihView> {
  static const _kSelected = 'tasbih_selected';
  static const _kTarget = 'tasbih_target';
  static String _countKey(int i) => 'tasbih_count_$i';
  static String _totalKey(int i) => 'tasbih_total_$i';

  int _selected = 0;
  int _target = 33;
  final _counts = List<int>.filled(_kDhikrs.length, 0);
  final _totals = List<int>.filled(_kDhikrs.length, 0);
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _selected = (prefs.getInt(_kSelected) ?? 0).clamp(
          0,
          _kDhikrs.length - 1,
        );
        final t = prefs.getInt(_kTarget) ?? 33;
        _target = _kTargets.contains(t) ? t : 33;
        for (var i = 0; i < _kDhikrs.length; i++) {
          _counts[i] = prefs.getInt(_countKey(i)) ?? 0;
          _totals[i] = prefs.getInt(_totalKey(i)) ?? 0;
        }
      });
    });
  }

  void _tap() {
    setState(() {
      _counts[_selected]++;
      _totals[_selected]++;
    });
    _prefs?.setInt(_countKey(_selected), _counts[_selected]);
    _prefs?.setInt(_totalKey(_selected), _totals[_selected]);
    if (_target > 0 && _counts[_selected] % _target == 0) {
      HapticFeedback.heavyImpact();
      Future.delayed(
        const Duration(milliseconds: 160),
        HapticFeedback.heavyImpact,
      );
    } else {
      HapticFeedback.selectionClick();
    }
  }

  void _reset() {
    setState(() => _counts[_selected] = 0);
    _prefs?.setInt(_countKey(_selected), 0);
  }

  String _num(int n) => localizedNumber(context, n);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isArabic = context.locale.languageCode == 'ar';
    final count = _counts[_selected];
    final progress = _target > 0 ? (count % _target) / _target : 0.0;
    final rounds = _target > 0 ? count ~/ _target : 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth * 0.68, 300.0);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _kDhikrs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => ChoiceChip(
                  label: Text(
                    _kDhikrs[i].ar,
                    style: AppTheme.athkarTextStyle(
                      context,
                    ).copyWith(fontSize: 15, height: 1.2),
                  ),
                  selected: i == _selected,
                  onSelected: (_) {
                    setState(() => _selected = i);
                    _prefs?.setInt(_kSelected, i);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _kDhikrs[_selected].ar,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: AppTheme.athkarTextStyle(context).copyWith(fontSize: 26),
            ),
            if (!isArabic) ...[
              const SizedBox(height: 4),
              Text(
                _kDhikrs[_selected].en,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 24),
            Center(
              child: Semantics(
                button: true,
                label: 'athkar.tasbih_tap'.tr(),
                child: GestureDetector(
                  onTap: _tap,
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: size,
                          height: size,
                          child: CircularProgressIndicator(
                            value: _target > 0 ? progress : 0,
                            strokeWidth: 10,
                            backgroundColor: scheme.surfaceContainerHighest,
                          ),
                        ),
                        Container(
                          width: size - 28,
                          height: size - 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.primaryContainer,
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _num(count),
                                style: Theme.of(context).textTheme.displayLarge
                                    ?.copyWith(
                                      color: scheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              if (_target > 0)
                                Text(
                                  '${'athkar.tasbih_target'.tr()}: ${_num(_target)}'
                                  '${rounds > 0 ? '  ·  ×${_num(rounds)}' : ''}',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: scheme.onPrimaryContainer,
                                      ),
                                ),
                              const SizedBox(height: 6),
                              Text(
                                'athkar.tasbih_tap'.tr(),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: scheme.onPrimaryContainer
                                          .withValues(alpha: 0.7),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${'athkar.tasbih_target'.tr()}: '),
                DropdownButton<int>(
                  value: _target,
                  items: [
                    for (final t in _kTargets)
                      DropdownMenuItem(
                        value: t,
                        child: Text(
                          t == 0 ? 'athkar.tasbih_no_target'.tr() : _num(t),
                        ),
                      ),
                  ],
                  onChanged: (t) {
                    if (t == null) return;
                    setState(() => _target = t);
                    _prefs?.setInt(_kTarget, t);
                  },
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: Text('athkar.tasbih_reset'.tr()),
                  onPressed: count == 0 ? null : _reset,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${'athkar.tasbih_total'.tr()}: ${_num(_totals[_selected])}',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.outline),
            ),
          ],
        );
      },
    );
  }
}

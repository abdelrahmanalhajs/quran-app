import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/arabic_numbers.dart';
import '../../core/services/notification_prefs.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/quran_repository.dart';
import '../../models/ayah.dart';
import '../../models/surah.dart';
import '../../state/audio_provider.dart';
import '../../state/hifz_provider.dart';
import '../../state/settings_provider.dart';
import '../../widgets/reciter_picker_sheet.dart';
import '../../widgets/responsive_center.dart';
import '../quran/reading_plan_screen.dart' show formatReminderTime;
import '../../core/plural_text.dart';

Future<SurahSummary> _surah(int number) async =>
    (await QuranRepository().getSurahList()).firstWhere(
      (s) => s.number == number,
    );

String _surahName(BuildContext context, SurahSummary s) =>
    context.locale.languageCode == 'ar' ? s.nameAr : s.englishName;

/// Overview of memorization: surahs due for review, in progress and
/// memorized, plus starting a new surah and the daily review reminder.
class HifzHubScreen extends StatefulWidget {
  const HifzHubScreen({super.key});

  @override
  State<HifzHubScreen> createState() => _HifzHubScreenState();
}

class _HifzHubScreenState extends State<HifzHubScreen> {
  List<SurahSummary> _surahs = const [];
  bool _reminderOn = false;
  ReminderTime _reminderTime = const ReminderTime(18 * 60);

  @override
  void initState() {
    super.initState();
    QuranRepository().getSurahList().then((l) {
      if (mounted) setState(() => _surahs = l);
    });
    () async {
      final on = await hifzReminderSetting.isEnabled();
      final t = await PlanReminderPrefs.hifzTime();
      if (mounted) {
        setState(() {
          _reminderOn = on;
          _reminderTime = t;
        });
      }
    }();
  }

  SurahSummary? _byNumber(int n) {
    for (final s in _surahs) {
      if (s.number == n) return s;
    }
    return null;
  }

  void _open(SurahSummary s, {bool review = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HifzSessionScreen(
          surah: s,
          fromAyah: 1,
          toAyah: s.numberOfAyahs,
          review: review,
        ),
      ),
    );
  }

  Future<void> _pickSurah() async {
    final picked = await showModalBottomSheet<SurahSummary>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.75,
        child: ListView.builder(
          itemCount: _surahs.length,
          itemBuilder: (ctx, i) {
            final s = _surahs[i];
            return ListTile(
              leading: CircleAvatar(
                radius: 14,
                child: Text(
                  localizedNumber(context, s.number),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              title: Text(_surahName(context, s)),
              subtitle: Text(
                'hifz.ayahs_n'.tr(
                  args: [localizedNumber(context, s.numberOfAyahs)],
                ),
              ),
              onTap: () => Navigator.of(ctx).pop(s),
            );
          },
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final hifz = context.read<HifzProvider>();
    if (hifz.entryFor(picked.number).status == HifzStatus.none) {
      await hifz.setLearning(picked.number);
    }
    _open(picked);
  }

  Future<void> _setReminder(bool on) async {
    final arabic = context.locale.languageCode == 'ar';
    setState(() => _reminderOn = on);
    await hifzReminderSetting.setEnabled(on);
    if (kIsWeb) return;
    if (on) {
      if (await NotificationService.requestPermission()) {
        await NotificationService.scheduleHifzReminder(arabic: arabic);
      }
    } else {
      await NotificationService.cancelHifzReminder();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hifz = context.watch<HifzProvider>();
    final theme = Theme.of(context);
    String n(int v) => localizedNumber(context, v);
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Text(title, style: theme.textTheme.titleSmall),
    );

    final due = hifz.dueForReview;
    final learning = hifz.learning;
    final memorized = hifz.memorized;

    return Scaffold(
      appBar: AppBar(title: Text('hifz.title'.tr())),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _surahs.isEmpty ? null : _pickSurah,
        icon: const Icon(Icons.add),
        label: Text('hifz.start_surah'.tr()),
      ),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text('hifz.intro'.tr()),
              ),
            ),
            if (due.isNotEmpty) ...[
              section('hifz.due_today'.tr()),
              for (final e in due)
                if (_byNumber(e.surah) case final s?)
                  Card(
                    child: ListTile(
                      title: Text(_surahName(context, s)),
                      subtitle: Text(
                        'hifz.review_round'.tr(args: [n(e.stage + 1)]),
                      ),
                      trailing: FilledButton(
                        onPressed: () => _open(s, review: true),
                        child: Text('hifz.review'.tr()),
                      ),
                    ),
                  ),
            ],
            if (learning.isNotEmpty) ...[
              section('hifz.learning'.tr()),
              for (final e in learning)
                if (_byNumber(e.surah) case final s?)
                  Card(
                    child: ListTile(
                      title: Text(_surahName(context, s)),
                      onTap: () => _open(s),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) => v == 'done'
                            ? hifz.markMemorized(s.number)
                            : hifz.remove(s.number),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'done',
                            child: Text('hifz.mark_memorized'.tr()),
                          ),
                          PopupMenuItem(
                            value: 'remove',
                            child: Text('hifz.remove'.tr()),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
            if (memorized.isNotEmpty) ...[
              section('hifz.memorized_n'.tr(args: [n(memorized.length)])),
              for (final e in memorized)
                if (_byNumber(e.surah) case final s?)
                  Card(
                    child: ListTile(
                      title: Text(_surahName(context, s)),
                      subtitle: Text(() {
                        final next = e.nextReview;
                        if (next == null || !next.isAfter(todayDay)) {
                          return 'hifz.review_due_now'.tr();
                        }
                        return 'hifz.next_review_in'.tr(
                          args: [
                            daysText(context, next.difference(todayDay).inDays),
                          ],
                        );
                      }()),
                      onTap: () => _open(s, review: true),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) => hifz.remove(s.number),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'remove',
                            child: Text('hifz.remove'.tr()),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
            if (due.isEmpty && learning.isEmpty && memorized.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'hifz.empty'.tr(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text('hifz.reminder'.tr()),
                    value: _reminderOn,
                    onChanged: _setReminder,
                  ),
                  if (_reminderOn)
                    ListTile(
                      title: Text('settings.reminder_time'.tr()),
                      trailing: Text(
                        formatReminderTime(context, _reminderTime),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      onTap: () async {
                        final arabic = context.locale.languageCode == 'ar';
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: _reminderTime.hour,
                            minute: _reminderTime.minute,
                          ),
                        );
                        if (picked == null) return;
                        final t = ReminderTime(
                          picked.hour * 60 + picked.minute,
                        );
                        setState(() => _reminderTime = t);
                        await PlanReminderPrefs.setHifzTime(t);
                        if (!kIsWeb) {
                          await NotificationService.scheduleHifzReminder(
                            arabic: arabic,
                          );
                        }
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens a memorization session from an ayah (e.g. from the ayah sheet):
/// that ayah and the next few.
Future<void> openHifzFromAyah(BuildContext context, Ayah ayah) async {
  final s = await _surah(ayah.surahNumber);
  if (!context.mounted) return;
  final hifz = context.read<HifzProvider>();
  if (hifz.entryFor(s.number).status == HifzStatus.none) {
    await hifz.setLearning(s.number);
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => HifzSessionScreen(
        surah: s,
        fromAyah: ayah.numberInSurah,
        toAyah: (ayah.numberInSurah + 4).clamp(1, s.numberOfAyahs),
      ),
    ),
  );
}

const _kRepeatChoices = [1, 2, 3, 5, 7, 10, 20];
const _kRangeChoices = [1, 2, 3, 5, 0];
const _kPauseChoices = [0, 2, 3, 5, 10];

/// One memorization session: an ayah range recited with repetitions and
/// pauses, optional hidden text (tap an ayah to reveal it), and marking
/// the surah memorized or reviewed.
class HifzSessionScreen extends StatefulWidget {
  final SurahSummary surah;
  final int fromAyah;
  final int toAyah;

  /// Opened to review an already memorized surah.
  final bool review;

  const HifzSessionScreen({
    super.key,
    required this.surah,
    required this.fromAyah,
    required this.toAyah,
    this.review = false,
  });

  @override
  State<HifzSessionScreen> createState() => _HifzSessionScreenState();
}

class _HifzSessionScreenState extends State<HifzSessionScreen> {
  late int _from = widget.fromAyah;
  late int _to = widget.toAyah;
  List<Ayah> _ayahs = const [];
  final Set<int> _revealed = {};
  final Map<int, GlobalKey> _keys = {};
  int? _lastScrolledTo;

  late final AudioProvider _audio;

  @override
  void initState() {
    super.initState();
    _audio = context.read<AudioProvider>();
    QuranRepository().getSurahAyahs(widget.surah.number).then((a) {
      if (mounted) setState(() => _ayahs = a);
    });
  }

  @override
  void dispose() {
    // Leaving the screen ends the session.
    if (_audio.hifzActive) _audio.stopHifz();
    super.dispose();
  }

  String _n(int v) => localizedNumber(context, v);

  Future<int?> _pickFrom(
    List<int> options,
    int current,
    String Function(int) label,
  ) {
    return showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in options)
              ListTile(
                title: Text(label(o)),
                trailing: o == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(ctx).pop(o),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRange() async {
    var from = _from, to = _to;
    final total = widget.surah.numberOfAyahs;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('hifz.choose_ayahs'.tr()),
          content: Row(
            children: [
              Text('${'hifz.from'.tr()} '),
              DropdownButton<int>(
                value: from,
                items: [
                  for (var i = 1; i <= total; i++)
                    DropdownMenuItem(value: i, child: Text(_n(i))),
                ],
                onChanged: (v) => setD(() {
                  from = v!;
                  if (to < from) to = from;
                }),
              ),
              const SizedBox(width: 16),
              Text('${'hifz.to'.tr()} '),
              DropdownButton<int>(
                value: to,
                items: [
                  for (var i = from; i <= total; i++)
                    DropdownMenuItem(value: i, child: Text(_n(i))),
                ],
                onChanged: (v) => setD(() => to = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('prayer.cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('prayer.save'.tr()),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      if (_audio.hifzActive) await _audio.stopHifz();
      if (!mounted) return;
      setState(() {
        _from = from;
        _to = to;
      });
    }
  }

  void _togglePlay() {
    final audio = context.read<AudioProvider>();
    if (audio.hifzActive) {
      audio.stopHifz();
      return;
    }
    final hifz = context.read<HifzProvider>();
    final reciter = context.read<SettingsProvider>().reciter;
    _lastScrolledTo = null;
    audio.playHifz(
      surahNumber: widget.surah.number,
      fromAyah: _from,
      toAyah: _to,
      reciter: reciter,
      repeatEach: hifz.repeatEach,
      repeatRange: hifz.repeatRange,
      pause: Duration(seconds: hifz.pauseSeconds),
      surahTitle: widget.surah.nameAr,
    );
  }

  void _scrollTo(int ayah) {
    if (_lastScrolledTo == ayah) return;
    _lastScrolledTo = ayah;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[ayah]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          alignment: 0.3,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hifz = context.watch<HifzProvider>();
    final audio = context.watch<AudioProvider>();
    final settings = context.watch<SettingsProvider>();
    final reciter = settings.reciter;
    final theme = Theme.of(context);
    final playingHere =
        audio.hifzActive && audio.hifzSurah == widget.surah.number;
    final current = playingHere ? audio.hifzAyah : null;
    if (current != null) _scrollTo(current);
    final entry = hifz.entryFor(widget.surah.number);
    final ayahs = _ayahs
        .where((a) => a.numberInSurah >= _from && a.numberInSurah <= _to)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_surahName(context, widget.surah)),
        actions: [
          IconButton(
            tooltip: 'hifz.hide_text'.tr(),
            icon: Icon(hifz.hideText ? Icons.visibility_off : Icons.visibility),
            onPressed: () {
              setState(_revealed.clear);
              hifz.updateSessionSettings(hideText: !hifz.hideText);
            },
          ),
        ],
      ),
      body: ResponsiveCenter(
        child: Column(
          children: [
            if (!reciter.supportsAyahPlayback)
              MaterialBanner(
                content: Text(
                  'hifz.reciter_unsupported'.tr(args: [reciter.nameAr]),
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      final r = await showReciterPicker(context, reciter);
                      if (r != null) await settings.setReciter(r);
                    },
                    child: Text('hifz.change_reciter'.tr()),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.format_list_numbered, size: 18),
                    label: Text('${'hifz.ayahs'.tr()} ${_n(_from)}–${_n(_to)}'),
                    onPressed: _pickRange,
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.repeat_one, size: 18),
                    label: Text(
                      'hifz.repeat_each'.tr(args: [_n(hifz.repeatEach)]),
                    ),
                    onPressed: () async {
                      final v = await _pickFrom(
                        _kRepeatChoices,
                        hifz.repeatEach,
                        (o) => '×${_n(o)}',
                      );
                      if (v != null) hifz.updateSessionSettings(repeatEach: v);
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.repeat, size: 18),
                    label: Text(
                      hifz.repeatRange == 0
                          ? 'hifz.range_loop'.tr()
                          : 'hifz.repeat_range'.tr(
                              args: [_n(hifz.repeatRange)],
                            ),
                    ),
                    onPressed: () async {
                      final v = await _pickFrom(
                        _kRangeChoices,
                        hifz.repeatRange,
                        (o) => o == 0 ? 'hifz.range_loop'.tr() : '×${_n(o)}',
                      );
                      if (v != null) hifz.updateSessionSettings(repeatRange: v);
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.timer_outlined, size: 18),
                    label: Text(
                      'hifz.pause_s'.tr(args: [_n(hifz.pauseSeconds)]),
                    ),
                    onPressed: () async {
                      final v = await _pickFrom(
                        _kPauseChoices,
                        hifz.pauseSeconds,
                        (o) => 'hifz.pause_s'.tr(args: [_n(o)]),
                      );
                      if (v != null) {
                        hifz.updateSessionSettings(pauseSeconds: v);
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: _ayahs.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                      children: [
                        for (final a in ayahs)
                          _AyahTile(
                            key: _keys.putIfAbsent(
                              a.numberInSurah,
                              GlobalKey.new,
                            ),
                            ayah: a,
                            hidden:
                                hifz.hideText &&
                                !_revealed.contains(a.numberInSurah),
                            active: current == a.numberInSurah,
                            repeatLabel: current == a.numberInSurah
                                ? '${_n(audio.hifzRepeat)}/${_n(hifz.repeatEach)}'
                                : null,
                            onTap: () => setState(() {
                              if (!_revealed.add(a.numberInSurah)) {
                                _revealed.remove(a.numberInSurah);
                              }
                            }),
                          ),
                      ],
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (playingHere && current != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'hifz.status'.tr(
                            args: [
                              _n(current),
                              _n(audio.hifzRepeat),
                              _n(hifz.repeatEach),
                            ],
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                            icon: Icon(
                              playingHere ? Icons.stop : Icons.play_arrow,
                            ),
                            label: Text(
                              playingHere ? 'hifz.stop'.tr() : 'hifz.play'.tr(),
                            ),
                            onPressed: reciter.supportsAyahPlayback
                                ? _togglePlay
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                            icon: const Icon(Icons.check_circle_outline),
                            label: Text(
                              entry.status == HifzStatus.memorized
                                  ? 'hifz.mark_reviewed'.tr()
                                  : 'hifz.mark_memorized'.tr(),
                            ),
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final isArabic =
                                  context.locale.languageCode == 'ar';
                              if (entry.status == HifzStatus.memorized) {
                                await hifz.markReviewed(widget.surah.number);
                              } else {
                                await hifz.markMemorized(widget.surah.number);
                              }
                              final next = hifz
                                  .entryFor(widget.surah.number)
                                  .nextReview;
                              final days = next == null
                                  ? 1
                                  : next.difference(DateTime.now()).inDays + 1;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'hifz.saved_next_review'.tr(
                                      args: [
                                        'common.days'.plural(
                                          days,
                                          args: [
                                            isArabic
                                                ? arabicIndicNumber(days)
                                                : '$days',
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
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
  }
}

class _AyahTile extends StatelessWidget {
  final Ayah ayah;
  final bool hidden;
  final bool active;
  final String? repeatLabel;
  final VoidCallback onTap;

  const _AyahTile({
    super.key,
    required this.ayah,
    required this.hidden,
    required this.active,
    required this.repeatLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = AppTheme.quranTextStyle(
      context,
      fontSize: 22,
    ).copyWith(height: 2.1);
    final words = ayah.textAr.split(' ');
    final Widget text = hidden
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${words.first} …',
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: style,
              ),
              ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Text(
                  words.skip(1).join(' '),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: style,
                  maxLines: 2,
                  overflow: TextOverflow.clip,
                ),
              ),
            ],
          )
        : Text(
            // The number badge beside it already shows the ayah number.
            ayah.textAr,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: style,
          );
    return Card(
      color: active ? scheme.secondaryContainer : null,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: active
                        ? scheme.primary
                        : scheme.secondaryContainer,
                    child: Text(
                      arabicIndicNumber(ayah.numberInSurah),
                      style: TextStyle(
                        fontSize: 12,
                        color: active ? scheme.onPrimary : null,
                      ),
                    ),
                  ),
                  if (repeatLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        repeatLabel!,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(child: text),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const _kQuranFont = 'KFGQPC HAFS Uthmanic Script';

enum _CardStyle { cream, green, night }

/// Opens a preview of [textAr] as a designed image card (Uthmani text, the
/// surah reference, optional English translation, the app's name) with a
/// choice of three looks, and shares it as a PNG.
Future<void> showAyahImageShare(
  BuildContext context, {
  required String textAr,
  required String refAr,
  String? translation,
  String? refEn,
}) {
  return showDialog(
    context: context,
    builder: (_) => _AyahImageDialog(
      textAr: textAr,
      refAr: refAr,
      translation: translation,
      refEn: refEn,
    ),
  );
}

class _AyahImageDialog extends StatefulWidget {
  final String textAr;
  final String refAr;
  final String? translation;
  final String? refEn;

  const _AyahImageDialog({
    required this.textAr,
    required this.refAr,
    this.translation,
    this.refEn,
  });

  @override
  State<_AyahImageDialog> createState() => _AyahImageDialogState();
}

class _AyahImageDialogState extends State<_AyahImageDialog> {
  final _boundaryKey = GlobalKey();
  _CardStyle _style = _CardStyle.cream;
  bool _withTranslation = true;
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    try {
      final boundary =
          _boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      // ~1080px wide on a typical phone preview.
      final ratio = 1080 / boundary.size.width;
      final image = await boundary.toImage(pixelRatio: ratio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('no image');
      final png = bytes.buffer.asUint8List();
      final XFile file;
      if (kIsWeb) {
        file = XFile.fromData(png, mimeType: 'image/png', name: 'ayah.png');
      } else {
        final dir = await getTemporaryDirectory();
        final f = File(
          '${dir.path}/ayah_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await f.writeAsBytes(png);
        file = XFile(f.path, mimeType: 'image/png');
      }
      await SharePlus.instance.share(
        ShareParams(files: [file], sharePositionOrigin: origin),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('quran.share_image_failed'.tr())));
      setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTranslation = (widget.translation ?? '').trim().isNotEmpty;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                key: _boundaryKey,
                child: _AyahCard(
                  style: _style,
                  textAr: widget.textAr,
                  refAr: widget.refAr,
                  translation: hasTranslation && _withTranslation
                      ? widget.translation
                      : null,
                  refEn: widget.refEn,
                  appName: 'app_name'.tr(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final s in _CardStyle.values)
                    ChoiceChip(
                      label: Text('quran.card_style_${s.name}'.tr()),
                      selected: _style == s,
                      onSelected: (_) => setState(() => _style = s),
                    ),
                ],
              ),
              if (hasTranslation)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('quran.card_with_translation'.tr()),
                  value: _withTranslation,
                  onChanged: (v) => setState(() => _withTranslation = v),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('prayer.cancel'.tr()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: _sharing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.share),
                      label: Text('quran.share_image'.tr()),
                      onPressed: _sharing ? null : _share,
                    ),
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

class _AyahCard extends StatelessWidget {
  final _CardStyle style;
  final String textAr;
  final String refAr;
  final String? translation;
  final String? refEn;
  final String appName;

  const _AyahCard({
    required this.style,
    required this.textAr,
    required this.refAr,
    required this.translation,
    required this.refEn,
    required this.appName,
  });

  @override
  Widget build(BuildContext context) {
    final (Color bg1, Color bg2, Color ink, Color accent) = switch (style) {
      _CardStyle.cream => (
        const Color(0xFFFBF6E9),
        const Color(0xFFF1E7CC),
        const Color(0xFF1F1A12),
        const Color(0xFF0E6E55),
      ),
      _CardStyle.green => (
        const Color(0xFF0E6E55),
        const Color(0xFF0A4F3D),
        Colors.white,
        const Color(0xFFFFD27A),
      ),
      _CardStyle.night => (
        const Color(0xFF151A24),
        const Color(0xFF0B0E14),
        const Color(0xFFF3EEDF),
        const Color(0xFFD9B86C),
      ),
    };
    // Long passages get a smaller font so the card stays a sensible shape.
    final len = textAr.length;
    final fontSize = len < 120
        ? 26.0
        : len < 260
        ? 22.0
        : len < 420
        ? 19.0
        : 16.0;

    return AspectRatio(
      aspectRatio: translation == null ? 1 : 4 / 5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bg1, bg2],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: accent, width: 2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: accent.withValues(alpha: 0.5),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                  child: Column(
                    children: [
                      Text(
                        '﴾ ${refAr.split(':').first} ﴿',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: _kQuranFont,
                          fontSize: 15,
                          color: accent,
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: SizedBox(
                              width: 380,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    textAr,
                                    textAlign: TextAlign.center,
                                    textDirection: TextDirection.rtl,
                                    style: TextStyle(
                                      fontFamily: _kQuranFont,
                                      fontSize: fontSize,
                                      height: 2.0,
                                      color: ink,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    refAr,
                                    textDirection: TextDirection.rtl,
                                    style: TextStyle(
                                      fontFamily: _kQuranFont,
                                      fontSize: 14,
                                      color: accent,
                                    ),
                                  ),
                                  if (translation != null) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      translation!,
                                      textAlign: TextAlign.center,
                                      textDirection: TextDirection.ltr,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        color: ink.withValues(alpha: 0.85),
                                      ),
                                    ),
                                    if (refEn != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          refEn!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: accent,
                                          ),
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        appName,
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.5,
                          color: ink.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import '../core/constants/reciters.dart';

Future<Reciter?> showReciterPicker(BuildContext context, Reciter current) {
  return showDialog<Reciter>(
    context: context,
    builder: (ctx) {
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'quran.choose_reciter_hint'.tr(),
                    textAlign: TextAlign.center,
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: kReciters.map((r) {
                      final selected = r.id == current.id;
                      final isArabic = ctx.locale.languageCode == 'ar';
                      return ListTile(
                        leading: Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: selected
                              ? Theme.of(ctx).colorScheme.primary
                              : null,
                        ),
                        title: Text(isArabic ? r.nameAr : r.nameEn),
                        onTap: () => Navigator.of(ctx).pop(r),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

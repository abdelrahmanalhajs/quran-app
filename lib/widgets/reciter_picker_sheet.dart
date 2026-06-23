import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import '../core/constants/reciters.dart';

Future<Reciter?> showReciterPicker(BuildContext context, Reciter current) {
  return showModalBottomSheet<Reciter>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'quran.choose_reciter'.tr(),
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ...kReciters.map((r) {
              final selected = r.id == current.id;
              final isArabic = ctx.locale.languageCode == 'ar';
              return ListTile(
                leading: Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? Theme.of(ctx).colorScheme.primary : null,
                ),
                title: Text(isArabic ? r.nameAr : r.nameEn),
                onTap: () => Navigator.of(ctx).pop(r),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

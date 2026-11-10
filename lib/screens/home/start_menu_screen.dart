import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shown each time the app is opened again: lets the user pick which part
/// of the app to go to (Quran, prayer, athkar, hadith, settings). Pops with
/// the chosen [HomeShell] tab index; HomeShell then opens that section where
/// the user last left it (e.g. the last-read Mushaf page).
class StartMenuScreen extends StatelessWidget {
  const StartMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = [
      (Icons.menu_book, 'nav.quran'.tr()),
      (Icons.explore_outlined, 'nav.prayer'.tr()),
      (Icons.favorite_outline, 'nav.athkar'.tr()),
      (Icons.format_quote, 'nav.hadith'.tr()),
      (Icons.settings_outlined, 'nav.settings'.tr()),
    ];
    return PopScope(
      // This is the app's root screen at launch: back leaves the app, as it
      // would from any home screen, rather than revealing the tabs behind.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) SystemNavigator.pop();
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(24),
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        width: 96,
                        height: 96,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'app_name'.tr(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 28),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.25,
                    children: [
                      for (var i = 0; i < items.length; i++)
                        _MenuTile(
                          icon: items[i].$1,
                          label: items[i].$2,
                          onTap: () => Navigator.of(context).pop(i),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: scheme.onPrimaryContainer),
            const SizedBox(height: 10),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

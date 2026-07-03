import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/settings_provider.dart';
import '../home/home_shell.dart';

class _Step {
  final IconData icon;
  final String titleKey;
  final String bodyKey;
  const _Step(this.icon, this.titleKey, this.bodyKey);
}

const _kSteps = [
  _Step(Icons.menu_book, 'onboarding.step1_title', 'onboarding.step1_body'),
  _Step(Icons.swipe, 'onboarding.step2_title', 'onboarding.step2_body'),
  _Step(
    Icons.headphones,
    'onboarding.step3_title',
    'onboarding.step3_body',
  ),
  _Step(Icons.explore, 'onboarding.step4_title', 'onboarding.step4_body'),
  _Step(
    Icons.favorite_outline,
    'onboarding.step5_title',
    'onboarding.step5_body',
  ),
];

/// Shown once, before [HomeShell], on a fresh install: page 0 asks the
/// first-time user to pick a language (the app has no locale preference of
/// its own yet at this point, so both names are spelled out rather than
/// relying on `.tr()`); the following pages are a short Next/Skip-driven
/// walkthrough of the app's main features, now localized into whichever
/// language was just chosen. See [SettingsProvider.onboardingDone] for the
/// persisted flag that keeps this from showing again.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  final int _totalPages = _kSteps.length + 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _chooseLanguage(Locale locale) async {
    await context.setLocale(locale);
    _controller.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish() async {
    await context.read<SettingsProvider>().setOnboardingDone();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  void _next() {
    if (_page == _totalPages - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _LanguagePage(onChoose: _chooseLanguage),
                  for (final step in _kSteps) _FeatureStep(step: step),
                ],
              ),
            ),
            if (_page > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _finish,
                      child: Text('onboarding.skip'.tr()),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        for (var i = 1; i < _totalPages; i++)
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == _page
                                  ? scheme.primary
                                  : scheme.primary.withValues(alpha: 0.25),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _next,
                      child: Text(
                        _page == _totalPages - 1
                            ? 'onboarding.get_started'.tr()
                            : 'onboarding.next'.tr(),
                      ),
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

class _LanguagePage extends StatelessWidget {
  final void Function(Locale locale) onChoose;
  const _LanguagePage({required this.onChoose});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_book, size: 72, color: scheme.primary),
                  const SizedBox(height: 24),
                  const Text(
                    'Choose your language',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'اختر لغتك',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => onChoose(const Locale('en')),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'English',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => onChoose(const Locale('ar')),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'العربية',
                        style: TextStyle(fontSize: 16),
                      ),
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
}

class _FeatureStep extends StatelessWidget {
  final _Step step;
  const _FeatureStep({required this.step});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(step.icon, size: 72, color: scheme.primary),
                  const SizedBox(height: 28),
                  Text(
                    step.titleKey.tr(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    step.bodyKey.tr(),
                    style: TextStyle(
                      fontSize: 15,
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

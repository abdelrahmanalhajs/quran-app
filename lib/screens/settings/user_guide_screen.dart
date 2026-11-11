import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import '../../core/responsive.dart';
import '../../widgets/responsive_center.dart';

class _GuideItem {
  final IconData icon;
  final String titleKey;
  final String bodyKey;
  const _GuideItem(this.icon, this.titleKey, this.bodyKey);
}

class _GuideSection {
  final IconData icon;
  final String titleKey;
  final List<_GuideItem> items;
  const _GuideSection(this.icon, this.titleKey, this.items);
}

const _kSections = [
  _GuideSection(Icons.menu_book_outlined, 'guide.section_reading', [
    _GuideItem(
      Icons.auto_stories_outlined,
      'guide.reading_page_view_title',
      'guide.reading_page_view_body',
    ),
    _GuideItem(
      Icons.swipe_outlined,
      'guide.reading_swipe_title',
      'guide.reading_swipe_body',
    ),
    _GuideItem(
      Icons.pinch_outlined,
      'guide.reading_zoom_title',
      'guide.reading_zoom_body',
    ),
    _GuideItem(
      Icons.format_size,
      'guide.reading_font_size_title',
      'guide.reading_font_size_body',
    ),
    _GuideItem(
      Icons.palette_outlined,
      'guide.reading_signs_title',
      'guide.reading_signs_body',
    ),
    _GuideItem(
      Icons.search,
      'guide.reading_search_title',
      'guide.reading_search_body',
    ),
    _GuideItem(
      Icons.touch_app_outlined,
      'guide.reading_ayah_sheet_title',
      'guide.reading_ayah_sheet_body',
    ),
    _GuideItem(
      Icons.auto_awesome_outlined,
      'guide.ayah_of_day_title',
      'guide.ayah_of_day_body',
    ),
    _GuideItem(
      Icons.image_outlined,
      'guide.share_image_title',
      'guide.share_image_body',
    ),
  ]),
  _GuideSection(Icons.bookmark_outline, 'guide.section_bookmarks', [
    _GuideItem(
      Icons.bookmark,
      'guide.bookmark_page_title',
      'guide.bookmark_page_body',
    ),
    _GuideItem(
      Icons.bookmark_added_outlined,
      'guide.bookmark_ayah_title',
      'guide.bookmark_ayah_body',
    ),
    _GuideItem(
      Icons.flag_outlined,
      'guide.khatm_page_title',
      'guide.khatm_page_body',
    ),
  ]),
  _GuideSection(Icons.school_outlined, 'guide.section_hifz', [
    _GuideItem(
      Icons.play_circle_outline,
      'guide.hifz_start_title',
      'guide.hifz_start_body',
    ),
    _GuideItem(
      Icons.repeat,
      'guide.hifz_repeat_title',
      'guide.hifz_repeat_body',
    ),
    _GuideItem(
      Icons.visibility_off_outlined,
      'guide.hifz_hide_title',
      'guide.hifz_hide_body',
    ),
    _GuideItem(
      Icons.event_repeat,
      'guide.hifz_review_title',
      'guide.hifz_review_body',
    ),
  ]),
  _GuideSection(Icons.flag_outlined, 'guide.section_plan', [
    _GuideItem(
      Icons.local_fire_department_outlined,
      'guide.plan_goal_title',
      'guide.plan_goal_body',
    ),
    _GuideItem(
      Icons.menu_book_outlined,
      'guide.plan_khatma_title',
      'guide.plan_khatma_body',
    ),
    _GuideItem(
      Icons.notifications_active_outlined,
      'guide.plan_reminder_title',
      'guide.plan_reminder_body',
    ),
  ]),
  _GuideSection(Icons.headphones_outlined, 'guide.section_audio', [
    _GuideItem(
      Icons.record_voice_over_outlined,
      'guide.audio_reciter_title',
      'guide.audio_reciter_body',
    ),
    _GuideItem(
      Icons.play_circle_outline,
      'guide.audio_play_title',
      'guide.audio_play_body',
    ),
    _GuideItem(
      Icons.download_for_offline_outlined,
      'guide.audio_offline_title',
      'guide.audio_offline_body',
    ),
    _GuideItem(
      Icons.graphic_eq,
      'guide.audio_highlight_title',
      'guide.audio_highlight_body',
    ),
  ]),
  _GuideSection(Icons.explore_outlined, 'guide.section_prayer', [
    _GuideItem(
      Icons.access_time,
      'guide.prayer_times_title',
      'guide.prayer_times_body',
    ),
    _GuideItem(
      Icons.explore,
      'guide.prayer_qiblah_title',
      'guide.prayer_qiblah_body',
    ),
    _GuideItem(
      Icons.event_outlined,
      'guide.islamic_days_title',
      'guide.islamic_days_body',
    ),
    _GuideItem(Icons.checklist, 'guide.qada_title', 'guide.qada_body'),
  ]),
  _GuideSection(Icons.self_improvement_outlined, 'guide.section_athkar', [
    _GuideItem(
      Icons.wb_twilight,
      'guide.athkar_daily_title',
      'guide.athkar_daily_body',
    ),
    _GuideItem(
      Icons.favorite_outline,
      'guide.athkar_tabs_title',
      'guide.athkar_tabs_body',
    ),
    _GuideItem(
      Icons.touch_app_outlined,
      'guide.tasbih_title',
      'guide.tasbih_body',
    ),
    _GuideItem(
      Icons.menu_book_outlined,
      'guide.hadith_title',
      'guide.hadith_body',
    ),
  ]),
  _GuideSection(Icons.notifications_outlined, 'guide.section_notifications', [
    _GuideItem(
      Icons.volume_up_outlined,
      'guide.notif_athan_title',
      'guide.notif_athan_body',
    ),
    _GuideItem(
      Icons.wb_sunny_outlined,
      'guide.notif_athkar_reminders_title',
      'guide.notif_athkar_reminders_body',
    ),
    _GuideItem(
      Icons.menu_book,
      'guide.notif_hadith_title',
      'guide.notif_hadith_body',
    ),
    _GuideItem(
      Icons.timer_outlined,
      'guide.notif_zikr_title',
      'guide.notif_zikr_body',
    ),
    _GuideItem(
      Icons.bedtime_outlined,
      'guide.notif_times_title',
      'guide.notif_times_body',
    ),
    _GuideItem(
      Icons.nights_stay_outlined,
      'guide.notif_fasting_title',
      'guide.notif_fasting_body',
    ),
    _GuideItem(
      Icons.wb_sunny_outlined,
      'guide.notif_ayah_day_title',
      'guide.notif_ayah_day_body',
    ),
    _GuideItem(
      Icons.touch_app,
      'guide.notif_tap_title',
      'guide.notif_tap_body',
    ),
  ]),
  _GuideSection(Icons.settings_outlined, 'guide.section_general', [
    _GuideItem(
      Icons.language,
      'guide.general_language_title',
      'guide.general_language_body',
    ),
    _GuideItem(
      Icons.dark_mode_outlined,
      'guide.general_theme_title',
      'guide.general_theme_body',
    ),
    _GuideItem(
      Icons.share_outlined,
      'guide.general_share_title',
      'guide.general_share_body',
    ),
  ]),
];

/// A permanently-accessible reference for every feature the app has —
/// unlike [OnboardingScreen] (shown once, and only a 5-step highlight
/// reel), this is the full list, reachable any time from Settings, so a
/// returning user can look up something like the manual "stop sign"
/// bookmark or the offline-download flow without reinstalling the app.
class UserGuideScreen extends StatelessWidget {
  const UserGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('guide.title'.tr())),
      body: ResponsiveCenter(
        child: ListView.separated(
          padding: EdgeInsets.symmetric(
            horizontal: responsiveHorizontalPadding(context) - 4,
            vertical: 8,
          ),
          itemCount: _kSections.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, index) => _SectionCard(
            section: _kSections[index],
            initiallyExpanded: index == 0,
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final _GuideSection section;
  final bool initiallyExpanded;

  const _SectionCard({required this.section, required this.initiallyExpanded});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: Icon(section.icon),
        title: Text(
          section.titleKey.tr(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        children: [
          for (final item in section.items) _GuideItemTile(item: item),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _GuideItemTile extends StatelessWidget {
  final _GuideItem item;

  const _GuideItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              item.icon,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.titleKey.tr(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  item.bodyKey.tr(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

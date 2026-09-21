import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/error/failure_exception.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/platform_chrome.dart';
import 'package:readendar/core/widgets/book_cover.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/core/widgets/nav_box.dart';
import 'package:readendar/core/widgets/rd_icon_button.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:readendar/core/widgets/section_header.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/feedback/feedback_mail.dart';
import 'package:readendar/features/import/import_sources_screen.dart';
import 'package:readendar/features/profile/appearance_sheet.dart';
import 'package:readendar/features/profile/settings_screen.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_format.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_hub_screen.dart';
import 'package:readendar/features/store_review/store_review_prompt.dart';
import 'package:readendar/features/widget/widgets_screen.dart';

/// Profile tab: tools, widgets, and mail-based feedback. Account identity lives
/// only in local data and is not shown here.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.navYou, key: const Key('profileAppBarTitle')),
        actions: [
          const _ThemeToggleAction(),
          RdIconButton(
            tooltip: l.settingsTitle,
            icon: LucideIcons.settings,
            onPressed: () => Navigator.of(context).push(
              rdPageRoute<void>(
                context,
                builder: (_) => const SettingsScreen(),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          28 + rdFloatingNavContentInset(context),
        ),
        children: [
          const _ReadingChapterProfileRow(),
          _SectionLabel(l.profileSectionTools),
          NavBox(
            icon: LucideIcons.bookUp,
            title: l.profileImportData,
            subtitle: l.profileImportSubtitle,
            tintBg: context.colors.warningSoftBg,
            tintFg: context.colors.warningSoftFg,
            onTap: () => Navigator.of(context).push(
              rdPageRoute<void>(
                context,
                builder: (_) => const ImportSourcesScreen(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          NavBox(
            icon: LucideIcons.layoutGrid,
            title: l.widgetsTitle,
            subtitle: l.widgetsRowSubtitle,
            onTap: () => Navigator.of(context).push(
              rdPageRoute<void>(
                context,
                builder: (_) => const WidgetsScreen(),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _FeedbackHighlightCard(
            onTap: () => unawaited(openFeedbackMailto(context)),
          ),
          const SizedBox(height: 12),
          _StoreReviewInviteCard(
            onTap: () => unawaited(showStoreReviewFromProfile(context, ref)),
          ),
        ],
      ),
    );
  }
}

class _ReadingChapterProfileRow extends ConsumerWidget {
  const _ReadingChapterProfileRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final latest = ref.watch(readingChapterLatestProvider);
    if (latest.hasError) {
      final error = latest.error;
      if (error is FailureException && error.failure is ForbiddenFailure) {
        return const SizedBox.shrink();
      }
    }
    final archiveValue = latest.asData?.value;
    if (archiveValue != null && !archiveValue.capabilities.privateGeneration) {
      return const SizedBox.shrink();
    }
    final item = archiveValue == null || archiveValue.items.isEmpty
        ? null
        : archiveValue.items.first;
    final hasUnread = archiveValue?.hasUnread ?? false;
    return Semantics(
      button: true,
      label: l.readingChapterTitle,
      child: RdCard(
        onTap: () => Navigator.of(context).push(
          rdPageRoute<void>(
            context,
            builder: (_) => const ReadingChapterHubScreen(),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        gradient: readingChapterThemeWash(context.colors),
        borderColor: readingChapterThemeWashBorder(context.colors),
        child: Row(
          children: [
            _ReadingChapterProfileMark(
              coverUrls: item?.coverUrls ?? const [],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.readingChapterTitle,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: context.colors.fg1,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      if (hasUnread) const ReadingChapterUnreadBadge(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item == null
                        ? l.readingChapterProfileSubtitle
                        : l.readingChapterProfileLatest(
                            readingChapterPeriodLabel(
                              context,
                              item.kind,
                              item.periodKey,
                            ),
                          ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.colors.fg2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              LucideIcons.chevronRight,
              color: context.colors.fg3,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadingChapterProfileMark extends StatelessWidget {
  const _ReadingChapterProfileMark({required this.coverUrls});
  final List<String> coverUrls;

  @override
  Widget build(BuildContext context) {
    if (coverUrls.isEmpty) {
      return Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: context.colors.accentSoftBg,
          borderRadius: BorderRadius.circular(ReadendarTokens.radiusCard),
        ),
        child: Icon(
          LucideIcons.bookHeart,
          color: context.colors.accent,
          size: 26,
        ),
      );
    }
    final visible = coverUrls.take(3).toList();
    return SizedBox(
      width: 58,
      height: 62,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var index = visible.length - 1; index >= 0; index--)
            Transform.translate(
              offset: Offset((index - 1) * 8, index * 1.5),
              child: Transform.rotate(
                angle: (index - 1) * 0.08,
                child: BookCover(
                  title: '',
                  coverUrl: visible[index],
                  width: 36,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shared grouped-content heading for the profile tab.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SectionHeader(
      text,
      key: const Key('profileSectionTitle'),
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
    );
  }
}

/// A deliberately eye-catching entry for "Send feedback": brand-tinted card,
/// filled icon chip, and a pill-styled title so users notice they can reach us.
class _FeedbackHighlightCard extends StatelessWidget {
  const _FeedbackHighlightCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    return RdCard(
      onTap: onTap,
      backgroundColor: c.accentSoftBg,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.accent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.messageCircleHeart,
              color: c.fgOnAccent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The badge is the card's title: a title font, but kept compact
                // and pill-styled so it reads as a highlight, not a banner.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    l.feedbackBadge,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: c.fgOnAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(l.feedbackProfileHint, style: TextStyle(color: c.fg1)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(LucideIcons.chevronRight, size: 18, color: c.accentSoftFg),
        ],
      ),
    );
  }
}

/// Soft, gratitude-flavoured invite to leave a store review — not a NavBox and
/// not the feedback highlight: warm tint, a quiet star row, friendly copy.
class _StoreReviewInviteCard extends StatelessWidget {
  const _StoreReviewInviteCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusLg),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ReadendarTokens.radiusLg),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                c.highlightSoft,
                c.warningSoftBg,
              ],
            ),
            border: Border.all(color: c.highlight.withValues(alpha: 0.35)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (var i = 0; i < 5; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      const Icon(
                        LucideIcons.star,
                        size: 16,
                        color: ReadendarTokens.amberStar,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  l.storeReviewSettingsRow,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: c.fg1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.storeReviewSettingsHint,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: c.fg2,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Appearance control in the "Tú" app bar: opens Light / Dark / System.
/// When System is selected, the glyph follows OS brightness (sun/moon).
class _ThemeToggleAction extends ConsumerWidget {
  const _ThemeToggleAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final mode = ref.watch(themeModeProvider);

    // Boxed so the control reads as its own affordance in the app bar rather
    // than a bare glyph: a subtly tinted, outlined pill that adapts to themes.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: RdIconButton(
        tooltip: l.profileAppearance,
        icon: appearanceIcon(mode, MediaQuery.platformBrightnessOf(context)),
        onPressed: () => showAppearanceSheet(context, ref),
        style: IconButton.styleFrom(
          backgroundColor: context.colors.surface2,
          foregroundColor: context.colors.fg1,
          side: BorderSide(color: context.colors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ReadendarTokens.radiusCard),
          ),
        ),
      ),
    );
  }
}

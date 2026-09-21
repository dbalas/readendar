import 'dart:async';

import 'package:flutter/material.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/date_format.dart';
import 'package:readendar/core/utils/platform_chrome.dart';
import 'package:readendar/core/utils/progress_display.dart';
import 'package:readendar/core/widgets/book_cover.dart';
import 'package:readendar/core/widgets/compact_empty_card.dart';
import 'package:readendar/core/widgets/event_card_compact.dart';
import 'package:readendar/core/widgets/event_icon.dart';
import 'package:readendar/core/widgets/error_retry.dart';
import 'package:readendar/core/widgets/rd_menu.dart';
import 'package:readendar/core/widgets/rd_refresh.dart';
import 'package:readendar/core/widgets/section_header.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/calendar/event_detail_sheet.dart';
import 'package:readendar/features/calendar/event_form_screen.dart';
import 'package:readendar/features/home/banner_editor_screen.dart';
import 'package:readendar/features/home/home_hero.dart';
import 'package:readendar/features/library/book_detail_screen.dart';
import 'package:readendar/features/library/library_pane.dart';
import 'package:readendar/features/library/status_books_screen.dart';
import 'package:readendar/features/offline/migration_banner.dart';
import 'package:readendar/features/roulette/book_roulette_screen.dart';
import 'package:readendar/features/search/search_screen.dart';
import 'package:readendar/features/stats/user_stats_screen.dart';

/// Users whose Home entrance has already played during this app run.
///
/// Kept outside [HomeScreen] because the shell disposes inactive tabs. Returning
/// from Library, Calendar, or Profile must show Home normally.
final _homeEntrancePlayedUsersProvider = StateProvider<Set<String>>(
  (ref) => const <String>{},
);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const _entranceDuration = Duration(milliseconds: 880);
  static const _heroInterval = Interval(0, 0.55, curve: Curves.easeOutCubic);
  static const _quickActionsInterval = Interval(
    0.12,
    0.67,
    curve: Curves.easeOutCubic,
  );
  static const _readingInterval = Interval(
    0.24,
    0.79,
    curve: Curves.easeOutCubic,
  );
  static const _eventsInterval = Interval(
    0.36,
    1,
    curve: Curves.easeOutCubic,
  );

  late final AnimationController _entrance;
  String? _animationStartedForUserId;
  String? _animationScheduledForUserId;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: _entranceDuration,
    );
  }

  void _scheduleInitialEntrance({
    required String? userId,
    required bool initialDataReady,
    required bool entrancePlayed,
    bool skipAnimation = false,
  }) {
    if (userId == null ||
        !initialDataReady ||
        entrancePlayed ||
        _animationStartedForUserId == userId ||
        _animationScheduledForUserId == userId) {
      return;
    }
    _animationScheduledForUserId = userId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _animationScheduledForUserId != userId) return;
      _animationScheduledForUserId = null;
      _animationStartedForUserId = userId;
      final playedUsers = ref.read(_homeEntrancePlayedUsersProvider);
      ref.read(_homeEntrancePlayedUsersProvider.notifier).state = {
        ...playedUsers,
        userId,
      };
      // Soft first-load failures and reduce-motion must not leave FadeTransitions
      // stuck at opacity 0 (blank Home).
      if (skipAnimation || MediaQuery.disableAnimationsOf(context)) {
        _entrance.value = 1.0;
        return;
      }
      unawaited(_entrance.forward(from: 0));
    });
  }

  Widget _appear({
    required String keyName,
    required Interval interval,
    required bool animate,
    required Widget child,
  }) {
    if (!animate || MediaQuery.disableAnimationsOf(context)) {
      return KeyedSubtree(key: ValueKey(keyName), child: child);
    }

    final animation = _entrance.drive(CurveTween(curve: interval));
    return FadeTransition(
      key: ValueKey(keyName),
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _openAddBook() async {
    final book = await Navigator.of(context).push<Book>(
      rdPageRoute<Book>(
        context,
        builder: (_) => const SearchScreen(),
      ),
    );
    if (book != null) {
      ref.invalidate(booksProvider);
      openLibrosTab(ref);
    }
  }

  Future<void> _openStartReading() async {
    final l = AppL10n.of(context);
    final choice = await showRdMenu<_StartReadingChoice>(
      context: context,
      items: [
        RdMenuItem(
          value: _StartReadingChoice.library,
          label: l.statusEmptyGoToLibrary,
          icon: LucideIcons.library,
        ),
        RdMenuItem(
          value: _StartReadingChoice.roulette,
          label: l.rouletteEntry,
          icon: LucideIcons.galleryHorizontal,
        ),
      ],
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _StartReadingChoice.library:
        openLibrosTab(ref);
      case _StartReadingChoice.roulette:
        await openBookRoulette(context);
    }
  }

  void _openAddEvent() {
    unawaited(
      Navigator.of(context).push<void>(
        rdPageRoute<void>(
          context,
          builder: (_) => EventFormScreen(defaultDate: DateTime.now()),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final displayName = ref.watch(
      sessionProvider.select((s) => s.user?.displayName ?? ''),
    );
    final userId = ref.watch(sessionProvider.select((s) => s.user?.id));
    // Narrow watch: only the banner style change should rebuild the hero.
    final banner = ref.watch(
      sessionProvider.select(
        (s) => s.user?.homeBanner ?? const BannerStyle.defaultStyle(),
      ),
    );
    final apiBaseUrl = ref.watch(apiBaseUrlProvider);
    final events = ref.watch(upcomingEventsProvider);
    final books = ref.watch(visibleBooksProvider);
    if ((books.hasError && !books.hasValue) ||
        (events.hasError && !events.hasValue)) {
      return Scaffold(
        body: SafeArea(
          child: ErrorRetry(
            error: books.error ?? events.error!,
            onRetry: () {
              ref
                ..invalidate(upcomingEventsProvider)
                ..invalidate(booksProvider);
            },
          ),
        ),
      );
    }
    // Prebuilt lookup maps (derived providers) — built once per data change,
    // not on every Home rebuild.
    final booksById = ref.watch(booksByIdProvider);
    final now = DateTime.now();
    final eventList = events.value ?? const <ReadingEvent>[];
    final bookList = books.value ?? const <Book>[];
    final todayEvents = eventList
        .where(
          (e) => _sameDay(e.dateLocal, now) && e.status == EventStatus.active,
        )
        .toList();
    final readingBooks = bookList
        .where((b) => b.status == BookStatus.reading)
        .toList();
    final greeting = homeGreeting(l, displayName, now);
    // Keep previously loaded shelves visible during pull-to-refresh. Only hide
    // while the *first* load is still in flight (no value yet).
    const booksSettled = true;
    const eventsSettled = true;
    // Entrance can start once loading finishes — success OR soft first-load
    // failure. Gating on "!hasError" left FadeTransitions at opacity 0 forever
    // after a failed first fetch (blank Home).
    final booksReady = books.hasValue || booksSettled;
    final eventsReady = events.hasValue || eventsSettled;
    final entrancePlayed =
        userId != null &&
        ref.watch(_homeEntrancePlayedUsersProvider).contains(userId);
    final animateEntrance =
        userId != null &&
        (!entrancePlayed || _animationStartedForUserId == userId);
    // Soft first-load failure only (no prior value). Refresh errors keep stale
    // data and must not disable entrance chrome for an already-played Home.
    final softFirstLoadFailure =
        (books.hasError && !books.hasValue) ||
        (events.hasError && !events.hasValue);
    _scheduleInitialEntrance(
      userId: userId,
      initialDataReady: booksReady && eventsReady,
      entrancePlayed: entrancePlayed,
      skipAnimation: softFirstLoadFailure,
    );

    return Scaffold(
      body: SafeArea(
        child: RdRefresh(
          onRefresh: () async {
            ref
              ..invalidate(upcomingEventsProvider)
              ..invalidate(booksProvider);
          },
          child: ListView(
            padding: EdgeInsets.only(
              bottom: 16 + rdFloatingNavContentInset(context),
            ),
            children: [
              _appear(
                keyName: 'homeHeroEntrance',
                interval: _heroInterval,
                animate: animateEntrance && !softFirstLoadFailure,
                child: HomeHero(
                  greeting: greeting,
                  date: formatHomeDate(
                    now,
                    Localizations.localeOf(context).toString(),
                  ),
                  readingCount: readingBooks.length,
                  pendingCount: bookList
                      .where((b) => b.status == BookStatus.pending)
                      .length,
                  wantedCount: bookList
                      .where((b) => b.status == BookStatus.wanted)
                      .length,
                  loading: false,
                  banner: banner,
                  mediaBaseUrl: apiBaseUrl,
                  onStatusTap: (status) => Navigator.of(context).push(
                    rdPageRoute<void>(
                      context,
                      builder: (_) => StatusBooksScreen(status: status),
                    ),
                  ),
                  onEdit: () => Navigator.of(context).push(
                    rdPageRoute<void>(
                      context,
                      builder: (_) => const BannerEditorScreen(),
                    ),
                  ),
                ),
              ),
              const MigrationBanner(),
              _appear(
                keyName: 'homeQuickActionsEntrance',
                interval: _quickActionsInterval,
                animate: animateEntrance && !softFirstLoadFailure,
                child: _QuickActions(
                  onAddBook: _openAddBook,
                  onAddEvent: _openAddEvent,
                  onRoulette: () => openBookRoulette(context),
                  onMetrics: () => Navigator.of(context).push(
                    rdPageRoute<void>(
                      context,
                      builder: (_) => const UserStatsScreen(),
                    ),
                  ),
                ),
              ),
              _appear(
                keyName: 'homeReadingEntrance',
                interval: _readingInterval,
                animate: animateEntrance && !softFirstLoadFailure,
                child: _ReadingShelf(
                  books: readingBooks,
                  onStartReading: _openStartReading,
                ),
              ),
              _appear(
                keyName: 'homeTodayEventsEntrance',
                interval: _eventsInterval,
                animate: animateEntrance && !softFirstLoadFailure,
                child: _EventSection(
                  title: l.sectionToday,
                  emptyMessage: l.emptyToday,
                  events: todayEvents,
                  booksById: booksById,
                  onAddEvent: _openAddEvent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onAddBook,
    required this.onAddEvent,
    required this.onRoulette,
    required this.onMetrics,
  });

  final VoidCallback onAddBook;
  final VoidCallback onAddEvent;
  final VoidCallback onRoulette;
  final VoidCallback onMetrics;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: _QuickAction(
              icon: LucideIcons.bookPlus,
              label: l.homeActionAddBook,
              color: c.accent2,
              foreground: Theme.of(context).colorScheme.onSecondary,
              tint: c.accent2SoftBg,
              onTap: onAddBook,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _QuickAction(
              icon: LucideIcons.calendarPlus,
              label: l.homeActionAddEvent,
              color: c.warning,
              foreground: c.warningSoftFg,
              tint: c.warningSoftBg,
              onTap: onAddEvent,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _QuickAction(
              icon: LucideIcons.galleryHorizontal,
              label: l.homeActionRoulette,
              color: c.accent,
              foreground: c.fgOnAccent,
              tint: c.accentSoftBg,
              onTap: onRoulette,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _QuickAction(
              icon: LucideIcons.chartColumn,
              label: l.myStatsTitle,
              color: ReadendarTokens.sage600,
              foreground: ReadendarTokens.paper50,
              tint: c.successSoftBg,
              onTap: onMetrics,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.foreground,
    required this.tint,
    required this.onTap,
  });

  static const _labelFontSize = 10.0;
  static const _labelLineHeight = 1.05;
  static const _labelMaxLines = 2;
  static const _labelHeight =
      _labelFontSize * _labelLineHeight * _labelMaxLines;

  final IconData icon;
  final String label;
  final Color color;
  final Color foreground;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
      child: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
              ),
              child: Icon(icon, color: foreground, size: 16),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: _labelHeight,
              child: Align(
                alignment: Alignment.topCenter,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: _labelMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: _labelFontSize,
                    fontWeight: FontWeight.w800,
                    height: _labelLineHeight,
                    color: context.colors.fg1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadingShelf extends StatelessWidget {
  const _ReadingShelf({
    required this.books,
    required this.onStartReading,
  });
  final List<Book> books;
  final VoidCallback onStartReading;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final colors = context.colors;
    return _HomeSection(
      title: l.sectionReading,
      child: Builder(
        builder: (_) {
          if (books.isEmpty) {
            return CompactEmptyCard(
              message: l.homeNoReading,
              actionLabel: l.homeStartReading,
              onAction: onStartReading,
              illustration: CompactEmptyGlyph(
                background: colors.accent2SoftBg,
                foreground: colors.accent2,
                icon: LucideIcons.bookOpen,
              ),
            );
          }
          return SizedBox(
            // Cover (132) + gap + up to 3 title lines + author, plus the 6px
            // top inset that keeps overhanging rating/notes badges unclipped.
            height: 216,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              // Top/right padding leaves room for the rating + notes badges that
              // overhang the cover corners, so the list viewport doesn't clip them.
              padding: const EdgeInsets.only(top: 6, right: 6),
              itemCount: books.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, i) => _ReadingBookTile(books[i]),
            ),
          );
        },
      ),
    );
  }
}

class _EventSection extends StatelessWidget {
  const _EventSection({
    required this.title,
    required this.emptyMessage,
    required this.events,
    required this.booksById,
    required this.onAddEvent,
  });

  final String title;
  final String emptyMessage;
  final List<ReadingEvent> events;
  final Map<String, Book> booksById;
  final VoidCallback onAddEvent;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final colors = context.colors;
    return _HomeSection(
      title: title,
      child: Builder(
        builder: (_) {
          if (events.isEmpty) {
            return CompactEmptyCard(
              message: emptyMessage,
              actionLabel: l.actionAddEvent,
              onAction: onAddEvent,
              illustration: CompactEmptyGlyph(
                background: colors.accentSoftBg,
                foreground: colors.accent,
                icon: LucideIcons.calendarPlus,
              ),
            );
          }
          return Column(
            children: events.map((e) {
              final book = booksById[e.bookId];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _EventTile(e, book),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

enum _StartReadingChoice { library, roulette }

class _HomeSection extends StatelessWidget {
  const _HomeSection({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title,
            key: const Key('homeSectionTitle'),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile(this.e, this.book);
  final ReadingEvent e;
  final Book? book;
  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final type = EventType.fromString(e.type) ?? EventType.deadline;
    return EventCardCompact(
      onTap: () => showEventDetailSheet(context, e, book: book),
      title: type.label(l),
      type: type,
      subtitle: _subtitle(context, e, l),
      bookTitle: book?.title,
      bookAuthor: book?.authors.firstOrNull,
      bookCoverUrl: book?.coverUrl,
      completed: e.status == EventStatus.completed,
    );
  }

  String _subtitle(BuildContext context, ReadingEvent e, AppL10n l) {
    final now = DateTime.now();
    final days = e.dateLocal
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (days == 0) return e.timeLocal ?? l.homeTodayLabel;
    if (days == 1) return l.homeTomorrowLabel;
    if (days > 0 && days < 7) return l.homeInDays(days);
    return formatDayMonth(context, e.dateLocal);
  }
}

class _ReadingBookTile extends ConsumerWidget {
  const _ReadingBookTile(this.b);
  final Book b;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider(b.id)).value;
    final page = progress?.currentPage;
    final chapter = progress?.currentChapter;
    final showPercent = shouldShowProgressPercentLabel(
      currentPage: page,
      currentPercentage: progress?.currentPercentage,
      pageCount: b.pageCount,
    );
    final pct = showPercent
        ? effectiveProgressPercent(
            currentPage: page,
            currentPercentage: progress?.currentPercentage,
            pageCount: b.pageCount,
          )
        : null;
    final hasOverlay = pct != null || page != null || chapter != null;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        rdPageRoute<void>(
          context,
          builder: (_) => BookDetailScreen(bookId: b.id),
        ),
      ),
      borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
      child: SizedBox(
        width: 88,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                BookCover(
                  title: b.title,
                  author: b.authors.isEmpty ? null : b.authors.first,
                  coverUrl: b.coverUrl,
                  color: context.colors.accent2,
                  rating: b.rating,
                  hasNotes: b.hasNotes,
                ),
                if (hasOverlay)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _CoverProgressBadge(
                      percent: pct,
                      currentPage: page,
                      currentChapter: chapter,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                b.title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
              ),
            ),
            if (b.authors.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                b.authors.first,
                style: TextStyle(fontSize: 11, color: context.colors.fg3),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CoverProgressBadge extends StatelessWidget {
  const _CoverProgressBadge({
    this.percent,
    this.currentPage,
    this.currentChapter,
  });
  final int? percent;
  final int? currentPage;
  final int? currentChapter;

  @override
  Widget build(BuildContext context) {
    final hasDetail = currentPage != null || currentChapter != null;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(6),
        bottomRight: Radius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(4, 3, 4, hasDetail ? 2 : 3),
            color: Colors.black.withValues(alpha: 0.55),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (percent != null)
                  Text(
                    '$percent%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                if (percent != null && hasDetail) const SizedBox(height: 2),
                if (hasDetail)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (currentPage != null) ...[
                          Icon(
                            LucideIcons.bookOpen,
                            size: 7,
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '$currentPage',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ],
                        if (currentPage != null && currentChapter != null)
                          Text(
                            '  ·  ',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 8,
                              height: 1,
                            ),
                          ),
                        if (currentChapter != null) ...[
                          Icon(
                            LucideIcons.bookmark,
                            size: 7,
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '$currentChapter',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (percent != null)
            SizedBox(
              height: 3,
              child: LayoutBuilder(
                builder: (_, c) => Row(
                  children: [
                    Container(
                      width: c.maxWidth * percent! / 100,
                      color: context.colors.accent,
                    ),
                    Expanded(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

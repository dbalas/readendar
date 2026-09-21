import 'package:flutter/material.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_motion.dart';
import 'package:readendar/core/utils/date_format.dart';
import 'package:readendar/core/utils/platform_chrome.dart';
import 'package:readendar/core/widgets/error_retry.dart';
import 'package:readendar/core/widgets/empty_state.dart';
import 'package:readendar/core/widgets/event_card_compact.dart';
import 'package:readendar/core/widgets/event_icon.dart';
import 'package:readendar/core/widgets/month_calendar.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_icon_button.dart';
import 'package:readendar/core/widgets/rd_create_action.dart';
import 'package:readendar/core/widgets/rd_date_picker.dart';
import 'package:readendar/core/widgets/rd_progress.dart';
import 'package:readendar/core/widgets/rd_segmented_control.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/calendar/event_detail_sheet.dart';
import 'package:readendar/features/calendar/event_form_screen.dart';
import 'package:readendar/features/filters/filter_icon_button.dart';
import 'package:readendar/features/filters/filters_state.dart';

/// The calendar's zoom level. All three share one anchor-based pager; the page
/// unit (month / week / day) changes with the view.
enum CalendarView { month, week, day }

// The empty icon's natural ListView position is 8px + EmptyState's 24px.
// Extend it to the first event-row baseline in calendar agendas.
const double _calendarEmptyStateRowOffset = 14;
const double _calendarLoadingIconTop =
    8.0 + 24.0 + _calendarEmptyStateRowOffset;

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({
    super.key,
    this.embedded = false,
    this.canCreate = true,
  });

  final bool embedded;
  final bool canCreate;
  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  static const _initialPage = 1200;
  // Recreated when the view (month/week/day) changes, since the page unit and
  // the base date it's anchored to change with it.
  late PageController _pager;
  // The date mapped to _initialPage; the anchor of the paging math.
  late DateTime _baseDate;
  // The currently-focused date (updated on every page change).
  late DateTime _anchor;
  CalendarView _view = CalendarView.month;
  // Month grid ("mapa") vs events list ("listado"), toggled from the app bar.
  // Only meaningful in the month view. Map first.
  bool _showList = false;
  // Covers the pager immediately when its next page begins moving, before its
  // target range becomes the active provider request in onPageChanged.
  bool _isPaging = false;
  int? _pageWhenPagingStarted;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _baseDate = DateTime(now.year, now.month);
    _anchor = _baseDate;
    _pager = PageController(initialPage: _initialPage);
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  // Start of the week containing [d], honoring the locale's first weekday
  // (Monday in Europe, Sunday in the US/Canada) so it matches the grid + header.
  // Uses this.State's context (only ever called post-mount, from build/paging).
  DateTime _weekStartOf(DateTime d) {
    final firstDow = firstDayOfWeekFor(context);
    return DateTime(d.year, d.month, d.day - leadingWeekdayOffset(d, firstDow));
  }

  // Normalizes an arbitrary date into the anchor a given view pages by.
  DateTime _normalizeFor(CalendarView v, DateTime d) => switch (v) {
    CalendarView.month => DateTime(d.year, d.month),
    CalendarView.week => _weekStartOf(d),
    CalendarView.day => DateTime(d.year, d.month, d.day),
  };

  CalendarEventRange _eventRangeFor(CalendarView view, DateTime anchor) {
    final from = _normalizeFor(view, anchor);
    final to = switch (view) {
      CalendarView.month => DateTime(from.year, from.month + 1),
      CalendarView.week => DateTime(from.year, from.month, from.day + 7),
      CalendarView.day => DateTime(from.year, from.month, from.day + 1),
    };
    return CalendarEventRange(from: from, to: to);
  }

  void _refreshRange(CalendarView view, DateTime anchor) {
    ref.invalidate(calendarEventsProvider(_eventRangeFor(view, anchor)));
  }

  // The date a pager page maps to, given the current view + base.
  DateTime _dateForPage(int page) {
    final delta = page - _initialPage;
    return switch (_view) {
      CalendarView.month => DateTime(_baseDate.year, _baseDate.month + delta),
      CalendarView.week => DateTime(
        _baseDate.year,
        _baseDate.month,
        _baseDate.day + 7 * delta,
      ),
      CalendarView.day => DateTime(
        _baseDate.year,
        _baseDate.month,
        _baseDate.day + delta,
      ),
    };
  }

  void _setView(CalendarView v) {
    if (v == _view) return;
    // Swap in a fresh pager (the page unit + base date change with the view) and
    // focus the current period. Dispose the outgoing one only AFTER this frame,
    // so the old PageView has detached from it first (disposing mid-rebuild
    // throws "used after dispose").
    final old = _pager;
    final now = DateTime.now();
    setState(() {
      _baseDate = _normalizeFor(v, now);
      _anchor = _baseDate;
      _view = v;
      _isPaging = false;
      _pager = PageController(initialPage: _initialPage);
    });
    _refreshRange(v, _anchor);
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  void _focusDate(DateTime target) {
    // Leave a pre-mount request pending; build watches it again after the pager
    // attaches, then this callback moves directly to the requested period.
    if (!mounted || !_pager.hasClients) return;
    setState(() {
      _baseDate = _normalizeFor(_view, target);
      _anchor = _baseDate;
      _isPaging = false;
    });
    _refreshRange(_view, _anchor);
    _pager.jumpToPage(_initialPage);
    ref.read(calendarFocusProvider.notifier).state = null;
  }

  void _beginPaging() {
    if (_isPaging) return;
    _pageWhenPagingStarted = _pager.hasClients ? _pager.page?.round() : null;
    setState(() => _isPaging = true);
  }

  void _finishPagingIfPeriodDidNotChange() {
    if (!_isPaging || !_pager.hasClients) return;
    final page = _pager.page?.round();
    if (page != null && page == _pageWhenPagingStarted) {
      setState(() => _isPaging = false);
    }
  }

  Future<void> _goPrev() {
    _beginPaging();
    return _pager.previousPage(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : ReadendarMotion.standard,
      curve: ReadendarMotion.curve,
    );
  }

  Future<void> _goNext() {
    _beginPaging();
    return _pager.nextPage(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : ReadendarMotion.standard,
      curve: ReadendarMotion.curve,
    );
  }

  // Opens a date picker so the user can jump to any month/year (or day) at
  // once. A "Reset" action inside the modal jumps straight back to today.
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showRdDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    _focusDate(picked);
  }

  String _headerLabel(BuildContext context) => switch (_view) {
    CalendarView.month => formatMonthYearShort(context, _anchor),
    // Calendar arithmetic, not Duration(days: 6): a fixed 6×24h offset lands on
    // Saturday 23:00 across a DST fall-back, printing the wrong end day (and
    // disagreeing with WeekStrip, which builds its 7 days the same way).
    CalendarView.week =>
      '${formatDayMonth(context, _anchor)} – '
          '${formatDayMonth(context, DateTime(_anchor.year, _anchor.month, _anchor.day + 6))}',
    CalendarView.day => formatMediumDate(context, _anchor),
  };

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    // When a flow (e.g. the reading-plan completion) asks the calendar to land
    // on a specific date, jump there after the frame. Watching (not listening)
    // means a request set before this screen mounts — or while the events are
    // still loading and the PageView isn't built — is retried on later builds
    // until `_focusDate` succeeds and clears it.
    final focusTarget = ref.watch(calendarFocusProvider);
    if (focusTarget != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _focusDate(focusTarget),
      );
    }
    final eventRange = _eventRangeFor(_view, _anchor);
    final calendarCache = ref.watch(calendarEventsCacheProvider);
    // Home already owns a complete wide event feed for the current session.
    // Reuse the slice for an instant first Calendar frame, then let the exact
    // visible-period request below refresh it. Do not start the wide feed here
    // solely for this optimization.
    if (ref.exists(upcomingEventsProvider)) {
      calendarCache.seedFromUpcomingIfReady(
        eventRange,
        ref.watch(upcomingEventsProvider),
      );
    }
    final events = ref.watch(calendarEventsProvider(eventRange));
    final cachedEvents = calendarCache.read(eventRange);
    final books = ref.watch(booksProvider);
    final bookList = books.value ?? const <Book>[];
    final eventContext = EventRenderContext(personalBooks: bookList);
    final filters = ref.watch(filtersProvider);
    // Filtered once here and shared by every page's itemBuilder (each page slices
    // this list, not the raw feed). NOTE: a swipe calls setState(_anchor=…) to
    // relabel the header, which re-runs this filter — cheap for the expected
    // handful of events; revisit (memoize on events+filters) if that grows.
    final periodEvents = calendarCache.visibleFor(eventRange, events);
    final visibleEvents = periodEvents
        .where((e) => _matchesFilters(e, filters, eventContext, l))
        .toList(growable: false);
    final periodPager = PageView.builder(
      // A new controller alone can retain the outgoing PageView's in-flight page
      // during a quick view change. Re-key it by page unit so the freshly reset
      // controller always builds today's period as well as its header.
      key: ValueKey(_view),
      controller: _pager,
      onPageChanged: (page) {
        final next = _dateForPage(page);
        if (next == _anchor) return;
        setState(() {
          _anchor = next;
          _isPaging = false;
        });
        _refreshRange(_view, next);
      },
      itemBuilder: (context, page) {
        final date = _dateForPage(page);
        void openDay(DateTime day, List<ReadingEvent> dayEvents) =>
            _onDayTap(context, ref, day, dayEvents, eventContext);
        return switch (_view) {
          CalendarView.month => _MonthView(
            month: DateTime(date.year, date.month),
            events: visibleEvents,
            eventContext: eventContext,
            eventsTitle: l.calendarEventsTitle,
            emptyText: l.calendarMonthNoEvents,
            showList: _showList,
            onOpenDay: openDay,
            bottomInset: widget.embedded
                ? 0
                : rdFloatingNavContentInset(context),
          ),
          CalendarView.week => _WeekView(
            weekStart: date,
            events: visibleEvents,
            eventContext: eventContext,
            eventsTitle: l.calendarWeekEventsTitle,
            emptyText: l.calendarWeekNoEvents,
            onOpenDay: openDay,
            bottomInset: widget.embedded
                ? 0
                : rdFloatingNavContentInset(context),
          ),
          CalendarView.day => _DayView(
            day: date,
            events: visibleEvents,
            eventContext: eventContext,
            emptyText: l.calendarDayNoEvents,
            addLabel: l.actionAddEvent,
            onOpenDay: openDay,
            bottomInset: widget.embedded
                ? 0
                : rdFloatingNavContentInset(context),
          ),
        };
      },
    );
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final loadingOverlay = ColoredBox(
      key: const ValueKey('calendar-loading'),
      color: Theme.of(context).scaffoldBackgroundColor,
      // Month-list and day empty states start after the ListView's 8px inset
      // plus EmptyState's 24px padding. Keep the loading indicator in that
      // exact 36px icon slot to avoid a visual jump.
      child: Padding(
        padding: const EdgeInsets.only(top: _calendarLoadingIconTop),
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox.square(
            dimension: 36,
            child: RdProgress(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
      ),
    );
    final isMonthGrid = _view == CalendarView.month && !_showList;
    const readyOverlay = SizedBox.shrink(
      key: ValueKey('calendar-ready'),
    );
    final periodOverlay = isMonthGrid
        // The grid is already useful navigation context. Keep its day cells
        // visible while the target period's event markers arrive.
        ? events.when(
            skipLoadingOnRefresh: true,
            skipError: true,
            loading: () => readyOverlay,
            error: (error, _) => cachedEvents == null || cachedEvents.isEmpty
                ? ErrorRetry(
                    error: error,
                    onRetry: () => _refreshRange(_view, _anchor),
                  )
                : readyOverlay,
            data: (_) => readyOverlay,
          )
        : _isPaging
        ? loadingOverlay
        : events.when(
            skipLoadingOnRefresh: true,
            skipError: true,
            loading: () => cachedEvents == null ? loadingOverlay : readyOverlay,
            error: (error, _) => cachedEvents == null || cachedEvents.isEmpty
                ? ErrorRetry(
                    error: error,
                    onRetry: () => _refreshRange(_view, _anchor),
                  )
                : readyOverlay,
            data: (_) => readyOverlay,
          );
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(
                l.navCalendar,
                overflow: TextOverflow.visible,
                softWrap: false,
              ),
              actions: [
                // Map/list toggle only applies to the month grid.
                if (_view == CalendarView.month)
                  RdIconButton(
                    icon: _showList
                        ? LucideIcons.calendarDays
                        : LucideIcons.list,
                    tooltip: _showList ? l.calendarShowMap : l.calendarShowList,
                    onPressed: () => setState(() => _showList = !_showList),
                  ),
                FilterIconButton(
                  active: !filters.isEmpty,
                  calendarOnly: true,
                ),
                if (widget.canCreate)
                  ...RdCreateAction.appBarActions(
                    context: context,
                    onPressed: () => _createEventForDay(context, ref, _anchor),
                    tooltip: l.actionAddEvent,
                  ),
                const SizedBox(width: 4),
              ],
            ),
      body: Column(
        children: [
          _CalendarHeader(
            label: _headerLabel(context),
            view: _view,
            onPrev: _goPrev,
            onNext: _goNext,
            onPickDate: _pickDate,
            onViewChanged: _setView,
            monthLabel: l.calendarViewMonth,
            weekLabel: l.calendarViewWeek,
            dayLabel: l.calendarViewDay,
          ),
          Expanded(
            // Keep the pager mounted while a newly visited period loads. The
            // opaque overlay hides its empty shell but does not interrupt the
            // horizontal motion; it then fades out over the loaded data.
            child: Stack(
              fit: StackFit.expand,
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.axis != Axis.horizontal) {
                      return false;
                    }
                    if (notification is ScrollStartNotification) {
                      _beginPaging();
                    } else if (notification is ScrollEndNotification) {
                      _finishPagingIfPeriodDidNotChange();
                    }
                    return false;
                  },
                  child: periodPager,
                ),
                AnimatedSwitcher(
                  duration: reduceMotion ? Duration.zero : ReadendarMotion.fast,
                  switchInCurve: ReadendarMotion.curve,
                  switchOutCurve: Curves.easeInCubic,
                  child: periodOverlay,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: widget.canCreate
          ? RdCreateAction.fab(
              context: context,
              forceFab: widget.embedded,
              onPressed: () => _createEventForDay(context, ref, _anchor),
              tooltip: l.actionAddEvent,
            )
          : null,
    );
  }

  Future<void> _createEventForDay(
    BuildContext context,
    WidgetRef ref,
    DateTime day,
  ) async {
    final saved = await Navigator.of(context).push<bool>(
      rdPageRoute<bool>(
        context,
        builder: (_) => EventFormScreen(defaultDate: day),
      ),
    );
    if (saved ?? false) {
      _refreshRange(_view, _anchor);
      ref
        ..invalidate(upcomingEventsProvider)
        ..invalidate(booksProvider);
    }
  }

  /// Tapping a day dispatches on how many events it holds:
  /// - none   → jump straight into creation for that day,
  /// - one    → open that event's detail sheet,
  /// - several → push a per-day list (date as title, back button) that reuses
  ///   the same event rows as the calendar.
  void _onDayTap(
    BuildContext context,
    WidgetRef ref,
    DateTime day,
    List<ReadingEvent> dayEvents,
    EventRenderContext eventContext,
  ) {
    if (dayEvents.isEmpty) {
      _createEventForDay(context, ref, day);
      return;
    }
    final sorted = [...dayEvents]..sort(byEventTime);
    if (sorted.length == 1) {
      final e = sorted.first;
      showEventDetailSheet(context, e, book: eventContext.bookFor(e));
      return;
    }
    Navigator.of(context).push(
      rdPageRoute<void>(
        context,
        builder: (_) => DayEventsScreen(
          day: day,
          eventContext: eventContext,
        ),
      ),
    );
  }

  bool _matchesFilters(
    ReadingEvent e,
    FiltersState filters,
    EventRenderContext eventContext,
    AppL10n l,
  ) => matchesCalendarEventFilters(e, filters, eventContext, l);
}

/// Shared by [CalendarScreen] and [DayEventsScreen] so day agendas stay in sync
/// with the calendar filters.
bool matchesCalendarEventFilters(
  ReadingEvent e,
  FiltersState filters,
  EventRenderContext eventContext,
  AppL10n l,
) {
  if (filters.eventTypes.isNotEmpty && !filters.eventTypes.contains(e.type)) {
    return false;
  }
  if (filters.from != null && e.dateLocal.isBefore(filters.from!)) {
    return false;
  }
  if (filters.to != null && e.dateLocal.isAfter(filters.to!)) {
    return false;
  }
  if (filters.completedOnly && e.status != EventStatus.completed) {
    return false;
  }
  if (filters.uncompletedOnly && e.status == EventStatus.completed) {
    return false;
  }
  final book = eventContext.bookFor(e);
  final query = filters.query.trim().toLowerCase();
  if (query.isEmpty) return true;
  final type = EventType.fromString(e.type) ?? EventType.deadline;
  return e.title.toLowerCase().contains(query) ||
      type.label(l).toLowerCase().contains(query) ||
      e.description.toLowerCase().contains(query) ||
      (e.targetChapter?.toString().contains(query) ?? false) ||
      (book?.title.toLowerCase().contains(query) ?? false);
}

/// All-day events first, then timed events in chronological order. Shared by the
/// day-tap dispatch and the day / overflow agendas so they never diverge.
int byEventTime(ReadingEvent a, ReadingEvent b) {
  final ta = a.timeLocal;
  final tb = b.timeLocal;
  if (ta == null && tb == null) return 0;
  if (ta == null) return -1;
  if (tb == null) return 1;
  return ta.compareTo(tb);
}

/// One event row as shown in every calendar agenda (month list, week, day, and
/// the per-day overflow screen): resolves the event's book/type and builds
/// the shared [EventCardCompact]. Only [subtitle] varies between callers.
Widget _eventRow(
  BuildContext context,
  ReadingEvent e,
  EventRenderContext eventContext, {
  String? subtitle,
}) {
  final book = eventContext.bookFor(e);
  final type = EventType.fromString(e.type) ?? EventType.deadline;
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
    child: EventCardCompact(
      onTap: () => showEventDetailSheet(context, e, book: book),
      title: type.label(AppL10n.of(context)),
      type: type,
      subtitle: subtitle,
      bookTitle: book?.title,
      bookAuthor: book?.authors.firstOrNull,
      bookCoverUrl: book?.coverUrl,
      completed: e.status == EventStatus.completed,
    ),
  );
}

/// Lazy agenda for hundreds of events. Empty/header chrome stays a short
/// eager [ListView] so empty-state alignment tests keep their pixel contract.
Widget _eventAgendaList({
  required BuildContext context,
  required List<ReadingEvent> events,
  required EventRenderContext eventContext,
  required String? Function(ReadingEvent event) subtitleOf,
  required EdgeInsetsGeometry padding,
  List<Widget> leading = const [],
  Widget? empty,
  bool bottomSpacer = true,
}) {
  if (events.isEmpty) {
    return ListView(
      padding: padding,
      children: [
        ...leading,
        ?empty,
        if (bottomSpacer) const SizedBox(height: 96),
      ],
    );
  }
  return ListView.builder(
    padding: padding,
    itemCount: leading.length + events.length + (bottomSpacer ? 1 : 0),
    itemBuilder: (context, index) {
      if (index < leading.length) return leading[index];
      final eventIndex = index - leading.length;
      if (eventIndex >= events.length) {
        return const SizedBox(height: 96);
      }
      final event = events[eventIndex];
      return _eventRow(
        context,
        event,
        eventContext,
        subtitle: subtitleOf(event),
      );
    },
  );
}

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.month,
    required this.events,
    required this.eventContext,
    required this.eventsTitle,
    required this.emptyText,
    required this.showList,
    required this.onOpenDay,
    this.bottomInset = 0,
  });
  final DateTime month;
  final List<ReadingEvent> events;
  final EventRenderContext eventContext;
  final String eventsTitle;
  final String emptyText;
  // false → calendar grid only ("mapa"); true → events list only ("listado").
  final bool showList;
  final void Function(DateTime day, List<ReadingEvent> events) onOpenDay;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final monthEvents = events
        .where(
          (x) =>
              x.dateLocal.year == month.year &&
              x.dateLocal.month == month.month,
        )
        .toList();
    final padding = EdgeInsets.only(top: 8, bottom: bottomInset);
    if (!showList) {
      return ListView(
        padding: padding,
        children: [
          MonthGrid(
            month: month,
            events: events,
            eventContext: eventContext,
            onOpenDay: onOpenDay,
          ),
          const SizedBox(height: 96),
        ],
      );
    }
    return _eventAgendaList(
      context: context,
      events: monthEvents,
      eventContext: eventContext,
      subtitleOf: (e) => formatDayMonth(context, e.dateLocal),
      padding: padding,
      leading: [
        if (monthEvents.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              eventsTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
      ],
      empty: Padding(
        padding: const EdgeInsets.only(top: _calendarEmptyStateRowOffset),
        child: EmptyState(
          icon: LucideIcons.calendarRange,
          message: emptyText,
        ),
      ),
    );
  }
}

/// The relocated month/week/day selector: prev / tappable label (opens a date
/// picker) / next, plus a month·week·day view switch. Lives above the calendar
/// body now (it used to sit cramped in the app bar).
class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.label,
    required this.view,
    required this.onPrev,
    required this.onNext,
    required this.onPickDate,
    required this.onViewChanged,
    required this.monthLabel,
    required this.weekLabel,
    required this.dayLabel,
  });

  final String label;
  final CalendarView view;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPickDate;
  final ValueChanged<CalendarView> onViewChanged;
  final String monthLabel;
  final String weekLabel;
  final String dayLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ml = MaterialLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      child: Column(
        children: [
          Row(
            children: [
              RdIconButton(
                icon: LucideIcons.chevronLeft,
                tooltip: ml.previousPageTooltip,
                onPressed: onPrev,
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onPickDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: AnimatedSwitcher(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : ReadendarMotion.fast,
                            switchInCurve: ReadendarMotion.curve,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.12),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                            child: Text(
                              label,
                              key: ValueKey(label),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          LucideIcons.chevronDown,
                          size: 16,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              RdIconButton(
                icon: LucideIcons.chevronRight,
                tooltip: ml.nextPageTooltip,
                onPressed: onNext,
              ),
            ],
          ),
          const SizedBox(height: 4),
          RdSegmentedControl<CalendarView>(
            selected: view,
            onChanged: onViewChanged,
            segments: [
              RdSegment(value: CalendarView.month, label: monthLabel),
              RdSegment(value: CalendarView.week, label: weekLabel),
              RdSegment(value: CalendarView.day, label: dayLabel),
            ],
          ),
        ],
      ),
    );
  }
}

/// One week: a week strip (7 day cells, same visuals as the month grid) above a
/// compact agenda of that week's events.
class _WeekView extends StatelessWidget {
  const _WeekView({
    required this.weekStart,
    required this.events,
    required this.eventContext,
    required this.eventsTitle,
    required this.emptyText,
    required this.onOpenDay,
    this.bottomInset = 0,
  });

  final DateTime weekStart;
  final List<ReadingEvent> events;
  final EventRenderContext eventContext;
  final String eventsTitle;
  final String emptyText;
  final void Function(DateTime day, List<ReadingEvent> events) onOpenDay;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final weekEndExclusive = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + 7,
    );
    final weekStartDay = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );
    final weekEvents = events.where((e) {
      final d = DateTime(e.dateLocal.year, e.dateLocal.month, e.dateLocal.day);
      return !d.isBefore(weekStartDay) && d.isBefore(weekEndExclusive);
    }).toList()..sort((a, b) => a.dateLocal.compareTo(b.dateLocal));
    return _eventAgendaList(
      context: context,
      events: weekEvents,
      eventContext: eventContext,
      subtitleOf: (e) => formatDayMonth(context, e.dateLocal),
      padding: EdgeInsets.only(top: 8, bottom: bottomInset),
      leading: [
        WeekStrip(
          weekStart: weekStart,
          events: events,
          eventContext: eventContext,
          onOpenDay: onOpenDay,
        ),
        const SizedBox(height: 12),
        if (weekEvents.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              eventsTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
      ],
      empty: Padding(
        padding: const EdgeInsets.only(top: _calendarEmptyStateRowOffset),
        child: EmptyState(
          icon: LucideIcons.calendarDays,
          message: emptyText,
        ),
      ),
    );
  }
}

/// One day: an agenda of the day's events (or an empty state with a quick
/// "add event" for that day).
class _DayView extends StatelessWidget {
  const _DayView({
    required this.day,
    required this.events,
    required this.eventContext,
    required this.emptyText,
    required this.addLabel,
    required this.onOpenDay,
    this.bottomInset = 0,
  });

  final DateTime day;
  final List<ReadingEvent> events;
  final EventRenderContext eventContext;
  final String emptyText;
  final String addLabel;
  final void Function(DateTime day, List<ReadingEvent> events) onOpenDay;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final dayEvents = events.where((e) {
      return e.dateLocal.year == day.year &&
          e.dateLocal.month == day.month &&
          e.dateLocal.day == day.day;
    }).toList()..sort(byEventTime);
    return _eventAgendaList(
      context: context,
      events: dayEvents,
      eventContext: eventContext,
      subtitleOf: (e) => e.isAllDay ? null : e.timeLocal,
      padding: EdgeInsets.only(top: 8, bottom: bottomInset),
      empty: Padding(
        padding: const EdgeInsets.only(top: _calendarEmptyStateRowOffset),
        child: EmptyState(
          icon: LucideIcons.calendar,
          message: emptyText,
          action: RdButton.secondary(
            onPressed: () => onOpenDay(day, const []),
            icon: LucideIcons.calendarPlus,
            label: addLabel,
          ),
        ),
      ),
    );
  }
}

/// Read-only list of every event on a single day, opened when a calendar cell
/// holds more than one event. The date is the title; the rows reuse the same
/// [EventCardCompact] as the calendar, and tapping one opens its detail sheet.
class DayEventsScreen extends ConsumerWidget {
  const DayEventsScreen({
    required this.day,
    required this.eventContext,
    super.key,
  });

  final DateTime day;
  final EventRenderContext eventContext;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final range = CalendarEventRange(
      from: DateTime(day.year, day.month, day.day),
      to: DateTime(day.year, day.month, day.day + 1),
    );
    final calendarCache = ref.watch(calendarEventsCacheProvider);
    final eventsAsync = ref.watch(calendarEventsProvider(range));
    final periodEvents = calendarCache.visibleFor(range, eventsAsync);
    final filters = ref.watch(filtersProvider);
    final dayEvents =
        periodEvents
            .where((e) => _sameDay(e.dateLocal, day))
            .where(
              (e) => matchesCalendarEventFilters(e, filters, eventContext, l),
            )
            .toList()
          ..sort(byEventTime);

    final title = MaterialLocalizations.of(context).formatFullDate(day);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: dayEvents.isEmpty
          ? EmptyState(
              icon: LucideIcons.calendarX,
              message: l.calendarDayNoEvents,
            )
          : _eventAgendaList(
              context: context,
              events: dayEvents,
              eventContext: eventContext,
              subtitleOf: (e) => e.isAllDay ? null : e.timeLocal,
              padding: const EdgeInsets.symmetric(vertical: 8),
              bottomSpacer: false,
            ),
    );
  }
}

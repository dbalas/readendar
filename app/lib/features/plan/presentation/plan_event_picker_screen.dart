import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/utils/date_format.dart';
import 'package:readendar/core/widgets/empty_state.dart';
import 'package:readendar/core/widgets/event_card_compact.dart';
import 'package:readendar/core/widgets/event_icon.dart';
import 'package:readendar/core/widgets/month_calendar.dart';
import 'package:readendar/core/widgets/rd_date_picker.dart';
import 'package:readendar/core/widgets/rd_icon_button.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:readendar/core/widgets/rd_progress.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/calendar/calendar_screen.dart';
import 'package:readendar/features/calendar/event_detail_sheet.dart';

/// Full-screen calendar for picking an existing event as a plan finish day.
/// Reuses [MonthGrid] and the same event cards / detail sheet as Calendar,
/// but read-only: empty days cannot be selected.
class PlanEventPickerScreen extends ConsumerStatefulWidget {
  const PlanEventPickerScreen({super.key});

  @override
  ConsumerState<PlanEventPickerScreen> createState() =>
      _PlanEventPickerScreenState();
}

class _PlanEventPickerScreenState extends ConsumerState<PlanEventPickerScreen> {
  late final ValueNotifier<DateTime> _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = ValueNotifier(DateTime(now.year, now.month));
  }

  @override
  void dispose() {
    _month.dispose();
    super.dispose();
  }

  CalendarEventRange _rangeFor(DateTime month) {
    final from = DateTime(month.year, month.month);
    return CalendarEventRange(
      from: from,
      to: DateTime(from.year, from.month + 1),
    );
  }

  void _focusMonth(DateTime month) {
    final next = DateTime(month.year, month.month);
    if (next == _month.value) return;
    _month.value = next;
    ref.invalidate(calendarEventsProvider(_rangeFor(next)));
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showRdDatePicker(
      context: context,
      initialDate: _month.value,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    _focusMonth(picked);
  }

  void _select(ReadingEvent event) {
    if (!mounted) return;
    Navigator.of(context).pop(event);
  }

  void _openEvent(ReadingEvent event, EventRenderContext ctx) {
    showEventDetailSheet(
      context,
      event,
      book: ctx.bookFor(event),
      onPlanUntilHere: _select,
    );
  }

  void _onDayTap(
    DateTime day,
    List<ReadingEvent> dayEvents,
    EventRenderContext ctx,
  ) {
    final l = AppL10n.of(context);
    if (dayEvents.isEmpty) {
      showRdToast(
        context,
        message: l.planPickEventEmptyDay,
      );
      return;
    }
    final sorted = [...dayEvents]..sort(byEventTime);
    if (sorted.length == 1) {
      _openEvent(sorted.first, ctx);
      return;
    }
    Navigator.of(context).push<void>(
      rdPageRoute<void>(
        context,
        builder: (_) => _PickerDayEventsScreen(
          day: day,
          events: sorted,
          eventContext: ctx,
          onSelect: _select,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final ml = MaterialLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.planPickEventTitle)),
      body: ValueListenableBuilder<DateTime>(
        valueListenable: _month,
        builder: (context, month, _) {
          final range = _rangeFor(month);
          final eventsAsync = ref.watch(calendarEventsProvider(range));
          final cache = ref.watch(calendarEventsCacheProvider);
          final events = cache.visibleFor(range, eventsAsync);
          final books = ref.watch(booksProvider).value ?? const <Book>[];
          final ctx = EventRenderContext(personalBooks: books);
          final loading = eventsAsync.isLoading && cache.read(range) == null;

          Widget body;
          if (loading) {
            body = RdProgress.centered();
          } else if (events.isEmpty) {
            body = EmptyState(
              icon: LucideIcons.calendarRange,
              message: l.planPickEventEmptyMonth,
            );
          } else {
            body = MonthGrid(
              month: month,
              events: events,
              eventContext: ctx,
              onOpenDay: (day, dayEvents) => _onDayTap(day, dayEvents, ctx),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  l.planPickEventHint,
                  style: TextStyle(fontSize: 12.5, color: context.colors.fg3),
                ),
              ),
              Row(
                children: [
                  RdIconButton(
                    tooltip: ml.previousMonthTooltip,
                    icon: LucideIcons.chevronLeft,
                    onPressed: () => _focusMonth(
                      DateTime(month.year, month.month - 1),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _pickMonth,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                formatMonthYearShort(context, month),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              LucideIcons.chevronDown,
                              size: 16,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  RdIconButton(
                    tooltip: ml.nextMonthTooltip,
                    icon: LucideIcons.chevronRight,
                    onPressed: () => _focusMonth(
                      DateTime(month.year, month.month + 1),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: GestureDetector(
                  onHorizontalDragEnd: (details) {
                    final v = details.primaryVelocity;
                    if (v == null || v == 0) return;
                    _focusMonth(
                      DateTime(month.year, month.month + (v < 0 ? 1 : -1)),
                    );
                  },
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    child: body,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PickerDayEventsScreen extends StatelessWidget {
  const _PickerDayEventsScreen({
    required this.day,
    required this.events,
    required this.eventContext,
    required this.onSelect,
  });

  final DateTime day;
  final List<ReadingEvent> events;
  final EventRenderContext eventContext;
  final ValueChanged<ReadingEvent> onSelect;

  @override
  Widget build(BuildContext context) {
    final title = MaterialLocalizations.of(context).formatFullDate(day);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ...events.map((e) {
            final book = eventContext.bookFor(e);
            final type = EventType.fromString(e.type) ?? EventType.deadline;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: EventCardCompact(
                onTap: () => showEventDetailSheet(
                  context,
                  e,
                  book: book,
                  onPlanUntilHere: (selected) {
                    Navigator.of(context).pop(); // day list
                    onSelect(selected);
                  },
                ),
                title: type.label(AppL10n.of(context)),
                type: type,
                subtitle: e.isAllDay ? null : e.timeLocal,
                bookTitle: book?.title,
                bookAuthor: book?.authors.firstOrNull,
                bookCoverUrl: book?.coverUrl,
                completed: e.status == EventStatus.completed,
              ),
            );
          }),
        ],
      ),
    );
  }
}

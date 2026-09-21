// Shared book-events list body — used by the book-detail Eventos tab.
// Same rows / empty art as the former BookEventsScreen.
// Create lives on the parent FAB / AppBar + (RdCreateAction), not the empty CTA.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/utils/date_format.dart';
import 'package:readendar/core/widgets/empty_state.dart';
import 'package:readendar/core/widgets/error_retry.dart';
import 'package:readendar/core/widgets/event_card_compact.dart';
import 'package:readendar/core/widgets/event_icon.dart';
import 'package:readendar/core/widgets/rd_progress.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/calendar/book_events_empty_art.dart';
import 'package:readendar/features/calendar/event_detail_sheet.dart';

/// Events list for one personal book.
class BookEventsListBody extends ConsumerWidget {
  const BookEventsListBody({
    required this.bookId,
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 24),
  });

  final String bookId;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final bookAsync = ref.watch(bookViewProvider(bookId));
    final events = ref.watch(eventsForBookProvider(bookId));

    return bookAsync.when(
      skipError: bookAsync.hasValue,
      skipLoadingOnReload: bookAsync.hasValue,
      loading: RdProgress.centered,
      error: (e, _) => ErrorRetry(
        error: e,
        onRetry: () => ref.invalidate(bookViewProvider(bookId)),
      ),
      data: (b) => events.when(
        skipError: true,
        loading: RdProgress.centered,
        error: (e, _) => ErrorRetry(
          error: e,
          onRetry: () => ref.invalidate(eventsForBookProvider(bookId)),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              illustration: const BookEventsEmptyArt(),
              message: l.emptyEvents,
            );
          }
          return ListView.separated(
            padding: padding,
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final e = list[i];
              final eventType =
                  EventType.fromString(e.type) ?? EventType.deadline;
              return GestureDetector(
                onTap: () => showEventDetailSheet(context, e, book: b),
                child: EventCardCompact(
                  title: eventType.label(l),
                  type: eventType,
                  subtitle: formatDayMonth(context, e.dateLocal),
                  bookTitle: b.title,
                  bookAuthor: b.authors.firstOrNull,
                  bookCoverUrl: b.coverUrl,
                  completed: e.status == EventStatus.completed,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

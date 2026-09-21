import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/error/failure_exception.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/error_retry.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/calendar/book_events_screen.dart';

Widget _wrap(Book book, List<ReadingEvent> events) => ProviderScope(
  overrides: [
    bookProvider(book.id).overrideWith((ref) async => book),
    eventsForBookProvider(
      book.id,
    ).overrideWith((ref) => AsyncValue.data(events)),
  ],
  child: MaterialApp(
    locale: const Locale('es'),
    theme: buildLightTheme(),
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: BookEventsScreen(bookId: book.id),
  ),
);

void main() {
  final book = Book(
    id: 'book-1',
    ownerType: 'user',
    ownerId: 'user-1',
    title: 'Pedro Paramo',
    authors: const ['Juan Rulfo'],
    status: BookStatus.reading,
    pageCount: 120,
  );

  testWidgets('renders the events list without layout errors', (tester) async {
    final events = [
      ReadingEvent(
        id: 'e1',
        ownerType: 'user',
        ownerId: 'user-1',
        bookId: book.id,
        type: 'page_milestone',
        title: 'Read to page 80',
        dateLocal: DateTime.utc(2026, 6, 12),
        status: EventStatus.active,
      ),
      ReadingEvent(
        id: 'e2',
        ownerType: 'user',
        ownerId: 'user-1',
        bookId: book.id,
        type: 'finish',
        title: 'Fin',
        dateLocal: DateTime.utc(2026, 6, 20),
        status: EventStatus.completed,
      ),
    ];

    await tester.pumpWidget(_wrap(book, events));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Eventos'), findsOneWidget); // app bar title
    // Personal book: create lives on RdCreateAction (FAB on Material).
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byTooltip('Añadir evento'), findsOneWidget);
    expect(find.text('Sin eventos.'), findsNothing);
  });

  testWidgets('empty state shows a placeholder; add lives on FAB', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(book, const []));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('Aún no hay eventos para este libro'),
      findsOneWidget,
    );
    // No duplicate CTA in the empty pane — Material add is the FAB only.
    expect(find.text('Añadir evento'), findsNothing);
    final fab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(fab.tooltip, 'Añadir evento');
  });

  testWidgets('event load failure shows ErrorRetry instead of empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookProvider(book.id).overrideWith((ref) async => book),
          eventsForBookProvider(book.id).overrideWith(
            (ref) => AsyncValue<List<ReadingEvent>>.error(
              const FailureException(NetworkFailure()),
              StackTrace.empty,
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: BookEventsScreen(bookId: book.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ErrorRetry), findsOneWidget);
    expect(
      find.textContaining('Aún no hay eventos para este libro'),
      findsNothing,
    );
  });
}

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/library/book_field_cards.dart';
import 'package:readendar/features/library/book_status_history_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../quotes/quotes_test_utils.dart';

void main() {
  testWidgets('renders newest status and viewer-timezone date', (
    tester,
  ) async {
    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Libro',
      authors: const ['Autor'],
      status: 'reading',
    );
    final repo = _HistoryRepository(
      BookStatusHistoryPage(
        items: [
          BookStatusHistoryEntry(
            id: 'h-new',
            status: 'reading',
            changedAt: DateTime.parse('2026-07-19T22:30:00Z'),
          ),
          BookStatusHistoryEntry(
            id: 'h-old',
            status: 'pending',
            changedAt: DateTime.parse('2026-07-18T12:00:00Z'),
            isBaseline: true,
          ),
        ],
      ),
    );

    await tester.pumpWidget(_app(book, repo));
    await tester.pumpAndSettle();

    expect(find.text('Historial de estados'), findsOneWidget);
    expect(find.text('Leyendo'), findsOneWidget);
    expect(
      find.text('Estado registrado al activar el historial'),
      findsOneWidget,
    );
    // 22:30 UTC is already the next civil day in the default viewer timezone
    // (Europe/Madrid), and only that localized date is shown.
    expect(find.textContaining('20 jul 2026'), findsOneWidget);

    final readingCard = find
        .ancestor(of: find.text('Leyendo'), matching: find.byType(RdCard))
        .first;
    final statusIcon = find.descendant(
      of: readingCard,
      matching: find.byType(BookFieldLeadingIcon),
    );
    expect(
      tester.getCenter(find.text('Leyendo')).dy,
      closeTo(tester.getCenter(statusIcon).dy, 0.01),
    );
    expect(find.byIcon(LucideIcons.pencil), findsNothing);
  });

  testWidgets('edit date patches locally and reorders without refetch', (
    tester,
  ) async {
    final book = Book(
      id: 'personal-book',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Libro',
      authors: const ['Autor'],
      status: 'reading',
    );
    final older = BookStatusHistoryEntry(
      id: 'h-old',
      status: 'pending',
      changedAt: DateTime.utc(2026, 7, 10, 12),
    );
    final newer = BookStatusHistoryEntry(
      id: 'h-new',
      status: 'reading',
      changedAt: DateTime.utc(2026, 7, 18, 12),
    );
    final repo = _HistoryRepository(
      BookStatusHistoryPage(items: [newer, older]),
    );

    await tester.pumpWidget(_app(book, repo, canEdit: true));
    await tester.pumpAndSettle();

    expect(find.text('Leyendo'), findsOneWidget);
    expect(find.byIcon(LucideIcons.pencil), findsNWidgets(2));

    // Edit the older "Pendiente" row so it becomes newest.
    final pendingCard = find
        .ancestor(of: find.text('Pendiente'), matching: find.byType(RdCard))
        .first;
    await tester.tap(
      find.descendant(
        of: pendingCard,
        matching: find.byIcon(LucideIcons.pencil),
      ),
    );
    await tester.pumpAndSettle();

    // Material date picker: jump to 20 jul 2026 and confirm.
    await tester.tap(find.text('20').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ACEPTAR'));
    await tester.pumpAndSettle();

    expect(repo.updateCalls, 1);
    expect(repo.lastUpdatedEntryId, 'h-old');
    expect(repo.calls, 1); // no refetch
    expect(find.text('Fecha del estado actualizada'), findsOneWidget);

    final pendingTop = tester.getTopLeft(find.text('Pendiente')).dy;
    final readingTop = tester.getTopLeft(find.text('Leyendo')).dy;
    expect(pendingTop, lessThan(readingTop));
  });

  testWidgets('an inferred date can be confirmed without changing its day', (
    tester,
  ) async {
    final book = Book(
      id: 'personal-book',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Libro',
      authors: const ['Autor'],
      status: 'read',
    );
    final repo = _HistoryRepository(
      BookStatusHistoryPage(
        items: [
          BookStatusHistoryEntry(
            id: 'h-unknown',
            status: 'read',
            changedAt: DateTime.utc(2026, 7, 18, 12),
            dateConfirmed: false,
          ),
        ],
      ),
    );

    await tester.pumpWidget(_app(book, repo, canEdit: true));
    await tester.pumpAndSettle();
    const unconfirmedCopy =
        'Esta fecha se ha inferido. Confírmala o corrígela antes de que cuente en las estadísticas por fecha.';
    expect(find.text(unconfirmedCopy), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.pencil));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ACEPTAR'));
    await tester.pumpAndSettle();

    expect(repo.updateCalls, 1);
    expect(find.text(unconfirmedCopy), findsNothing);
  });

  testWidgets('edit date failure keeps order and shows error toast', (
    tester,
  ) async {
    final book = Book(
      id: 'personal-book',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Libro',
      authors: const ['Autor'],
      status: 'reading',
    );
    final repo = _HistoryRepository(
      BookStatusHistoryPage(
        items: [
          BookStatusHistoryEntry(
            id: 'h-1',
            status: 'reading',
            changedAt: DateTime.utc(2026, 7, 18, 12),
          ),
          BookStatusHistoryEntry(
            id: 'h-2',
            status: 'pending',
            changedAt: DateTime.utc(2026, 7, 10, 12),
          ),
        ],
      ),
      updateFailure: const NetworkFailure(),
    );

    await tester.pumpWidget(_app(book, repo, canEdit: true));
    await tester.pumpAndSettle();

    final pendingCard = find
        .ancestor(of: find.text('Pendiente'), matching: find.byType(RdCard))
        .first;
    await tester.tap(
      find.descendant(
        of: pendingCard,
        matching: find.byIcon(LucideIcons.pencil),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('20').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ACEPTAR'));
    await tester.pumpAndSettle();

    expect(repo.updateCalls, 1);
    expect(repo.calls, 1);
    expect(find.text('Fecha del estado actualizada'), findsNothing);
    final pendingTop = tester.getTopLeft(find.text('Pendiente')).dy;
    final readingTop = tester.getTopLeft(find.text('Leyendo')).dy;
    expect(readingTop, lessThan(pendingTop));
  });

  testWidgets('empty history remains pull-to-refreshable', (tester) async {
    final book = Book(
      id: 'personal-book',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Libro',
      authors: const ['Autor'],
      status: 'pending',
    );
    final repo = _HistoryRepository(BookStatusHistoryPage(items: const []));

    await tester.pumpWidget(_app(book, repo));
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.history), findsOneWidget);
    expect(
      find.text('Aún no hay cambios de estado registrados.'),
      findsOneWidget,
    );
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(repo.calls, 1);
  });

  testWidgets('history cards render in dark mode without overflow', (
    tester,
  ) async {
    final book = Book(
      id: 'personal-book',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Libro',
      authors: const ['Autor'],
      status: 'abandoned',
    );
    final repo = _HistoryRepository(
      BookStatusHistoryPage(
        items: [
          BookStatusHistoryEntry(
            id: 'h-1',
            status: 'abandoned',
            changedAt: DateTime.utc(2026, 7, 20),
          ),
        ],
      ),
    );

    await tester.pumpWidget(_app(book, repo, dark: true));
    await tester.pumpAndSettle();

    expect(find.text('Abandonado'), findsOneWidget);
    expect(
      tester.getCenter(find.text('Abandonado')).dy,
      closeTo(
        tester.getCenter(find.byType(BookFieldLeadingIcon)).dy,
        0.01,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('baseline description uses the width below the date', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final book = Book(
      id: 'personal-book',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Libro',
      authors: const ['Autor'],
      status: 'pending',
    );
    final repo = _HistoryRepository(
      BookStatusHistoryPage(
        items: [
          BookStatusHistoryEntry(
            id: 'h-1',
            status: 'pending',
            changedAt: DateTime.utc(2026, 7, 20),
            isBaseline: true,
          ),
        ],
      ),
    );

    await tester.pumpWidget(_app(book, repo));
    await tester.pumpAndSettle();

    final description = find.text(
      'Estado registrado al activar el historial',
    );
    final date = find.textContaining('20 jul 2026');
    expect(description, findsOneWidget);
    expect(date, findsOneWidget);
    expect(
      tester.getRect(description).right,
      greaterThan(tester.getRect(date).left),
    );
    final statusRect = tester.getRect(find.text('Pendiente'));
    final dateRect = tester.getRect(date);
    final descriptionRect = tester.getRect(description);
    final contentTop = statusRect.top < dateRect.top
        ? statusRect.top
        : dateRect.top;
    expect(
      (contentTop + descriptionRect.bottom) / 2,
      closeTo(
        tester.getCenter(find.byType(BookFieldLeadingIcon)).dy,
        1,
      ),
    );
    expect(descriptionRect.top - statusRect.bottom, lessThanOrEqualTo(2.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'refresh supersedes an in-flight page without blocking pagination',
    (
      tester,
    ) async {
      final book = Book(
        id: 'personal-book',
        ownerType: 'user',
        ownerId: 'user-1',
        title: 'Libro',
        authors: const ['Autor'],
        status: 'reading',
      );
      final repo = _ControlledHistoryRepository();

      await tester.pumpWidget(_app(book, repo));
      expect(repo.requests, hasLength(1));
      repo.complete(
        0,
        BookStatusHistoryPage(
          items: _entries(24),
          nextCursor: 'page-2',
        ),
      );
      await tester.pumpAndSettle();

      await tester.fling(
        find.byType(AnimatedList),
        const Offset(0, -4000),
        4000,
      );
      await tester.pump();
      expect(repo.requests, hasLength(2));
      expect(repo.requests[1].cursor, 'page-2');

      final refresh = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      unawaited(refresh.onRefresh());
      await tester.pump();
      expect(repo.requests, hasLength(3));
      expect(repo.requests[2].cursor, isNull);

      repo.complete(
        1,
        BookStatusHistoryPage(
          items: _entries(3, prefix: 'stale'),
          nextCursor: 'stale-page',
        ),
      );
      await tester.pump();
      repo.complete(
        2,
        BookStatusHistoryPage(
          items: _entries(24, prefix: 'fresh'),
          nextCursor: 'fresh-page-2',
        ),
      );
      await tester.pumpAndSettle();

      await tester.fling(
        find.byType(AnimatedList),
        const Offset(0, -4000),
        4000,
      );
      await tester.pump();
      expect(repo.requests, hasLength(4));
      expect(repo.requests[3].cursor, 'fresh-page-2');
      repo.complete(3, BookStatusHistoryPage(items: const []));
      await tester.pumpAndSettle();
    },
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('uses adaptive page chrome on $platform', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        final book = Book(
          id: 'book-1',
          ownerType: 'user',
          ownerId: 'user-1',
          title: 'Libro',
          authors: const ['Autor'],
          status: 'reading',
        );
        await tester.pumpWidget(
          _app(
            book,
            _HistoryRepository(BookStatusHistoryPage(items: const [])),
            platform: platform,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Historial de estados'), findsOneWidget);
        if (platform == TargetPlatform.iOS) {
          expect(find.byType(CupertinoNavigationBar), findsOneWidget);
          expect(find.byType(AppBar), findsNothing);
        } else {
          expect(find.byType(AppBar), findsOneWidget);
          expect(find.byType(CupertinoNavigationBar), findsNothing);
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets('iOS edge swipe pops a pushed status history route', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final book = Book(
        id: 'book-1',
        ownerType: 'user',
        ownerId: 'user-1',
        title: 'Libro',
        authors: const ['Autor'],
        status: 'reading',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookRepoProvider.overrideWithValue(
              _HistoryRepository(BookStatusHistoryPage(items: const [])),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme().copyWith(platform: TargetPlatform.iOS),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    rdPageRoute<void>(
                      context,
                      builder: (_) => BookStatusHistoryScreen(book: book),
                    ),
                  ),
                  child: const Text('open-history'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open-history'));
      await tester.pumpAndSettle();

      expect(find.text('Historial de estados'), findsOneWidget);
      expect(find.byType(CupertinoNavigationBarBackButton), findsNothing);
      expect(find.byIcon(CupertinoIcons.back), findsOneWidget);
      final route =
          ModalRoute.of(tester.element(find.text('Historial de estados')))!
              as PageRoute<void>;
      expect(route, isA<CupertinoPageRoute<void>>());
      expect(route.popGestureEnabled, isTrue);

      await tester.timedDragFrom(
        const Offset(5, 300),
        const Offset(400, 0),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();

      expect(find.text('Historial de estados'), findsNothing);
      expect(find.text('open-history'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

List<BookStatusHistoryEntry> _entries(int count, {String prefix = 'entry'}) =>
    List.generate(
      count,
      (index) => BookStatusHistoryEntry(
        id: '$prefix-$index',
        status: index.isEven ? 'reading' : 'pending',
        changedAt: DateTime.utc(2026, 7, 20).subtract(Duration(days: index)),
      ),
    );

Widget _app(
  Book book,
  BookRepository repo, {
  bool dark = false,
  bool canEdit = false,
  TargetPlatform? platform,
}) => ProviderScope(
  overrides: [bookRepoProvider.overrideWithValue(repo)],
  child: MaterialApp(
    locale: const Locale('es'),
    theme: (dark ? buildDarkTheme() : buildLightTheme()).copyWith(
      platform: platform,
    ),
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: BookStatusHistoryScreen(book: book, canEdit: canEdit),
  ),
);

class _HistoryRepository extends Fake implements BookRepository {
  _HistoryRepository(this.page, {this.updateFailure});

  final BookStatusHistoryPage page;
  final Failure? updateFailure;
  int calls = 0;
  int updateCalls = 0;
  String? lastUpdatedEntryId;
  DateTime? lastUpdatedChangedAt;

  @override
  Future<Result<BookStatusHistoryPage>> listStatusHistory(
    String bookId, {
    String? cursor,
    int limit = 20,
  }) async {
    calls++;
    return Ok(page);
  }

  @override
  Future<Result<BookStatusHistoryEntry>> updateStatusHistoryChangedAt(
    String bookId,
    String entryId,
    DateTime changedAt,
  ) async {
    updateCalls++;
    lastUpdatedEntryId = entryId;
    lastUpdatedChangedAt = changedAt;
    final failure = updateFailure;
    if (failure != null) return Err(failure);
    final existing = page.items.firstWhere((e) => e.id == entryId);
    return Ok(existing.copyWith(changedAt: changedAt, dateConfirmed: true));
  }
}

class _HistoryRequest {
  _HistoryRequest(this.cursor, this.completer);

  final String? cursor;
  final Completer<Result<BookStatusHistoryPage>> completer;
}

class _ControlledHistoryRepository extends Fake implements BookRepository {
  final requests = <_HistoryRequest>[];

  @override
  Future<Result<BookStatusHistoryPage>> listStatusHistory(
    String bookId, {
    String? cursor,
    int limit = 20,
  }) {
    final completer = Completer<Result<BookStatusHistoryPage>>();
    requests.add(_HistoryRequest(cursor, completer));
    return completer.future;
  }

  void complete(int index, BookStatusHistoryPage page) {
    requests[index].completer.complete(Ok(page));
  }
}


class _FakeHistoryTokenStorage extends SecureTokenStorage {
  @override
  Future<String?> getAccess() async => null;
}

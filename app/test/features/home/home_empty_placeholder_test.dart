import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/error/failure_exception.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/calendar/event_form_screen.dart';
import 'package:readendar/features/home/home_screen.dart';
import 'package:readendar/features/library/library_pane.dart';
import 'package:readendar/features/roulette/book_roulette_screen.dart';
import 'package:readendar/features/search/search_screen.dart';

AppUser _testUser({String id = 'user-1'}) => AppUser(
  id: id,
  email: 'reader@example.com',
  displayName: 'Reader',
  preferredLocale: 'es',
  timezone: 'Europe/Madrid',
  onboardingCompletedAt: DateTime(2026, 7),
);

class _Session extends SessionNotifier {
  _Session(super.ref, AppUser user) {
    state = SessionState(user: user);
  }
}

class _FakeSearchRepo extends Fake implements SearchRepository {
  @override
  Future<Result<SearchPage>> search(
    String query, {
    String? column,
    int page = 1,
    int limit = 20,
    bool allLanguages = false,
  }) async {
    return const Ok(SearchPage(items: [], page: 1, limit: 20, hasMore: false));
  }
}

Future<AppL10n> _pumpHome(
  WidgetTester tester, {
  ThemeData? theme,
  AppUser? user,
  List<Override> overrides = const [],
  Future<List<Book>> Function()? loadBooks,
  bool settle = true,
}) async {
  late AppL10n l10n;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(
          (ref) => _Session(ref, user ?? _testUser()),
        ),
        booksProvider.overrideWith((ref) async {
          if (loadBooks != null) return loadBooks();
          return const <Book>[];
        }),
        upcomingEventsProvider.overrideWith(
          (ref) async => const <ReadingEvent>[],
        ),
        notificationPrefsProvider.overrideWith(
          (ref) async => NotificationPreferences(
            globalEnabled: true,
            defaultReminderMinutesBefore: 1440,
            allDayReminderHour: 9,
          ),
        ),
        ...overrides,
      ],
      child: MaterialApp(
        locale: const Locale('es'),
        theme: theme ?? buildLightTheme(),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Builder(
          builder: (context) {
            l10n = AppL10n.of(context);
            return const HomeScreen();
          },
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }
  return l10n;
}

void main() {
  testWidgets('empty home shows compact placeholders with CTAs', (
    tester,
  ) async {
    final l = await _pumpHome(tester);

    expect(find.text(l.homeNoReading), findsOneWidget);
    expect(find.text(l.emptyToday), findsOneWidget);
    expect(find.text(l.homeStartReading), findsOneWidget);
    expect(find.text(l.actionAddEvent), findsOneWidget);
    expect(find.byIcon(LucideIcons.bookOpen), findsOneWidget);
    expect(find.byIcon(LucideIcons.calendarPlus), findsNWidgets(2));
  });

  testWidgets('home quick actions no longer include a quotes tile', (
    tester,
  ) async {
    final l = await _pumpHome(tester);
    expect(find.text(l.quotesTitle), findsNothing);
    expect(find.text(l.homeActionAddQuote), findsNothing);
  });

  testWidgets('home quick actions add event opens event form', (tester) async {
    final l = await _pumpHome(tester);

    expect(find.text(l.homeActionAddEvent), findsOneWidget);
    await tester.tap(find.text(l.homeActionAddEvent));
    await tester.pumpAndSettle();

    expect(find.byType(EventFormScreen), findsOneWidget);
    expect(find.text(l.eventCreateTitle), findsOneWidget);
  });

  testWidgets('empty home placeholders render in dark theme', (tester) async {
    final l = await _pumpHome(tester, theme: buildDarkTheme());

    expect(find.text(l.homeNoReading), findsOneWidget);
    expect(find.text(l.emptyToday), findsOneWidget);
    expect(find.text(l.homeStartReading), findsOneWidget);
    expect(find.text(l.actionAddEvent), findsOneWidget);
  });

  testWidgets('reading empty CTA opens start-reading sheet', (tester) async {
    final l = await _pumpHome(tester);

    await tester.tap(find.text(l.homeStartReading));
    await tester.pumpAndSettle();

    expect(find.text(l.statusEmptyGoToLibrary), findsOneWidget);
    expect(find.text(l.rouletteEntry), findsOneWidget);
  });

  testWidgets('start-reading sheet library option switches to library tab', (
    tester,
  ) async {
    final l = await _pumpHome(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    await tester.tap(find.text(l.homeStartReading));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.statusEmptyGoToLibrary));
    await tester.pumpAndSettle();

    expect(container.read(tabIndexProvider), 1);
    expect(container.read(libraryPaneProvider), LibraryPane.books);
  });

  testWidgets('start-reading sheet roulette option opens roulette', (
    tester,
  ) async {
    final l = await _pumpHome(tester);

    await tester.tap(find.text(l.homeStartReading));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.rouletteEntry));
    await tester.pumpAndSettle();

    expect(find.byType(BookRouletteScreen), findsOneWidget);
  });

  testWidgets('today empty CTA opens event form', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final l = await _pumpHome(tester);

    await tester.tap(find.text(l.actionAddEvent));
    await tester.pumpAndSettle();

    expect(find.byType(EventFormScreen), findsOneWidget);
    expect(find.text(l.eventCreateTitle), findsOneWidget);
  });

  testWidgets('adding a book from Home lands on owned books', (tester) async {
    final l = await _pumpHome(
      tester,
      user: _testUser(),
      overrides: [
        searchRepoProvider.overrideWithValue(_FakeSearchRepo()),
      ],
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    await tester.tap(find.text(l.homeActionAddBook));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(SearchScreen))).pop(
      Book(
        id: 'new-1',
        ownerType: 'user',
        ownerId: 'user-1',
        title: 'Dune',
        authors: const ['Frank Herbert'],
        status: 'pending',
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(tabIndexProvider), 1);
    expect(container.read(libraryPaneProvider), LibraryPane.books);
  });
}

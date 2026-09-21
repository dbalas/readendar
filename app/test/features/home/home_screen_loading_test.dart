import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/error/failure_exception.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/error_retry.dart';
import 'package:readendar/core/widgets/skeleton.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/home/home_hero.dart';
import 'package:readendar/features/home/home_screen.dart';

void main() {
  testWidgets(
    'Home runs one continuous first-load cascade without loading indicators',
    (tester) async {
      final books = Completer<List<Book>>();
      final events = Completer<List<ReadingEvent>>();
      var homeVisible = true;
      late StateSetter setHostState;
      addTearDown(() {
        if (!books.isCompleted) books.complete(const <Book>[]);
        if (!events.isCompleted) events.complete(const <ReadingEvent>[]);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(
              (ref) => _Session(ref, _testUser()),
            ),
            booksProvider.overrideWith((ref) => books.future),
            upcomingEventsProvider.overrideWith((ref) => events.future),
          ],
          child: StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return MaterialApp(
                theme: buildLightTheme(),
                localizationsDelegates: AppL10n.localizationsDelegates,
                supportedLocales: AppL10n.supportedLocales,
                home: homeVisible
                    ? const HomeScreen()
                    : const SizedBox(key: ValueKey('other-page')),
              );
            },
          ),
        ),
      );

      double opacity(String key) => tester
          .widget<FadeTransition>(find.byKey(ValueKey(key)))
          .opacity
          .value;
      Offset slidePosition(String key) => tester
          .widget<SlideTransition>(
            find.descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(SlideTransition),
            ),
          )
          .position
          .value;

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(SkeletonPulse), findsNothing);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(opacity('homeHeroEntrance'), greaterThan(0));
      expect(find.byKey(const Key('homeSectionTitle')), findsWidgets);

      books.complete(const <Book>[]);
      events.complete(const <ReadingEvent>[]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(opacity('homeHeroEntrance'), 1);
      expect(slidePosition('homeHeroEntrance'), Offset.zero);
      expect(opacity('homeQuickActionsEntrance'), 1);
      expect(opacity('homeReadingEntrance'), 1);
      expect(opacity('homeTodayEventsEntrance'), 1);
      expect(find.byKey(const Key('homeEditorialTitle')), findsOneWidget);
      expect(find.byKey(const Key('homeSectionTitle')), findsNWidgets(2));

      setHostState(() => homeVisible = false);
      await tester.pump();
      expect(find.byKey(const ValueKey('other-page')), findsOneWidget);

      setHostState(() => homeVisible = true);
      await tester.pump();
      for (final key in [
        'homeHeroEntrance',
        'homeQuickActionsEntrance',
        'homeReadingEntrance',
        'homeTodayEventsEntrance',
      ]) {
        expect(
          tester.widget(find.byKey(ValueKey(key))),
          isA<KeyedSubtree>(),
        );
      }
    },
  );

  testWidgets(
    'failed first book fetch shows ErrorRetry on Home',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith((ref) => _Session(ref, _testUser())),
            booksProvider.overrideWith(
              (ref) async => throw const FailureException(NetworkFailure()),
            ),
            upcomingEventsProvider.overrideWith(
              (ref) async => const <ReadingEvent>[],
            ),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme(),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ErrorRetry), findsOneWidget);
      expect(find.byType(HomeHero), findsNothing);
    },
  );

  testWidgets(
    'pull-to-refresh keeps previously loaded reading shelf visible',
    (tester) async {
      final refresh = Completer<List<Book>>();
      var calls = 0;
      final initial = [
        Book(
          id: 'book-1',
          ownerType: OwnerType.user,
          ownerId: 'user-1',
          title: 'Dune',
          authors: const ['Frank Herbert'],
          status: BookStatus.reading,
        ),
      ];
      addTearDown(() {
        if (!refresh.isCompleted) refresh.complete(initial);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith((ref) => _Session(ref, _testUser())),
            booksProvider.overrideWith((ref) async {
              calls++;
              if (calls == 1) return initial;
              return refresh.future;
            }),
            upcomingEventsProvider.overrideWith(
              (ref) async => const <ReadingEvent>[],
            ),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme(),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dune'), findsWidgets);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      container.invalidate(booksProvider);
      await tester.pump();
      expect(find.text('Dune'), findsWidgets);
    },
  );
}

AppUser _testUser() => AppUser(
  id: 'user-1',
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

ApiClient _fakeClient() => ApiClient(
  baseUrl: 'http://localhost',
  storage: _NoopSecureStorage(),
  localeProvider: () => 'es',
);

class _NoopSecureStorage extends SecureTokenStorage {
  @override
  Future<String?> getAccess() async => null;

  @override
  Future<String?> getRefresh() async => null;

  @override
  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {}

  @override
  Future<void> clear() async {}
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/home/home_screen.dart';

void main() {
  testWidgets(
    'cover badge derives percent from pages when stored values disagree',
    (tester) async {
      final book = Book(
        id: 'book-1',
        ownerType: 'user',
        ownerId: 'user-1',
        title: 'Pedro Paramo',
        authors: const ['Juan Rulfo'],
        status: BookStatus.reading,
        pageCount: 120,
      );
      final progress = Progress(
        bookEntryId: book.id,
        currentPage: 51,
        currentPercentage: 20,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(
              (ref) => _Session(ref, _testUser()),
            ),
            booksProvider.overrideWith((ref) async => [book]),
            upcomingEventsProvider.overrideWith(
              (ref) async => const <ReadingEvent>[],
            ),
            progressProvider(book.id).overrideWith((ref) async => progress),
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

      // 51/120 → 43%. Stale stored 20% must not appear next to page 51.
      expect(find.text('43%'), findsOneWidget);
      expect(find.text('51'), findsOneWidget);
      expect(find.text('20%'), findsNothing);
    },
  );

  testWidgets(
    'cover badge omits percent next to a page when total pages are unknown',
    (tester) async {
      final book = Book(
        id: 'book-1',
        ownerType: 'user',
        ownerId: 'user-1',
        title: 'Pedro Paramo',
        authors: const ['Juan Rulfo'],
        status: BookStatus.reading,
      );
      final progress = Progress(
        bookEntryId: book.id,
        currentPage: 51,
        currentPercentage: 20,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(
              (ref) => _Session(ref, _testUser()),
            ),
            booksProvider.overrideWith((ref) async => [book]),
            upcomingEventsProvider.overrideWith(
              (ref) async => const <ReadingEvent>[],
            ),
            progressProvider(book.id).overrideWith((ref) async => progress),
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

      expect(find.text('51'), findsOneWidget);
      expect(find.text('20%'), findsNothing);
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

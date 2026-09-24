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
import 'package:readendar/features/library/book_detail_screen.dart';

import '../../helpers/infra_overrides.dart';

void main() {
  late TestInfra infra;

  setUp(() async {
    infra = await TestInfra.create(prefix: 'book-detail-error');
  });

  tearDown(() => infra.dispose());

  testWidgets('book load failure shows ErrorRetry', (tester) async {
    const id = 'book-1';
    await tester.pumpWidget(
      ProviderScope(
        overrides: infra.combine([
          bookProvider(id).overrideWith(
            (ref) async => throw const FailureException(NetworkFailure()),
          ),
          progressProvider(id).overrideWith(
            (ref) async => Progress(bookEntryId: id),
          ),
          eventsForBookProvider(id).overrideWith(
            (ref) => const AsyncValue.data(<ReadingEvent>[]),
          ),
          booksProvider.overrideWith((ref) async => const <Book>[]),
        ]),
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const BookDetailScreen(bookId: id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ErrorRetry), findsOneWidget);
  });

  testWidgets('progress network failure is not painted as missing progress', (
    tester,
  ) async {
    const id = 'book-1';
    final book = Book(
      id: id,
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.reading,
      pageCount: 120,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: infra.combine([
          bookProvider(id).overrideWith((ref) async => book),
          progressProvider(id).overrideWith(
            (ref) async => throw const FailureException(NetworkFailure()),
          ),
          eventsForBookProvider(id).overrideWith(
            (ref) => const AsyncValue.data(<ReadingEvent>[]),
          ),
          booksProvider.overrideWith((ref) async => [book]),
        ]),
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const BookDetailScreen(bookId: id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sin progreso registrado'), findsNothing);
    expect(find.text('Sin conexión. Revisa la red.'), findsWidgets);
    expect(find.byKey(const Key('progressEditButton')), findsOneWidget);
  });
}

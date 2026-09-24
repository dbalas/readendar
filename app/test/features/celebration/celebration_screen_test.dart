import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/celebration/celebration_screen.dart';
import 'package:readendar/features/library/book_detail_screen.dart';
import 'package:readendar/features/library/book_field_cards.dart';
import 'package:readendar/features/library/rating_sheet.dart';
import '../../helpers/api_repo_stubs.dart';
import '../../helpers/infra_overrides.dart';

late TestInfra testInfra;

Book _book({String status = BookStatus.reading, int? pageCount = 120}) => Book(
  id: 'book-1',
  ownerType: 'user',
  ownerId: 'user-1',
  title: 'Pedro Paramo',
  authors: const ['Juan Rulfo'],
  status: status,
  pageCount: pageCount,
);

ReadingEvent _event(String type, DateTime date, {String status = 'active'}) =>
    ReadingEvent(
      id: 'e-$type',
      ownerType: 'user',
      ownerId: 'user-1',
      type: type,
      title: type,
      dateLocal: date,
      status: status,
      bookId: 'book-1',
    );

Widget _wrap(Widget home, List<Override> overrides) => ProviderScope(
  overrides: testInfra.combine(overrides),
  child: MaterialApp(
    locale: const Locale('es'),
    theme: buildLightTheme(),
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: home,
  ),
);

void main() {
  setUp(() async {
    testInfra = await TestInfra.create(prefix: 'celebration-screen');
  });

  tearDown(() => testInfra.dispose());

  testWidgets('premium celebration uses the selected theme identity', (
    tester,
  ) async {
    final book = _book(status: BookStatus.read);
    await tester.pumpWidget(
      ProviderScope(
        overrides: testInfra.combine([
          bookEventsHistoryProvider(book.id).overrideWith((ref) async => []),
          progressProvider(
            book.id,
          ).overrideWith((ref) async => Progress(bookEntryId: book.id)),
        ]),
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(themeId: ReadendarThemeId.ethereal),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: CelebrationScreen(book: book),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    expect(
      find.byKey(const Key('celebrationThemeBackdrop-ethereal')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('etherealCelebrationOrbit')), findsOneWidget);
    expect(find.byKey(const Key('standardCelebrationConfetti')), findsNothing);
  });

  for (final definition in ReadendarThemes.premium.where(
    (theme) => theme.id != ReadendarThemeId.ethereal,
  )) {
    testWidgets('${definition.id.name} owns its completion vocabulary', (
      tester,
    ) async {
      final book = _book(status: BookStatus.read);
      await tester.pumpWidget(
        ProviderScope(
          overrides: testInfra.combine([
            bookEventsHistoryProvider(book.id).overrideWith((ref) async => []),
            progressProvider(
              book.id,
            ).overrideWith((ref) async => Progress(bookEntryId: book.id)),
          ]),
          child: MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme(themeId: definition.id),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: CelebrationScreen(book: book),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      expect(
        find.byKey(Key('celebrationThemeBackdrop-${definition.id.wire}')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          Key('premiumCelebration-${definition.identity.effect.name}'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('standardCelebrationConfetti')),
        findsNothing,
      );
    });
  }

  testWidgets('premium celebration settles when reduced motion is enabled', (
    tester,
  ) async {
    final book = _book(status: BookStatus.read);
    await tester.pumpWidget(
      ProviderScope(
        overrides: testInfra.combine([
          bookEventsHistoryProvider(book.id).overrideWith((ref) async => []),
          progressProvider(
            book.id,
          ).overrideWith((ref) async => Progress(bookEntryId: book.id)),
        ]),
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(themeId: ReadendarThemeId.ethereal),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: CelebrationScreen(book: book),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('etherealCelebrationOrbit')), findsOneWidget);
  });

  testWidgets('renders title, computable metrics and the remaining actions', (
    tester,
  ) async {
    final book = _book(status: BookStatus.read);
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _wrap(CelebrationScreen(book: book), [
          bookEventsHistoryProvider(book.id).overrideWith(
            (ref) async => [
              _event('start', DateTime.utc(2026, 5)),
              _event(
                'chapter_milestone',
                DateTime.utc(2026, 5, 4),
                status: 'completed',
              ),
              _event('finish', DateTime.utc(2026, 5, 11)),
            ],
          ),
          progressProvider(
            book.id,
          ).overrideWith((ref) async => Progress(bookEntryId: book.id)),
          booksProvider.overrideWith((ref) async => [book]),
        ]),
      );
      // Resolve providers and drain the staggered firework timers; avoid
      // pumpAndSettle because the confetti animation never settles.
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('¡Lo has terminado!'), findsOneWidget);
      expect(find.text('Terminado en 10 días'), findsOneWidget);
      expect(find.text('120 páginas leídas'), findsOneWidget);
      expect(find.text('1 sesión de lectura'), findsOneWidget);

      // Share remains, plus a primary rate CTA.
      expect(find.text('Añadir libro'), findsNothing);
      expect(find.text('Mi biblioteca'), findsNothing);
      expect(find.text('Ruleta de lectura'), findsNothing);
      expect(find.widgetWithText(RdButton, 'Compartir'), findsOneWidget);
      expect(
        find.byKey(const Key('celebrationRateCta')),
        findsOneWidget,
      );

      // Rate-and-note block (personal copies only): stars open the sheet.
      // Prompt appears in the rate block and again as the primary CTA label.
      expect(find.text('¿Cómo lo valorarías?'), findsNWidgets(2));
      expect(find.byKey(const Key('celebrationHeaderRating')), findsOneWidget);
      expect(find.text('Sin valorar'), findsNothing);
      expect(
        find.widgetWithText(RdButton, 'Reseña'),
        findsNothing,
      );
    });
  });

  testWidgets('tapping stars on the celebration opens rating+review sheet', (
    tester,
  ) async {
    final book = _book(status: BookStatus.read);
    final repo = _FakeBookRepository(book);

    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _wrap(CelebrationScreen(book: book), [
          bookEventsHistoryProvider(
            book.id,
          ).overrideWith((ref) async => const <ReadingEvent>[]),
          progressProvider(
            book.id,
          ).overrideWith((ref) async => Progress(bookEntryId: book.id)),
          bookProvider(book.id).overrideWith((ref) async => book),
          booksProvider.overrideWith((ref) async => [book]),
          bookRepoProvider.overrideWithValue(repo),
        ]),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('Sin valorar'), findsNothing);
      expect(find.byType(BookStaticStars), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('celebrationHeaderRating')),
      );
      await tester.tap(find.byKey(const Key('celebrationHeaderRating')));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(HalfStarPicker), findsOneWidget);
      tester.widget<HalfStarPicker>(find.byType(HalfStarPicker)).onChanged(2.5);
      await tester.pump();
      expect(find.text('2.5'), findsOneWidget);
      expect(find.text(' / 5'), findsOneWidget);
      tester
          .widget<RdButton>(find.byKey(const Key('rating-review-save')))
          .onPressed!();
      await tester.pump(const Duration(milliseconds: 500));

      expect(repo.updatedRating, 2.5);
      expect(find.text('2.5'), findsOneWidget);
      expect(find.text('Sin valorar'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  testWidgets('celebration shows a truncated review caption under the stars', (
    tester,
  ) async {
    final book = _book(status: BookStatus.read).copyWith(
      rating: 4,
      reviewMarkdown: 'Me encantó el final\ny lo volvería a leer.',
    );

    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _wrap(CelebrationScreen(book: book), [
          bookEventsHistoryProvider(
            book.id,
          ).overrideWith((ref) async => const <ReadingEvent>[]),
          progressProvider(
            book.id,
          ).overrideWith((ref) async => Progress(bookEntryId: book.id)),
          booksProvider.overrideWith((ref) async => [book]),
        ]),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      final preview = find.byKey(const Key('celebrationReviewPreview'));
      expect(preview, findsOneWidget);
      expect(
        tester.widget<Text>(preview).data,
        'Me encantó el final y lo volvería a leer.',
      );
      expect(tester.widget<Text>(preview).maxLines, 1);
      expect(tester.widget<Text>(preview).style?.fontStyle, FontStyle.italic);
    });
  });

  testWidgets('changing status into "read" launches the celebration', (
    tester,
  ) async {
    final book = _book();
    final repo = _FakeBookRepository(_book(status: BookStatus.read));

    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _wrap(BookDetailScreen(bookId: book.id), [
          bookProvider(book.id).overrideWith((ref) async => book),
          eventsForBookProvider(
            book.id,
          ).overrideWith((ref) => const AsyncValue.data(<ReadingEvent>[])),
          booksProvider.overrideWith((ref) async => [book]),
          progressProvider(
            book.id,
          ).overrideWith((ref) async => Progress(bookEntryId: book.id)),
          bookRepoProvider.overrideWithValue(repo),
          bookEventsHistoryProvider(
            book.id,
          ).overrideWith((ref) async => const <ReadingEvent>[]),
        ]),
      );
      await tester.pumpAndSettle();

      // Open the status sheet and pick "Leído" (read) — goes straight to
      // celebration; rating/review sheet is only for explicit edits.
      await tester.tap(find.text('Leyendo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leído'));
      // Don't settle — the pushed celebration animates forever. Pump past the
      // staggered firework timers so none stay pending at teardown.
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      expect(repo.changedTo, BookStatus.read);
      expect(find.byType(CelebrationScreen), findsOneWidget);
      expect(find.byKey(const Key('rating-review-skip')), findsNothing);
    });
  });

  testWidgets('re-selecting "read" when already read does not celebrate', (
    tester,
  ) async {
    final book = _book(status: BookStatus.read);
    final repo = _FakeBookRepository(book);

    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        _wrap(BookDetailScreen(bookId: book.id), [
          bookProvider(book.id).overrideWith((ref) async => book),
          eventsForBookProvider(
            book.id,
          ).overrideWith((ref) => const AsyncValue.data(<ReadingEvent>[])),
          booksProvider.overrideWith((ref) async => [book]),
          progressProvider(
            book.id,
          ).overrideWith((ref) async => Progress(bookEntryId: book.id)),
          bookRepoProvider.overrideWithValue(repo),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Leído').first);
      await tester.pumpAndSettle();
      // The status row subtitle also reads "Leído"; the option in
      // the sheet is the last match.
      await tester.tap(find.text('Leído').last);
      await tester.pumpAndSettle();

      expect(repo.changedTo, isNull); // early-returned, no status call
      expect(find.byType(CelebrationScreen), findsNothing);
    });
  });
}

class _FakeBookRepository extends ApiBookRepository {
  _FakeBookRepository(this.result)
    : super(
        ApiClient(
          baseUrl: 'http://localhost',
          storage: _FakeSecureTokenStorage(),
          localeProvider: () => 'es',
        ),
      );

  final Book result;
  String? changedTo;
  double? updatedRating;
  String? updatedReview;

  @override
  Future<Result<Book>> changeStatus(String id, String status) async {
    changedTo = status;
    return Ok(result);
  }

  @override
  Future<Result<Book>> finish(
    String id, {
    required String idempotencyKey,
    double? rating,
    String reviewMarkdown = '',
    bool saveRatingReview = false,
  }) async {
    changedTo = BookStatus.read;
    updatedRating = saveRatingReview ? rating : null;
    updatedReview = saveRatingReview ? reviewMarkdown : null;
    return Ok(result);
  }

  @override
  Future<Result<Book>> updateRatingReview(
    String id, {
    required double? rating,
    required String reviewMarkdown,
  }) async {
    updatedRating = rating;
    updatedReview = reviewMarkdown;
    return Ok(
      result.copyWith(
        rating: rating,
        clearRating: rating == null,
        reviewMarkdown: reviewMarkdown,
      ),
    );
  }

  @override
  Future<Result<Book>> updatePersonal(
    String id, {
    required double? rating,
  }) async {
    updatedRating = rating;
    return Ok(
      result.copyWith(
        rating: rating,
        clearRating: rating == null,
      ),
    );
  }
}

class _FakeSecureTokenStorage extends SecureTokenStorage {
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

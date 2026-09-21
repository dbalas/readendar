import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/error/failure_exception.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/widgets/empty_state.dart';
import 'package:readendar/core/widgets/error_retry.dart';
import 'package:readendar/core/widgets/rd_list_item_actions.dart';
import 'package:readendar/core/widgets/search_field.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/quotes/book_annotations_screen.dart';
import 'package:readendar/features/quotes/annotations_empty_art.dart';
import 'package:readendar/features/quotes/quote_card.dart';
import 'package:readendar/features/quotes/quote_composer_sheet.dart';

import 'quotes_test_utils.dart';

Widget _host(
  FakeQuoteRepository repo,
  List<Book> books, {
  required String bookId,
  String? highlightAnnotationId,
  Book? seedBook,
  List<Override> extraOverrides = const [],
}) {
  return ProviderScope(
    overrides: [
      quoteRepoProvider.overrideWithValue(repo),
      sessionProvider.overrideWith(FakeSessionNotifier.new),
      booksProvider.overrideWith((ref) async => books),
      ...extraOverrides,
    ],
    child: MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: const [
        ...AppL10n.localizationsDelegates,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: AppL10n.supportedLocales,
      home: BookAnnotationsScreen(
        bookId: bookId,
        highlightAnnotationId: highlightAnnotationId,
        book: seedBook,
      ),
    ),
  );
}

void main() {
  final books = [
    testBook(),
    testBook(id: 'b2', title: 'Pedro Páramo'),
  ];

  List<Quote> seed() => [
    testQuote(
      text: 'Muchos años después',
      pinned: true,
      createdAt: DateTime.utc(2026, 7, 2),
    ),
    testQuote(
      id: 'q2',
      bookId: 'b2',
      text: 'Vine a Comala',
      createdAt: DateTime.utc(2026, 7),
    ),
    testQuote(
      id: 'n1',
      text: 'Una teoría propia',
      category: AnnotationCategory.theory,
    ),
  ];

  testWidgets('shows only annotations for the given book', (tester) async {
    await tester.pumpWidget(
      _host(FakeQuoteRepository(seed()), books, bookId: 'b2'),
    );
    await tester.pumpAndSettle();

    expect(find.text('«Vine a Comala»'), findsOneWidget);
    expect(find.text('«Muchos años después»'), findsNothing);
    expect(find.byType(QuoteCard), findsOneWidget);
    expect(find.byType(RdSearchField), findsOneWidget);
    expect(find.text('Categorías'), findsOneWidget);
    expect(find.text('Favoritas'), findsOneWidget);
  });

  testWidgets('list preview renders markdown escapes like the editor', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        FakeQuoteRepository([
          testQuote(text: r'\*not bold\*'),
        ]),
        books,
        bookId: 'b1',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('«*not bold*»'), findsOneWidget);
    expect(find.text('«\\*not bold\\*»'), findsNothing);
  });

  testWidgets('long annotation preview always ends with an ellipsis', (
    tester,
  ) async {
    final long = List.generate(
      16,
      (i) => 'Palabra número $i en una cita muy larga',
    ).join(' ');
    await tester.pumpWidget(
      _host(
        FakeQuoteRepository([testQuote(text: long)]),
        books,
        bookId: 'b1',
      ),
    );
    await tester.pumpAndSettle();

    final preview = tester.widget<Text>(
      find
          .descendant(
            of: find.byType(QuoteCard),
            matching: find.byWidgetPredicate(
              (w) => w is Text && (w.data?.contains('Palabra') ?? false),
            ),
          )
          .first,
    );
    expect(preview.maxLines, 3);
    expect(preview.overflow, TextOverflow.ellipsis);
    expect(preview.data?.length, lessThan(long.length + 4));
  });

  testWidgets('category chip filters the list', (tester) async {
    await tester.pumpWidget(
      _host(FakeQuoteRepository(seed()), books, bookId: 'b1'),
    );
    await tester.pumpAndSettle();

    expect(find.text('«Muchos años después»'), findsOneWidget);
    expect(find.text('Una teoría propia'), findsOneWidget);

    await tester.tap(find.text('Categorías'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Teoría'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(find.text('Una teoría propia'), findsOneWidget);
    expect(find.text('«Muchos años después»'), findsNothing);
  });

  testWidgets('category filter with no matches shows filter empty, not error', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(FakeQuoteRepository(seed()), books, bookId: 'b1'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Categorías'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preguntas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorRetry), findsNothing);
    expect(
      find.text('Ninguna anotación coincide con estos filtros.'),
      findsOneWidget,
    );
  });

  testWidgets('empty book shows dedicated empty art and CTA', (tester) async {
    await tester.pumpWidget(
      _host(FakeQuoteRepository([]), books, bookId: 'b1'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RefreshableEmptyState), findsOneWidget);
    expect(find.byType(AnnotationsEmptyArt), findsOneWidget);
    expect(
      find.text('Aún no se ha añadido ninguna anotación.'),
      findsOneWidget,
    );
    expect(find.text('Añadir anotación'), findsOneWidget);
    expect(find.text('Sin resultados.'), findsNothing);
    expect(find.text('Añadir cita'), findsNothing);
  });

  testWidgets('delete confirms then removes the annotation', (tester) async {
    final repo = FakeQuoteRepository([
      testQuote(text: 'Muchos años después'),
    ]);
    await tester.pumpWidget(_host(repo, books, bookId: 'b1'));
    await tester.pumpAndSettle();

    expect(find.byType(RdListItemActions), findsOneWidget);
    await tester.tap(find.byTooltip('Acciones de la anotación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(repo.deleteCalls, ['q1']);
    expect(find.text('«Muchos años después»'), findsNothing);
  });

  testWidgets('pin toggle is optimistic and respects the max of 3', (
    tester,
  ) async {
    final repo = FakeQuoteRepository([
      testQuote(
        id: 'p1',
        text: 'uno',
        pinned: true,
        category: AnnotationCategory.note,
      ),
      testQuote(
        id: 'p2',
        text: 'dos',
        pinned: true,
        category: AnnotationCategory.theory,
      ),
      testQuote(
        id: 'p3',
        text: 'tres',
        pinned: true,
        category: AnnotationCategory.question,
      ),
      testQuote(
        id: 'p4',
        text: 'cuatro',
        category: AnnotationCategory.note,
      ),
    ]);
    await tester.pumpWidget(_host(repo, books, bookId: 'b1'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Acciones de la anotación').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fijar').last);
    await tester.pumpAndSettle();

    expect(repo.updateCalls, isEmpty);
    expect(
      find.text('Puedes fijar hasta 3 anotaciones por libro.'),
      findsOneWidget,
    );
  });

  testWidgets('pin toggle paints from the controller overlay immediately', (
    tester,
  ) async {
    final repo = FakeQuoteRepository([
      testQuote(
        id: 'n1',
        text: 'nota suelta',
        category: AnnotationCategory.note,
      ),
    ]);
    // Slow update so the book FutureProvider would stay stale without the
    // quotesController overlay merge on the list screen.
    repo.updateDelay = const Duration(milliseconds: 400);
    await tester.pumpWidget(_host(repo, books, bookId: 'b1'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Acciones de la anotación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fijar').last);
    await tester.pump(); // request still in flight

    expect(repo.updateCalls, isEmpty);
    await tester.tap(find.byTooltip('Acciones de la anotación'));
    await tester.pumpAndSettle();
    expect(find.text('Quitar fijado'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  });

  testWidgets('quote pins do not consume the note pin cap', (tester) async {
    final repo = FakeQuoteRepository([
      testQuote(id: 'p1', text: 'uno', pinned: true),
      testQuote(id: 'p2', text: 'dos', pinned: true),
      testQuote(id: 'p3', text: 'tres', pinned: true),
      testQuote(
        id: 'p4',
        text: 'nota',
        category: AnnotationCategory.note,
      ),
    ]);
    await tester.pumpWidget(_host(repo, books, bookId: 'b1'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Acciones de la anotación').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fijar').last);
    await tester.pumpAndSettle();

    expect(repo.updateCalls, isNotEmpty);
    expect(
      find.text('Puedes fijar hasta 3 anotaciones por libro.'),
      findsNothing,
    );
  });

  testWidgets('highlightAnnotationId still renders the annotation', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        FakeQuoteRepository(seed()),
        books,
        bookId: 'b2',
        highlightAnnotationId: 'q2',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('«Vine a Comala»'), findsOneWidget);
  });

  testWidgets('pinned swipe delete keeps accent border on list chrome', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        FakeQuoteRepository([
          testQuote(text: 'Muchos años después', pinned: true),
        ]),
        books,
        bookId: 'b1',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RdListItemActions), findsOneWidget);
    final card = tester.widget<QuoteCard>(find.byType(QuoteCard));
    expect(card.accentFrame, isFalse);

    final actions = tester.widget<RdListItemActions>(
      find.byType(RdListItemActions),
    );
    expect(actions.border, isNotNull);
    expect(actions.border!.width, 1);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(QuoteCard)),
    );
    await gesture.moveBy(const Offset(-160, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    final actionRect = tester.getRect(
      find.byKey(const ValueKey('rd-swipe-action-delete')),
    );
    final chromeRect = tester.getRect(find.byType(RdListItemActions));
    expect(actionRect.left, greaterThanOrEqualTo(chromeRect.left));
    expect(actionRect.top, greaterThanOrEqualTo(chromeRect.top));
    expect(actionRect.right, lessThanOrEqualTo(chromeRect.right));
    expect(actionRect.bottom, lessThanOrEqualTo(chromeRect.bottom));
  });

  testWidgets('favorites filter hides non-favorites', (tester) async {
    await tester.pumpWidget(
      _host(
        FakeQuoteRepository([
          testQuote(text: 'cita favorita', favorite: true),
          testQuote(
            id: 'q2',
            text: 'cita normal',
            favorite: false,
          ),
        ]),
        books,
        bookId: 'b1',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('«cita favorita»'), findsOneWidget);
    expect(find.text('«cita normal»'), findsOneWidget);

    await tester.tap(find.text('Favoritas'));
    await tester.pumpAndSettle();

    expect(find.text('«cita favorita»'), findsOneWidget);
    expect(find.text('«cita normal»'), findsNothing);
  });

  testWidgets('does not autofocus the annotations search field', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(FakeQuoteRepository(seed()), books, bookId: 'b1'),
    );
    await tester.pumpAndSettle();

    final search = tester.widget<RdSearchField>(find.byType(RdSearchField));
    expect(search.autofocus, isFalse);
    // Soft keyboard stays closed on open (search must not claim focus).
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets(
    'personal book add still skips the picker when the copy is known',
    (tester) async {
      await tester.pumpWidget(
        _host(FakeQuoteRepository([]), books, bookId: 'b1'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Añadir cita'));
      await tester.pumpAndSettle();

      expect(find.text('¿De qué libro es la cita?'), findsNothing);
      expect(find.byType(QuoteComposerSheet), findsOneWidget);
      expect(find.text('Cien años de soledad'), findsWidgets);
    },
  );

  testWidgets(
    'unknown book shows empty art without a create action',
    (tester) async {
      await tester.pumpWidget(
        _host(FakeQuoteRepository([]), const [], bookId: 'ghost'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('Añadir anotación'), findsNothing);
      expect(find.text('¿De qué libro es la cita?'), findsNothing);
      expect(find.byType(QuoteComposerSheet), findsNothing);
      expect(find.byType(AnnotationsEmptyArt), findsOneWidget);
    },
  );

  testWidgets('annotation load failure shows ErrorRetry, not empty art', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        FakeQuoteRepository([]),
        books,
        bookId: 'b1',
        extraOverrides: [
          bookAnnotationsProvider('b1').overrideWith(
            (ref) async => throw const FailureException(NetworkFailure()),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ErrorRetry), findsOneWidget);
    expect(find.byType(AnnotationsEmptyArt), findsNothing);
  });
}

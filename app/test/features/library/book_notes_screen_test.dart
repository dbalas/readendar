import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/utils/annotation_markdown.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/rd_edge_fading_scroll.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/library/book_notes_screen.dart';
import '../quotes/quotes_test_utils.dart';
import '../../helpers/api_repo_stubs.dart';

void main() {
  // The visual editor stores Markdown: formatting must survive the
  // Markdown → Delta (load) → Markdown (save) round-trip the screen performs.
  test('Markdown survives the editor Delta round-trip', () {
    const source = '# Title\n\nSome **bold** and *italic* text\n\n- one\n- two';
    final out = annotationMarkdownFromDocument(
      Document.fromDelta(annotationMarkdownToDelta(source)),
    );
    expect(out, contains('# Title'));
    expect(out, contains('**bold**'));
    expect(out, contains('_italic_')); // markdown_quill emits italic as _x_
    expect(out, contains('- one'));
    expect(out, contains('- two'));
  });

  testWidgets('renders a visual editor seeded with the note + a toolbar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final book = Book(
      id: 'b1',
      ownerType: 'user',
      ownerId: 'u1',
      title: 'T',
      authors: const ['A'],
      status: BookStatus.reading,
      notes: 'Hello **world**',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepoProvider.overrideWithValue(_FakeBookRepository(book)),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: const [
            ...AppL10n.localizationsDelegates,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: AppL10n.supportedLocales,
          home: BookNotesScreen(book: book),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The screen builds the visual editor + toolbar (and the Quill localization
    // delegate is wired) without throwing.
    final toolbarFinder = find.byKey(const Key('notes-toolbar'));
    final frameFinder = find.ancestor(
      of: toolbarFinder,
      matching: find.byWidgetPredicate(
        (widget) => widget is Container && widget.decoration is BoxDecoration,
      ),
    );
    final frame = tester.widget<Container>(frameFinder);
    final decoration = frame.decoration! as BoxDecoration;
    final border = decoration.border! as Border;
    final context = tester.element(toolbarFinder);

    expect(toolbarFinder, findsOneWidget);
    expect(find.byType(QuillEditor), findsOneWidget);
    expect(find.byType(QuillSimpleToolbar), findsNothing);
    expect(
      decoration.borderRadius,
      BorderRadius.circular(ReadendarTokens.radiusSm),
    );
    expect(border.top, border.right);
    expect(border.top, border.bottom);
    expect(border.top, border.left);
    expect(border.top.color, context.colors.line);
    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.byKey(RdEdgeFadingScrollView.startShadowKey), findsNothing);
    expect(find.byKey(RdEdgeFadingScrollView.endShadowKey), findsOneWidget);

    final scrollable = find.descendant(
      of: toolbarFinder,
      matching: find.byType(Scrollable),
    );
    await tester.drag(scrollable, const Offset(-120, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(RdEdgeFadingScrollView.startShadowKey), findsOneWidget);
    expect(find.byKey(RdEdgeFadingScrollView.endShadowKey), findsOneWidget);
  });

  testWidgets('does not autofocus when opening an empty notes editor', (
    tester,
  ) async {
    final book = Book(
      id: 'b1',
      ownerType: 'user',
      ownerId: 'u1',
      title: 'T',
      authors: const ['A'],
      status: BookStatus.reading,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepoProvider.overrideWithValue(_FakeBookRepository(book)),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: const [
            ...AppL10n.localizationsDelegates,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: AppL10n.supportedLocales,
          home: BookNotesScreen(book: book),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editor = tester.widget<QuillEditor>(find.byType(QuillEditor));
    expect(editor.config.autoFocus, isFalse);
    expect(editor.focusNode.hasFocus, isFalse);
  });

  testWidgets('empty persist pops success without creating an annotation', (
    tester,
  ) async {
    final book = Book(
      id: 'b1',
      ownerType: 'user',
      ownerId: 'u1',
      title: 'T',
      authors: const ['A'],
      status: BookStatus.reading,
    );
    final annotations = FakeQuoteRepository([]);
    Object? popped;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          annotationRepoProvider.overrideWithValue(annotations),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: const [
            ...AppL10n.localizationsDelegates,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: AppL10n.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<Object?>(
                  MaterialPageRoute<Object?>(
                    builder: (_) => BookNotesScreen(book: book),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(popped, isTrue);
    expect(annotations.createCalls, isEmpty);
  });

  testWidgets('persist creates a note annotation and pops success', (
    tester,
  ) async {
    final book = Book(
      id: 'b1',
      ownerType: 'user',
      ownerId: 'u1',
      title: 'T',
      authors: const ['A'],
      status: BookStatus.reading,
      notes: 'Private line',
    );
    final annotations = FakeQuoteRepository([]);
    Object? popped;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          annotationRepoProvider.overrideWithValue(annotations),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: const [
            ...AppL10n.localizationsDelegates,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: AppL10n.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<Object?>(
                  MaterialPageRoute<Object?>(
                    builder: (_) => BookNotesScreen(book: book),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(popped, isTrue);
    expect(annotations.createCalls, hasLength(1));
    expect(annotations.createCalls.single['bookId'], 'b1');
    expect(annotations.createCalls.single['category'], AnnotationCategory.note);
    expect(annotations.createCalls.single['body'], contains('Private line'));
  });

  testWidgets('persist keeps the editor open when create fails', (
    tester,
  ) async {
    final book = Book(
      id: 'b1',
      ownerType: 'user',
      ownerId: 'u1',
      title: 'T',
      authors: const ['A'],
      status: BookStatus.reading,
      notes: 'Private line',
    );
    final annotations = FakeQuoteRepository([])..failMutations = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          annotationRepoProvider.overrideWithValue(annotations),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: const [
            ...AppL10n.localizationsDelegates,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: AppL10n.supportedLocales,
          home: BookNotesScreen(book: book),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.byType(BookNotesScreen), findsOneWidget);
    expect(find.text('boom'), findsOneWidget);
    expect(annotations.createCalls, hasLength(1));
  });
}

class _FakeBookRepository extends ApiBookRepository {
  _FakeBookRepository(this.book)
    : super(
        ApiClient(
          baseUrl: 'http://localhost',
          storage: _FakeSecureTokenStorage(),
          localeProvider: () => 'en',
        ),
      );

  final Book book;

  @override
  Future<Result<Book>> updatePersonal(
    String id, {
    required double? rating,
  }) async => Ok(book);
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

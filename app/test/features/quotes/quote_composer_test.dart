import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/annotation_category_style.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/di/providers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:readendar/features/quotes/quote_composer_sheet.dart';
import 'package:readendar/features/quotes/voice/quote_voice_permission.dart';
import 'package:readendar/features/quotes/voice/voice_dictation_controller.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'quotes_test_utils.dart';

class _MockSpeechToText extends Mock implements SpeechToText {}

Future<void> _enterBody(WidgetTester tester, String text) async {
  final editor = tester.widget<QuillEditor>(find.byType(QuillEditor));
  final len = editor.controller.document.length;
  editor.controller.replaceText(0, len > 0 ? len - 1 : 0, text, null);
  await tester.pump();
}

void _stubSpeechLifecycle(_MockSpeechToText speech) {
  when(() => speech.cancel()).thenAnswer((_) async {});
  when(() => speech.stop()).thenAnswer((_) async {});
}

Widget _host(
  FakeQuoteRepository repo,
  List<Book> books,
  Widget child,
) {
  return ProviderScope(
    overrides: [
      quoteRepoProvider.overrideWithValue(repo),
      booksProvider.overrideWith((ref) async => books),
    ],
    child: MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: const [
        ...AppL10n.localizationsDelegates,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: AppL10n.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('save is disabled until there is text, then creates the quote', (
    tester,
  ) async {
    final repo = FakeQuoteRepository([]);
    final book = testBook();
    await tester.pumpWidget(
      _host(repo, [book], QuoteComposerSheet(book: book)),
    );
    await tester.pumpAndSettle();

    // Pre-linked book renders in the header row.
    expect(find.text(book.title), findsWidgets);

    await tester.tap(find.widgetWithText(RdButton, 'Guardar'));
    await tester.pumpAndSettle();
    expect(repo.createCalls, isEmpty);

    await _enterBody(tester, '  El mundo era tan reciente  ');
    await tester.pump();
    await tester.tap(find.widgetWithText(RdButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(repo.createCalls, hasLength(1));
    expect(repo.createCalls.single['bookId'], 'b1');
    expect(repo.createCalls.single['text'], 'El mundo era tan reciente');
  });

  testWidgets('page and chapter fields are sent, pin toggles from config', (
    tester,
  ) async {
    final repo = FakeQuoteRepository([]);
    final book = testBook();
    await tester.pumpWidget(
      _host(repo, [book], QuoteComposerSheet(book: book)),
    );
    await tester.pumpAndSettle();

    await _enterBody(tester, 'cita');
    await tester.tap(find.text('Configuración'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('annotationConfigPage')), '12');
    await tester.enterText(
      find.byKey(const Key('annotationConfigChapter')),
      '3',
    );
    await tester.tap(find.text('Favorita'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(RdButton, 'Cerrar'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(RdButton, 'Guardar'));
    await tester.pumpAndSettle();

    final call = repo.createCalls.single;
    expect(call['page'], 12);
    expect(call['chapter'], 3);
    expect(call['favorite'], true);
  });

  testWidgets('composer shows the provided book and has no book picker', (
    tester,
  ) async {
    final repo = FakeQuoteRepository([]);
    final reading = testBook(title: 'Leyendo éste');
    final pending = testBook(
      id: 'b2',
      title: 'Pendiente',
      status: BookStatus.pending,
    );
    await tester.pumpWidget(
      _host(repo, [reading, pending], QuoteComposerSheet(book: reading)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Leyendo éste'), findsWidgets);
    expect(find.text('Pendiente'), findsNothing);
    expect(find.text('Elegir un libro'), findsNothing);
    expect(find.text('Selecciona un libro'), findsNothing);
  });

  testWidgets('config sheet exposes pin; private note stays on quote composer', (
    tester,
  ) async {
    final book = testBook();
    await tester.pumpWidget(
      _host(FakeQuoteRepository([]), [book], QuoteComposerSheet(book: book)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nota privada'), findsOneWidget);

    await tester.tap(find.text('Configuración'));
    await tester.pumpAndSettle();

    expect(find.text('Fijar'), findsOneWidget);
    expect(find.text('Favorita'), findsOneWidget);
    expect(find.text('Contiene spoilers'), findsNothing);
    expect(find.byKey(const Key('annotationConfigPage')), findsOneWidget);
    expect(find.byKey(const Key('annotationConfigChapter')), findsOneWidget);
    // Private note stays on the composer body (still in the tree under the sheet).
    expect(find.text('Nota privada'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(FilterChip), findsNothing);
    expect(find.byType(AnnotationCategoryChip), findsNothing);
  });

  testWidgets('editing prefills the quote and config save persists anchors', (
    tester,
  ) async {
    final existing = testQuote(page: 12, favorite: true);
    final repo = FakeQuoteRepository([existing]);
    final book = testBook();
    await tester.pumpWidget(
      _host(repo, [book], QuoteComposerSheet(existing: existing)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(QuillEditor), findsOneWidget);
    final editor = tester.widget<QuillEditor>(find.byType(QuillEditor));
    expect(
      editor.controller.document.toPlainText(),
      contains('El mundo era tan reciente'),
    );

    await tester.tap(find.text('Configuración'));
    await tester.pumpAndSettle();
    expect(find.text('12'), findsOneWidget);

    // Clear the page and save config: anchors persist without the main Save.
    await tester.enterText(find.byKey(const Key('annotationConfigPage')), '');
    await tester.tap(find.widgetWithText(RdButton, 'Guardar').last);
    await tester.pumpAndSettle();

    expect(repo.updateCalls, hasLength(1));
    expect(repo.updateCalls.single.page, isNull);
    expect(repo.updateCalls.single.favorite, isTrue);
    expect(repo.updateCalls.single.text, 'El mundo era tan reciente');
  });

  testWidgets(
    'saving config on an existing annotation persists flags',
    (tester) async {
      final existing = testQuote();
      final repo = FakeQuoteRepository([existing]);
      final book = testBook();
      await tester.pumpWidget(
        _host(
          repo,
          [book],
          QuoteComposerSheet(existing: existing),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Configuración'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fijar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(RdButton, 'Guardar').last);
      await tester.pumpAndSettle();

      expect(repo.updateCalls, hasLength(1));
      final updated = repo.updateCalls.single;
      expect(updated.pinned, isTrue);
      expect(updated.spoiler, isFalse);
      expect(updated.text, existing.text);
    },
  );

  testWidgets('config save failure keeps the sheet open and toasts', (
    tester,
  ) async {
    final existing = testQuote(page: 4);
    final repo = FakeQuoteRepository([existing])..failMutations = true;
    final book = testBook();
    await tester.pumpWidget(
      _host(repo, [book], QuoteComposerSheet(existing: existing)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Configuración'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('annotationConfigPage')), '99');
    await tester.tap(find.widgetWithText(RdButton, 'Guardar').last);
    await tester.pumpAndSettle();

    expect(repo.updateCalls, hasLength(1));
    // Sheet still open after failure; controllers reverted.
    expect(find.byKey(const Key('annotationConfigPage')), findsOneWidget);
    expect(find.text('99'), findsNothing);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets(
    'with the keyboard up the private note stays reachable (no overflow)',
    (tester) async {
      final repo = FakeQuoteRepository([]);
      final book = testBook();
      // A short viewport plus a tall keyboard inset — the exact case that used
      // to bury the note field under the keyboard.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            quoteRepoProvider.overrideWithValue(repo),
            booksProvider.overrideWith((ref) async => [book]),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            localizationsDelegates: const [
              ...AppL10n.localizationsDelegates,
              FlutterQuillLocalizations.delegate,
            ],
            supportedLocales: AppL10n.supportedLocales,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(400, 640),
                viewInsets: EdgeInsets.only(bottom: 320),
              ),
              child: Scaffold(body: QuoteComposerSheet(book: book)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The sheet lays out without a RenderFlex overflow.
      expect(tester.takeException(), isNull);

      expect(find.byType(QuillEditor), findsOneWidget);
      expect(find.byType(QuoteComposerSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'private note reappears when keyboard is dismissed while editor stays focused',
    () {
      expect(
        annotationComposerHidesBottomChrome(
          editorFocused: true,
          keyboardInsetBottom: 320,
        ),
        isTrue,
      );
      expect(
        annotationComposerHidesBottomChrome(
          editorFocused: true,
          keyboardInsetBottom: 0,
        ),
        isFalse,
      );
      expect(
        annotationComposerHidesBottomChrome(
          editorFocused: false,
          keyboardInsetBottom: 320,
        ),
        isFalse,
      );
    },
  );

  testWidgets('save action stays above the bottom system inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 48);
    tester.view.viewPadding = const FakeViewPadding(bottom: 48);
    addTearDown(tester.view.reset);

    final repo = FakeQuoteRepository([]);
    final book = testBook();
    await tester.pumpWidget(
      _host(
        repo,
        [book],
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => openQuoteComposer(context, book: book),
            child: const Text('Open composer'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open composer'));
    await tester.pumpAndSettle();

    final save = find.widgetWithText(RdButton, 'Guardar');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();

    expect(tester.getRect(save).bottom, lessThanOrEqualTo(700 - 48));
  });

  testWidgets('voice unavailable shows persistent inline notice and toast', (
    tester,
  ) async {
    final speech = _MockSpeechToText();
    _stubSpeechLifecycle(speech);
    when(
      () => speech.initialize(
        onStatus: any(named: 'onStatus'),
        onError: any(named: 'onError'),
      ),
    ).thenAnswer((_) async => true);
    when(speech.locales).thenAnswer(
      (_) async => [LocaleName('en_US', 'English')],
    );
    when(() => speech.isListening).thenReturn(false);

    final voice = VoiceDictationController(
      speech: speech,
      onDeviceAvailable: (_) async => false,
    );
    final book = testBook();
    await tester.pumpWidget(
      _host(
        FakeQuoteRepository([]),
        [book],
        QuoteComposerSheet(
          book: book,
          voiceController: voice,
          ensureVoicePermission: (_) async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final mic = find.byTooltip('Dictar por voz');
    await tester.tap(mic);
    await tester.pumpAndSettle();

    expect(
      find.text('El dictado por voz no está disponible en este dispositivo.'),
      findsWidgets,
    );
    expect(voice.unavailable, isTrue);
    // Mic stays tappable so a second press can re-surface the toast.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is IconButton &&
            w.onPressed != null &&
            w.tooltip == 'El dictado por voz no está disponible en este dispositivo.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('retryable voice init failure toasts try-again copy', (
    tester,
  ) async {
    final speech = _MockSpeechToText();
    _stubSpeechLifecycle(speech);
    when(
      () => speech.initialize(
        onStatus: any(named: 'onStatus'),
        onError: any(named: 'onError'),
      ),
    ).thenAnswer((_) async => false);
    when(() => speech.isListening).thenReturn(false);

    final voice = VoiceDictationController(speech: speech);
    final book = testBook();
    await tester.pumpWidget(
      _host(
        FakeQuoteRepository([]),
        [book],
        QuoteComposerSheet(
          book: book,
          voiceController: voice,
          ensureVoicePermission: (_) async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Dictar por voz'));
    await tester.pumpAndSettle();

    expect(
      find.text("No se pudo iniciar el dictado por voz. Inténtalo de nuevo."),
      findsOneWidget,
    );
    expect(
      find.text('El dictado por voz no está disponible en este dispositivo.'),
      findsNothing,
    );
    expect(voice.unavailable, isFalse);
  });

  testWidgets(
    'denied microphone shows permission modal instead of a silent miss',
    (tester) async {
      final speech = _MockSpeechToText();
      _stubSpeechLifecycle(speech);
      when(
        () => speech.initialize(
          onStatus: any(named: 'onStatus'),
          onError: any(named: 'onError'),
        ),
      ).thenAnswer((_) async => true);
      when(() => speech.isListening).thenReturn(false);

      final voice = VoiceDictationController(speech: speech);
      final book = testBook();
      await tester.pumpWidget(
        _host(
          FakeQuoteRepository([]),
          [book],
          QuoteComposerSheet(
            book: book,
            voiceController: voice,
            ensureVoicePermission: (context) => ensureQuoteVoiceAccess(
              context,
              requestMicrophone: () async => PermissionStatus.denied,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Dictar por voz'));
      await tester.pumpAndSettle();

      expect(find.text('Se necesita acceso al micrófono'), findsOneWidget);
      expect(
        find.text(
          'Readendar necesita acceso al micrófono para dictar citas. '
          'Puedes activarlo en Ajustes.',
        ),
        findsOneWidget,
      );
      expect(find.text('Abrir ajustes'), findsOneWidget);
      expect(
        find.text("No se pudo iniciar el dictado por voz. Inténtalo de nuevo."),
        findsNothing,
      );
      verifyNever(
        () => speech.initialize(
          onStatus: any(named: 'onStatus'),
          onError: any(named: 'onError'),
        ),
      );
    },
  );

}

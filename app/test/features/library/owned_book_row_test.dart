import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/rd_list_item_actions.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/library/owned_book_row.dart';

class _MockBookRepository extends Mock implements BookRepository {}

Book _book(String id) => Book(
  id: id,
  ownerType: 'user',
  ownerId: 'user-1',
  title: 'Owned Title',
  authors: const ['Autor'],
  status: BookStatus.pending,
);

ThemeData _iosTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: buildLightTheme().colorScheme,
  platform: TargetPlatform.iOS,
  cupertinoOverrideTheme: buildLightTheme().cupertinoOverrideTheme,
);

ThemeData _androidTheme() => buildLightTheme().copyWith(
  platform: TargetPlatform.android,
);

Future<void> _withPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<void> _swipeDelete(WidgetTester tester) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(OwnedBookRow)),
  );
  await gesture.moveBy(const Offset(-160, 0));
  await gesture.up();
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('rd-swipe-action-delete')));
  await tester.pumpAndSettle();
}

void main() {
  late _MockBookRepository books;

  setUpAll(() {
    registerFallbackValue('');
  });

  setUp(() {
    books = _MockBookRepository();
    when(() => books.delete(any())).thenAnswer((_) async => const Ok(null));
  });

  Widget app({
    required ThemeData theme,
    required Book book,
  }) => ProviderScope(
    overrides: [
      bookRepoProvider.overrideWithValue(books),
      booksProvider.overrideWith((ref) async => [book]),
      upcomingEventsProvider.overrideWith((ref) async => const []),
      calendarEventsProvider.overrideWith((ref, _) async => const []),
      sessionProvider.overrideWith(SessionNotifier.new),
    ],
    child: MaterialApp(
      locale: const Locale('es'),
      theme: theme,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: Scaffold(
        body: OwnedBookRow(book: book),
      ),
    ),
  );

  testWidgets('Android swipe delete confirms then deletes', (tester) async {
    final book = _book('a');
    await tester.pumpWidget(app(theme: _androidTheme(), book: book));
    await tester.pumpAndSettle();

    expect(find.byType(RdListItemActions), findsOneWidget);
    await _swipeDelete(tester);

    expect(find.text('¿Eliminar este libro de la biblioteca?'), findsOneWidget);
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();

    verify(() => books.delete('a')).called(1);
    expect(find.text('Libro eliminado de tu biblioteca'), findsOneWidget);
  });

  testWidgets('iOS swipe delete confirms then deletes', (tester) async {
    await _withPlatform(TargetPlatform.iOS, () async {
      final book = _book('b');
      await tester.pumpWidget(app(theme: _iosTheme(), book: book));
      await tester.pumpAndSettle();

      await _swipeDelete(tester);

      expect(find.text('¿Eliminar este libro de la biblioteca?'), findsOneWidget);
      await tester.tap(find.text('Eliminar').last);
      await tester.pumpAndSettle();

      verify(() => books.delete('b')).called(1);
    });
  });

  testWidgets('cancel leaves the book', (tester) async {
    final book = _book('c');
    await tester.pumpWidget(app(theme: _androidTheme(), book: book));
    await tester.pumpAndSettle();

    await _swipeDelete(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    verifyNever(() => books.delete(any()));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/offline/offline_config.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/core/widgets/rd_circular_progress.dart';
import 'package:readendar/core/widgets/rd_section_tabs.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/library/book_detail_screen.dart';
import '../../helpers/infra_overrides.dart';


Book _personalBook() => Book(
  id: 'book-1',
  ownerType: 'user',
  ownerId: 'user-1',
  title: 'Pedro Paramo',
  authors: const ['Juan Rulfo'],
  status: BookStatus.reading,
  description: 'Una sinopsis breve para el tab Detalle.',
  rating: 4.5,
  notes: 'Mis notas',
);

class _FakeSecureTokenStorage extends SecureTokenStorage {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> getAccess() async => null;

  @override
  Future<String?> getRefresh() async => null;

  @override
  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {}
}


List<Override> _ownedOverrides(
  Book book, {
  required TestInfra infra,
  List<Book> library = const [],
}) => [
  ...infra.baseOverrides,
  dataPlaneProvider.overrideWith((ref) => DataPlane.api),
  bookProvider(book.id).overrideWith((ref) async => book),
  eventsForBookProvider(
    book.id,
  ).overrideWith((ref) => const AsyncValue.data(<ReadingEvent>[])),
  booksProvider.overrideWith((ref) async => library.isEmpty ? [book] : library),
  progressProvider(
    book.id,
  ).overrideWith((ref) async => Progress(bookEntryId: book.id)),
  bookAnnotationsProvider(
    book.id,
  ).overrideWith((ref) async => const <Annotation>[]),
  bookPlansProvider(book.id).overrideWith((ref) async => const []),
];

Widget _wrap(
  Widget home, {
  required List<Override> overrides,
  ThemeData? theme,
  Locale locale = const Locale('es'),
}) => ProviderScope(
  overrides: [...overrides],
  child: MaterialApp(
    locale: locale,
    theme: theme ?? buildLightTheme(),
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: home,
  ),
);

/// Fails the test if a layout overflow is reported while painting.
void _trapOverflows(WidgetTester tester) {
  final previous = FlutterError.onError;
  addTearDown(() => FlutterError.onError = previous);
  FlutterError.onError = (details) {
    final text = details.toString();
    if (text.contains('overflowed') || text.contains('OVERFLOW')) {
      fail('Layout overflow while painting book detail:\n$text');
    }
    previous?.call(details);
  };
}

void main() {
  late TestInfra infra;

  setUp(() async {
    infra = await TestInfra.create(prefix: 'book-detail-paint');
  });

  tearDown(() => infra.dispose());

  group('BookDetailScreen paints correctly per scope', () {
    testWidgets('premium theme adds cinematic depth to the book header', (
      tester,
    ) async {
      final book = _personalBook();
      final premiumInfra = await TestInfra.create(
        prefix: 'book-detail-paint-premium',
        preferenceValues: {'premium_cover_atmosphere': true},
      );
      await tester.pumpWidget(
        _wrap(
          BookDetailScreen(bookId: book.id),
          overrides: [
            ..._ownedOverrides(book, infra: premiumInfra),
          ],
          theme: buildLightTheme(themeId: ReadendarThemeId.ethereal),
        ),
      );
      await tester.pumpAndSettle();
      premiumInfra.dispose();

      expect(find.byKey(const Key('premiumBookAtmosphere')), findsOneWidget);
      expect(
        find.byKey(const Key('premiumBookAtmosphereForeground')),
        findsOneWidget,
      );
    });

    testWidgets('personal: rating, progress, notes, Detalle and Eventos', (
      tester,
    ) async {
      _trapOverflows(tester);
      final book = _personalBook();
      await tester.pumpWidget(
        _wrap(
          BookDetailScreen(bookId: book.id),
          overrides: _ownedOverrides(book, infra: infra),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pedro Paramo'), findsWidgets);
      expect(find.byKey(const Key('bookHeaderRating')), findsOneWidget);
      expect(find.byType(RdCircularProgress), findsOneWidget);
      expect(find.text('Leyendo'), findsOneWidget);
      expect(find.text('Anotaciones'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(LucideIcons.pencil),
        ),
        findsOneWidget,
      );

      expect(find.byType(RdSectionTabs), findsOneWidget);
      expect(find.text('Detalle'), findsWidgets);
      expect(find.text('Eventos'), findsOneWidget);
      expect(find.textContaining('Una sinopsis breve'), findsOneWidget);
    });

  
  


    testWidgets('personal paints in dark theme without overflow', (
      tester,
    ) async {
      _trapOverflows(tester);
      final book = _personalBook();

      await tester.pumpWidget(
        _wrap(
          BookDetailScreen(bookId: book.id),
          overrides: _ownedOverrides(book, infra: infra),
          theme: buildDarkTheme(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pedro Paramo'), findsWidgets);
      expect(find.byKey(const Key('bookHeaderRating')), findsOneWidget);
    });

  });
}

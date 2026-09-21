import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/error/failure_exception.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/book_status_ui.dart';
import 'package:readendar/core/widgets/error_retry.dart';
import 'package:readendar/core/widgets/section_header.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/filters/filters_state.dart';
import 'package:readendar/features/library/book_picker_screen.dart';
import 'package:readendar/features/search/search_screen.dart';

Book _book(
  String id,
  String title,
  String status, {
  String ownerType = OwnerType.user,
  String ownerId = 'user-1',
}) => Book(
  id: id,
  ownerType: ownerType,
  ownerId: ownerId,
  title: title,
  authors: const ['Autor'],
  status: status,
);

void main() {
  final books = [
    _book('reading', 'Dune', BookStatus.reading),
    _book('pending', 'Foundation', BookStatus.pending),
    _book('read', 'Hyperion', BookStatus.read),
  ];

  Widget wrap({
    ThemeData? theme,
    List<Book>? overrideBooks,
  }) => ProviderScope(
    overrides: [
      booksProvider.overrideWith((ref) async => overrideBooks ?? books),
    ],
    child: MaterialApp(
      locale: const Locale('es'),
      theme: theme ?? buildLightTheme(),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: const _PickerHost(),
    ),
  );

  testWidgets('groups books by status, searches, and returns selection', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    expect(find.text('Leyendo'), findsWidgets);
    expect(find.text('Pendiente'), findsWidgets);
    expect(find.text('Leído'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'Dune');
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(BookPickerScreen)),
    );
    expect(container.read(filtersProvider).isEmpty, isTrue);
    expect(find.text('Dune'), findsWidgets);
    expect(find.text('Foundation'), findsNothing);

    await tester.tap(find.text('Dune').last);
    await tester.pumpAndSettle();

    expect(find.text('Selected: reading'), findsOneWidget);
  });

  testWidgets('status section headers use book state colors', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    final headers = tester
        .widgetList<SectionHeader>(find.byType(SectionHeader))
        .toList();
    final byText = {for (final h in headers) h.text: h.color};
    const c = ReadendarColors.light;
    expect(byText['Leyendo'], bookStatusColor(BookStatus.reading, c));
    expect(byText['Pendiente'], bookStatusColor(BookStatus.pending, c));
    expect(byText['Leído'], bookStatusColor(BookStatus.read, c));
    expect(headers.every((header) => header.count == 1), isTrue);
  });

  testWidgets('reuses book filters and excludes event-only controls', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();

    expect(find.text('Estado'), findsOneWidget);
    expect(find.text('Tipo de evento'), findsNothing);

    await tester.tap(find.text('Leído').last);
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(BookPickerScreen)),
    );
    expect(container.read(filtersProvider).isEmpty, isTrue);
    expect(find.text('Hyperion'), findsWidgets);
    expect(find.text('Dune'), findsNothing);
    expect(find.text('Foundation'), findsNothing);
  });

  testWidgets('add button opens the existing add-book flow', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Añadir libro'));
    await tester.pumpAndSettle();

    expect(find.byType(SearchScreen), findsOneWidget);
  });


  testWidgets('renders the shared picker controls in dark theme', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(theme: buildDarkTheme()));
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    expect(find.text('Dune'), findsWidgets);
    expect(find.byTooltip('Filtros'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('library load failure shows ErrorRetry instead of empty picker', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          booksProvider.overrideWith(
            (ref) async => throw const FailureException(NetworkFailure()),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const BookPickerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ErrorRetry), findsOneWidget);
  });
}

class _PickerHost extends StatefulWidget {
  const _PickerHost();

  @override
  State<_PickerHost> createState() => _PickerHostState();
}

class _PickerHostState extends State<_PickerHost> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _selected == null
            ? FilledButton(
                onPressed: () async {
                  final selected = await Navigator.of(context).push<String>(
                    MaterialPageRoute<String>(
                      builder: (_) => const BookPickerScreen(),
                    ),
                  );
                  if (selected != null) setState(() => _selected = selected);
                },
                child: const Text('Open picker'),
              )
            : Text('Selected: $_selected'),
      ),
    );
  }
}

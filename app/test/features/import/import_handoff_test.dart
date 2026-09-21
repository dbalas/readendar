import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/import/import_confirm_screen.dart';
import 'package:readendar/features/import/import_handoff.dart';

Widget _wrap(Widget home, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('es'),
        theme: buildLightTheme(),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: home,
      ),
    );

// One book from the canonical Goodreads export (Excel-escaped ISBNs), enough to
// exercise the parse → confirm handoff the picker and OS-open flows share.
const _validCsv =
    'Book Id,Title,Author,Author l-f,Additional Authors,ISBN,ISBN13,My Rating,Publisher,Binding,Number of Pages,Year Published,Original Publication Year,Date Read,Date Added,Bookshelves,Bookshelves with positions,Exclusive Shelf,My Review,Spoiler,Private Notes,Read Count,Owned Copies\n'
    '1,"The Hobbit","J.R.R. Tolkien","Tolkien, J.R.R.",,"=""0439023483""","=""9780439023481""",5,Scholastic,Paperback,374,2008,1937,,2020/01/01,,,read,,,,1,0';

void main() {
  group('openImportConfirm', () {
    testWidgets('a valid CSV lands on the confirm screen', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const _HandoffHost(csv: _validCsv),
          overrides: [
            booksProvider.overrideWith((ref) async => const <Book>[]),
          ],
        ),
      );
      // runAsync so the real off-isolate parse (compute) completes.
      await tester.runAsync(() async {
        await tester.tap(find.text('go'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(find.byType(ImportConfirmScreen), findsOneWidget);
      expect(find.text('Hemos encontrado 1 libro'), findsOneWidget);
    });

    testWidgets('a Bookmory XLSX uses the same confirm screen', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _BookmoryHandoffHost(bytes: _bookmoryWorkbook()),
          overrides: [
            booksProvider.overrideWith((ref) async => const <Book>[]),
          ],
        ),
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('go'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(find.byType(ImportConfirmScreen), findsOneWidget);
      expect(find.text('Hemos encontrado 1 libro'), findsOneWidget);
      expect(find.text('Bookmory book'), findsWidgets);
    });

    testWidgets('a Babelio CSV uses the same confirm screen', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const _BabelioHandoffHost(),
          overrides: [
            booksProvider.overrideWith((ref) async => const <Book>[]),
          ],
        ),
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('go'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(find.byType(ImportConfirmScreen), findsOneWidget);
      expect(find.text('Hemos encontrado 1 libro'), findsOneWidget);
      expect(find.text('Babelio book'), findsWidgets);
    });

    testWidgets('an invalid Bookmory file shows a source-specific error', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _BookmoryHandoffHost(bytes: Uint8List.fromList([1, 2, 3])),
        ),
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('go'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(find.byType(ImportConfirmScreen), findsNothing);
      expect(
        find.text(
          "Esto no parece una exportación Excel válida de Bookmory.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('an invalid Babelio file shows a source-specific error', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const _BabelioInvalidHandoffHost()),
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('go'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(find.byType(ImportConfirmScreen), findsNothing);
      expect(
        find.text(
          "Esto no parece una exportación CSV válida de Babelio.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('an unparseable CSV shows an error and stays put', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const _HandoffHost(csv: 'this is not a goodreads export')),
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('go'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(find.byType(ImportConfirmScreen), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}

/// Minimal host with a button that fires [openImportConfirm] against [csv], so
/// the handoff seam can be driven from a real BuildContext under a Navigator.
class _HandoffHost extends StatelessWidget {
  const _HandoffHost({required this.csv});
  final String csv;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => openImportConfirm(context, csv),
          child: const Text('go'),
        ),
      ),
    );
  }
}

class _BookmoryHandoffHost extends StatelessWidget {
  const _BookmoryHandoffHost({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => openBookmoryImportConfirm(context, bytes),
          child: const Text('go'),
        ),
      ),
    );
  }
}

class _BabelioHandoffHost extends StatelessWidget {
  const _BabelioHandoffHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => openBabelioImportConfirm(
            context,
            '"ISBN";"Titre";"Auteur";"Editeur";"Statut";"Note"\n'
            '"9782070737628";"Babelio book";"Author";"Publisher";"Lu";"5"',
          ),
          child: const Text('go'),
        ),
      ),
    );
  }
}

class _BabelioInvalidHandoffHost extends StatelessWidget {
  const _BabelioInvalidHandoffHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => openBabelioImportConfirm(context, 'not Babelio'),
          child: const Text('go'),
        ),
      ),
    );
  }
}

Uint8List _bookmoryWorkbook() {
  final excel = Excel.createExcel()..rename('Sheet1', 'Books');
  excel['Books']
    ..appendRow([
      TextCellValue('Book information'),
      TextCellValue(''),
      TextCellValue(''),
    ])
    ..appendRow([
      TextCellValue('Title'),
      TextCellValue('Authors'),
      TextCellValue('Status'),
    ])
    ..appendRow([
      TextCellValue('Bookmory book'),
      TextCellValue('Author'),
      TextCellValue('Reading'),
    ]);
  return Uint8List.fromList(excel.encode()!);
}

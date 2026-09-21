import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/features/search/isbn_manual_entry_sheet.dart';
import 'package:readendar/features/search/isbn_scanner_screen.dart';

Finder _isbnInput() => find.descendant(
  of: find.byKey(isbnManualEntryFieldKey),
  matching: find.byType(EditableText),
);

Future<void> _pumpSheetOpen(
  WidgetTester tester, {
  required TargetPlatform platform,
  required ValueNotifier<String?> popped,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final light = buildLightTheme();
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: light.colorScheme,
        platform: platform,
        cupertinoOverrideTheme: platform == TargetPlatform.iOS
            ? light.cupertinoOverrideTheme
            : null,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              popped.value = await showIsbnManualEntrySheet(context);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _pumpScanner(
  WidgetTester tester, {
  required TargetPlatform platform,
  required ValueNotifier<String?> popped,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final light = buildLightTheme();
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: light.colorScheme,
        platform: platform,
        cupertinoOverrideTheme: platform == TargetPlatform.iOS
            ? light.cupertinoOverrideTheme
            : null,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              popped.value = await Navigator.of(context).push<String>(
                MaterialPageRoute<String>(
                  builder: (_) => const IsbnScannerScreen(),
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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'manual ISBN sheet shows the required field and rejects empty ($platform)',
      (tester) async {
        final popped = ValueNotifier<String?>(null);
        addTearDown(popped.dispose);
        await _pumpSheetOpen(tester, platform: platform, popped: popped);

        expect(find.byType(IsbnManualEntrySheet), findsOneWidget);
        expect(find.byKey(isbnManualEntryFieldKey), findsOneWidget);
        expect(find.text('Introducir ISBN manualmente'), findsOneWidget);
        expect(find.textContaining('ISBN'), findsWidgets);

        await tester.tap(find.widgetWithText(RdButton, 'Buscar'));
        await tester.pump();

        expect(find.text('Campo requerido.'), findsOneWidget);
        expect(find.byType(IsbnManualEntrySheet), findsOneWidget);
        expect(popped.value, isNull);
      },
    );

    testWidgets(
      'manual ISBN sheet rejects an invalid code and keeps the field ($platform)',
      (tester) async {
        final popped = ValueNotifier<String?>(null);
        addTearDown(popped.dispose);
        await _pumpSheetOpen(tester, platform: platform, popped: popped);

        await tester.enterText(_isbnInput(), 'not-an-isbn');
        await tester.tap(find.widgetWithText(RdButton, 'Buscar'));
        await tester.pump();

        expect(find.text('Introduce un ISBN válido.'), findsOneWidget);
        expect(find.byType(IsbnManualEntrySheet), findsOneWidget);
        expect(popped.value, isNull);
      },
    );

    testWidgets(
      'manual ISBN sheet submits a valid ISBN-13 ($platform)',
      (tester) async {
        final popped = ValueNotifier<String?>(null);
        addTearDown(popped.dispose);
        await _pumpSheetOpen(tester, platform: platform, popped: popped);

        await tester.enterText(_isbnInput(), '978-0-7653-1178-8');
        await tester.tap(find.widgetWithText(RdButton, 'Buscar'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(popped.value, '9780765311788');
        expect(find.byType(IsbnManualEntrySheet), findsNothing);
      },
    );

    testWidgets(
      'tapping Enter ISBN manually opens the field without closing the scanner ($platform)',
      (tester) async {
        final popped = ValueNotifier<String?>(null);
        addTearDown(popped.dispose);
        await _pumpScanner(tester, platform: platform, popped: popped);

        expect(find.byType(IsbnScannerScreen), findsOneWidget);

        await tester.tap(
          find.widgetWithText(RdButton, 'Introducir ISBN manualmente').first,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(IsbnScannerScreen), findsOneWidget);
        expect(find.byType(IsbnManualEntrySheet), findsOneWidget);
        expect(find.byKey(isbnManualEntryFieldKey), findsOneWidget);
        expect(popped.value, isNull);

        await tester.enterText(_isbnInput(), '0306406152');
        await tester.tap(
          find.descendant(
            of: find.byType(IsbnManualEntrySheet),
            matching: find.widgetWithText(RdButton, 'Buscar'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(popped.value, '9780306406157');
        expect(find.byType(IsbnManualEntrySheet), findsNothing);
        expect(find.byType(IsbnScannerScreen), findsNothing);
      },
    );

    testWidgets(
      'dismissing the ISBN sheet leaves the scanner open ($platform)',
      (tester) async {
        final popped = ValueNotifier<String?>(null);
        addTearDown(popped.dispose);
        await _pumpScanner(tester, platform: platform, popped: popped);

        await tester.tap(
          find.widgetWithText(RdButton, 'Introducir ISBN manualmente').first,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(IsbnManualEntrySheet), findsOneWidget);
        Navigator.of(
          tester.element(find.byType(IsbnManualEntrySheet)),
        ).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(IsbnManualEntrySheet), findsNothing);
        expect(find.byType(IsbnScannerScreen), findsOneWidget);
        expect(popped.value, isNull);
      },
    );
  }
}

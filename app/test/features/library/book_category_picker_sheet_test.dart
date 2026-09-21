import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/rd_checkbox.dart';
import 'package:readendar/core/widgets/rd_glass.dart';
import 'package:readendar/core/widgets/search_field.dart';
import 'package:readendar/features/library/book_category_picker_sheet.dart';

class _Pick {
  List<String>? value;
}

Future<_Pick> _openSheet(
  WidgetTester tester, {
  required TargetPlatform platform,
  List<String> selected = const [],
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(tester.view.reset);

  final pick = _Pick();
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
              pick.value = await showRdModalSheet<List<String>>(
                context: context,
                builder: (_) => BookCategoryPickerSheet(selected: selected),
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
  return pick;
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'category sheet searches, toggles, and saves without overflow ($platform)',
      (tester) async {
        final pick = await _openSheet(tester, platform: platform);

        expect(tester.takeException(), isNull);
        expect(find.byType(BookCategoryPickerSheet), findsOneWidget);
        expect(find.byType(RdSearchField), findsOneWidget);
        expect(find.text('Categorías'), findsOneWidget);
        expect(find.text('Aventuras'), findsOneWidget);

        final sheetTop = tester
            .getTopLeft(find.byType(BookCategoryPickerSheet))
            .dy;
        final titleTop = tester.getTopLeft(find.text('Categorías')).dy;
        expect(titleTop - sheetTop, lessThan(40));

        final titleBottom = tester.getRect(find.text('Categorías')).bottom;
        final searchRect = tester.getRect(find.byType(RdSearchField));
        final optionTop = tester
            .getRect(find.byType(RdCheckboxListTile).first)
            .top;
        expect(searchRect.top - titleBottom, closeTo(12, 6));
        expect(optionTop - searchRect.bottom, closeTo(12, 6));
        expect(optionTop - searchRect.bottom, lessThan(24));

        final searchInput = find.descendant(
          of: find.byType(RdSearchField),
          matching: find.byType(EditableText),
        );
        await tester.enterText(searchInput, 'zzzz-not-a-category');
        await tester.pump();
        expect(find.text('Sin resultados.'), findsOneWidget);

        await tester.enterText(searchInput, 'fant');
        await tester.pump();
        expect(find.text('Fantasía'), findsOneWidget);
        expect(find.text('Ficción'), findsNothing);
        expect(find.text('Aventuras'), findsNothing);

        await tester.tap(find.text('Fantasía'));
        await tester.pump();
        await tester.tap(find.text('Guardar'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(pick.value, ['fantasy']);
        expect(find.byType(BookCategoryPickerSheet), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('iOS category checkboxes are large enough to tap and see', (
    tester,
  ) async {
    await _openSheet(tester, platform: TargetPlatform.iOS);

    expect(find.byType(RdCheckbox), findsWidgets);
    final visual = tester.getSize(find.byKey(RdCheckbox.iosVisualKey).first);
    expect(visual.width, greaterThanOrEqualTo(22));
    expect(visual.height, greaterThanOrEqualTo(22));
    expect(tester.takeException(), isNull);
  });
}

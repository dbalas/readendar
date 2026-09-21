import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/search_field.dart';

void main() {
  testWidgets(
    'RdSearchField submits and clears without a leading search icon',
    (
      tester,
    ) async {
      final controller = TextEditingController();
      final submitted = <String>[];
      var cleared = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: RdSearchField(
              controller: controller,
              hintText: 'Search books',
              showSubmitButton: true,
              submitTooltip: 'Search',
              onSubmitted: submitted.add,
              onClear: () => cleared += 1,
            ),
          ),
        ),
      );

      expect(find.byType(SearchBar), findsOneWidget);
      // Trailing submit only — no leading glyph (people-searcher contract).
      expect(find.byIcon(LucideIcons.search), findsOneWidget);

      await tester.enterText(find.byType(SearchBar), 'dune');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(submitted, ['dune']);

      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(cleared, 1);
    },
  );

  for (final entry in [
    ('light', buildLightTheme()),
    ('dark', buildDarkTheme()),
  ]) {
    testWidgets('RdSearchField stays flat without elevation (${entry.$1})', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: entry.$2,
          home: const Scaffold(
            body: RdSearchField(hintText: 'Search'),
          ),
        ),
      );

      final bar = tester.widget<SearchBar>(find.byType(SearchBar));
      expect(bar.elevation!.resolve({}), 0);
      expect(bar.shadowColor!.resolve({}), Colors.transparent);
    });
  }

  testWidgets('Material SearchBar hint uses fgFaint placeholder color', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(
          body: RdSearchField(hintText: 'Filter books'),
        ),
      ),
    );

    final bar = tester.widget<SearchBar>(find.byType(SearchBar));
    final c = tester.element(find.byType(SearchBar)).colors;
    expect(bar.hintStyle!.resolve({})!.color, c.fgFaint);
  });

  testWidgets('compact RdSearchField stays under a dense toolbar height', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(
          body: SizedBox(
            width: 220,
            child: RdSearchField(hintText: 'Filter', compact: true),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(SearchBar));
    expect(size.height, lessThanOrEqualTo(36));
    expect(size.width, lessThan(360));
    final bar = tester.widget<SearchBar>(find.byType(SearchBar));
    expect(bar.constraints!.maxHeight, 36);
    expect(bar.hintStyle!.resolve({})!.fontSize, 13);
  });

  testWidgets('iOS search glyph submits when showSubmitButton is set', (
    tester,
  ) async {
    final controller = TextEditingController();
    final submitted = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme().copyWith(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: RdSearchField(
            controller: controller,
            hintText: 'Search books',
            showSubmitButton: true,
            submitTooltip: 'Search',
            onSubmitted: submitted.add,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(CupertinoTextField), 'dune');
    await tester.tap(find.byIcon(LucideIcons.search));
    await tester.pump();
    expect(submitted, ['dune']);
  });

  testWidgets('compact RdSearchField on iOS uses a shorter pill', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme().copyWith(platform: TargetPlatform.iOS),
        home: const Scaffold(
          body: SizedBox(
            width: 220,
            child: RdSearchField(hintText: 'Filter', compact: true),
          ),
        ),
      ),
    );

    expect(find.byKey(RdSearchField.iosFieldKey), findsOneWidget);
    expect(find.byType(SearchBar), findsNothing);
    final size = tester.getSize(find.byKey(RdSearchField.iosFieldKey));
    expect(size.height, lessThan(48));
    final field = tester.widget<CupertinoTextField>(
      find.byType(CupertinoTextField),
    );
    expect(field.style?.fontSize, 13);
    expect(field.padding, const EdgeInsets.fromLTRB(6, 6, 4, 6));
  });
}

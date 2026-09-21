import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/core/widgets/rd_circular_progress.dart';

void main() {
  testWidgets('Ethereal progress renders a reader-reactive constellation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(themeId: ReadendarThemeId.ethereal),
        home: const Center(
          child: RdCircularProgress(value: 0.5, label: '50%'),
        ),
      ),
    );

    expect(
      find.byKey(const Key('etherealProgressConstellation')),
      findsOneWidget,
    );
    expect(find.text('50%'), findsOneWidget);
  });

  for (final definition in ReadendarThemes.premium.where(
    (theme) => theme.id != ReadendarThemeId.ethereal,
  )) {
    testWidgets('${definition.id.name} progress renders its identity ring', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(themeId: definition.id),
          home: const Center(
            child: RdCircularProgress(value: 0.5, label: '50%'),
          ),
        ),
      );

      expect(
        find.byKey(Key('premiumProgress-${definition.identity.effect.name}')),
        findsOneWidget,
      );
    });
  }

  testWidgets('standard progress keeps the canonical ring', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: const Center(
          child: RdCircularProgress(value: 0.5, label: '50%'),
        ),
      ),
    );

    expect(
      find.byKey(const Key('etherealProgressConstellation')),
      findsNothing,
    );
    expect(find.byKey(const Key('standardProgressRing')), findsOneWidget);
  });
}

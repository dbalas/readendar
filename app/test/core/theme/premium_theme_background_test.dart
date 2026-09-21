import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/theme/theme_background.dart';
import 'package:readendar/core/theme/theme_catalog.dart';

void main() {
  test('Courts ridge glint traverses every vertex without teleporting', () {
    const size = Size(430, 220);
    var previous = premiumVelarisRidgeGlintHead(size, 0);

    for (var step = 1; step <= 1200; step++) {
      final current = premiumVelarisRidgeGlintHead(size, step / 1200);
      expect(
        (current - previous).distance,
        lessThan(2),
        reason: 'glint jumped at animation step $step',
      );
      previous = current;
    }

    expect(
      (premiumVelarisRidgeGlintHead(size, 0) -
              premiumVelarisRidgeGlintHead(size, 1))
          .distance,
      lessThan(0.001),
    );
  });

  test('storm rain is vertical and neon trails are horizontal', () {
    const extent = 24.0;

    expect(
      premiumThemeEffectTravel(
        ReadendarBackgroundEffect.stormbound,
        extent,
      ),
      const Offset(0, extent),
    );
    expect(
      premiumThemeEffectTravel(ReadendarBackgroundEffect.neonMoon, extent),
      const Offset(extent, 0),
    );
  });

  for (final definition in ReadendarThemes.premium) {
    testWidgets('${definition.id.name} renders its premium atmosphere', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(themeId: definition.id),
          home: const ReadendarThemeBackground(child: SizedBox.expand()),
        ),
      );

      expect(find.byKey(const Key('premium-theme-effect')), findsOneWidget);
      expect(find.byKey(const Key('premium-theme-animation')), findsOneWidget);
      expect(
        find.byKey(
          Key(
            'premium-theme-painter-${definition.lightBackground.effect.name}',
          ),
        ),
        findsOneWidget,
      );
      final painterFinder = find.byKey(
        Key('premium-theme-painter-${definition.lightBackground.effect.name}'),
      );
      final before = tester.widget<CustomPaint>(painterFinder).painter!;
      await tester.pump(const Duration(seconds: 1));
      final after = tester.widget<CustomPaint>(painterFinder).painter!;
      expect(after.shouldRepaint(before), isTrue);
      expect(find.byKey(const Key('premium-theme-effect')), findsOneWidget);
    });
  }

  testWidgets('animated atmosphere does not repaint foreground content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(themeId: ReadendarThemeId.ethereal),
        home: const ReadendarThemeBackground(
          child: SizedBox(key: Key('foreground-content')),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('premium-theme-animation')),
        matching: find.byKey(const Key('foreground-content')),
      ),
      findsNothing,
    );
    expect(
      tester.widget(find.byKey(const Key('premium-theme-effect'))),
      isA<RepaintBoundary>(),
    );
  });

  for (final definition in ReadendarThemes.premium) {
    testWidgets('${definition.id.name} honors reduced motion and settles', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(themeId: definition.id),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const ReadendarThemeBackground(child: SizedBox.expand()),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('premium-theme-effect')), findsOneWidget);
    });
  }
}
